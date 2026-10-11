#Requires -Version 5.1
<#
    ABB Robot Weekly Backup Automation - Multi-Robot
    -------------------------------------------------
    Reads a list of robots from robots.csv, pings each one,
    pulls the latest backup folder via FTP (WinSCP), organizes
    it on a network drive by Year\Month, and keeps only the
    N most recent backups on the controller.

    Schedule: Weekly via Windows Task Scheduler
#>

# --- CONFIGURATION -----------------------------------------------------------

# Path to the robot list (same folder as this script by default)
# Columns: RobotName,IP,FTPUser,FTPPassword,DestFolder (see robots.example.csv)
$RobotListCSV = Join-Path $PSScriptRoot "robots.csv"

# Network drive root - backups land here:
#   <NetworkBackupRoot>\<DestFolder>\<Year>\<Month>\<FolderName>\
$NetworkBackupRoot = "\\fileserver\RobotBackups"

# WinSCP .NET assembly path
$WinSCPDll = "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"

# FTP path on every ABB controller where backups are stored
$RemoteBackupParent = "/hd0a/BACKUP"

# How many backups to keep on each controller
$KeepOnRobot = 3

# Ping timeout in milliseconds before marking a robot offline
$PingTimeoutMs = 1000

# Log folder (created automatically if it doesn't exist)
$LogFolder = Join-Path $PSScriptRoot "Logs"

# --- END CONFIGURATION -------------------------------------------------------


# --- Setup -------------------------------------------------------------------

$runDate = Get-Date
$logFile = Join-Path $LogFolder ("BackupRun_{0}.log" -f $runDate.ToString("yyyy-MM-dd_HHmm"))

if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

Add-Type -Path $WinSCPDll

$results = [System.Collections.Generic.List[PSCustomObject]]::new()


# --- Logging -----------------------------------------------------------------

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "OK"    { "Green" }
        default { "Cyan" }
    }
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $logFile -Value $line
}


# --- Per-Robot Backup Function -----------------------------------------------

function Invoke-RobotBackup {
    param(
        [string]$RobotName,
        [string]$IP,
        [string]$FtpUser,
        [string]$FtpPassword,
        [string]$DestFolder
    )

    Write-Log "---- $RobotName ($IP) [$DestFolder] ----"

    # 1. Ping check
    $ping = New-Object System.Net.NetworkInformation.Ping
    try {
        $reply = $ping.Send($IP, $PingTimeoutMs)
    }
    catch {
        $reply = $null
    }

    if (-not $reply -or $reply.Status -ne "Success") {
        Write-Log "$RobotName - OFFLINE or unreachable, skipping." "WARN"
        return [PSCustomObject]@{ Robot = $RobotName; DestFolder = $DestFolder; Status = "Offline"; Note = "" }
    }

    Write-Log "$RobotName - Reachable ($([int]$reply.RoundtripTime) ms)"

    # 2. Connect via WinSCP
    $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
        Protocol = [WinSCP.Protocol]::Ftp
        HostName = $IP
        UserName = $FtpUser
        Password = $FtpPassword
        FtpMode  = [WinSCP.FtpMode]::Passive
    }

    $session = New-Object WinSCP.Session

    try {
        $session.Open($sessionOptions)
        Write-Log "$RobotName - FTP connected."

        # 3. List backup folders, pick the latest
        $dirInfo       = $session.ListDirectory($RemoteBackupParent)
        $backupFolders = $dirInfo.Files |
                         Where-Object { $_.IsDirectory -and $_.Name -notin @(".", "..") } |
                         Sort-Object Name -Descending

        if (-not $backupFolders) {
            Write-Log "$RobotName - No backup folders found on controller." "WARN"
            return [PSCustomObject]@{ Robot = $RobotName; DestFolder = $DestFolder; Status = "NoBackups"; Note = "" }
        }

        $latest     = $backupFolders[0]
        $folderName = $latest.Name
        Write-Log "$RobotName - Latest backup: $folderName"

        # 4. Parse year/month from folder name (date expected at end: 20260601 or 2026-06-01)
        if ($folderName -match '(\d{4})[-]?(\d{2})\d{0,2}$') {
            $year  = $matches[1]
            $month = $matches[2]
        }
        else {
            $year  = $runDate.Year.ToString()
            $month = $runDate.ToString("MM")
            Write-Log "$RobotName - Could not parse date from folder name, using today's year/month." "WARN"
        }

        # 5. Build destination path - skip download if already there
        $destPath = Join-Path $NetworkBackupRoot "$DestFolder\$year\$month\$folderName"

        if (Test-Path $destPath) {
            Write-Log "$RobotName - Latest backup already on network drive, skipping download." "OK"
            $status = "AlreadyCurrent"
        }
        else {
            # Download to a temp folder first, then move to final destination
            $tempPath = Join-Path $env:TEMP "ABBBackup_${RobotName}_$folderName"
            if (Test-Path $tempPath) { Remove-Item $tempPath -Recurse -Force }
            New-Item -ItemType Directory -Path $tempPath -Force | Out-Null

            $remotePath = "$RemoteBackupParent/$folderName"
            Write-Log "$RobotName - Downloading to: $destPath"

            $transferResult = $session.GetFiles("$remotePath/*", "$tempPath\", $false)
            $transferResult.Check()

            # Move to final network location
            $destParent = Split-Path $destPath -Parent
            if (-not (Test-Path $destParent)) {
                New-Item -ItemType Directory -Path $destParent -Force | Out-Null
            }
            Move-Item -Path $tempPath -Destination $destPath -Force
            Write-Log "$RobotName - Download complete." "OK"
            $status = "Downloaded"
        }

        # 6. Cleanup - keep only $KeepOnRobot most recent on controller
        # Cleanup only runs after a successful download (or already-current), so it is safe to delete.
        if ($backupFolders.Count -gt $KeepOnRobot) {
            $toDelete = $backupFolders | Select-Object -Skip $KeepOnRobot
            foreach ($old in $toDelete) {
                Write-Log "$RobotName - Deleting old backup from controller: $($old.Name)"
                $session.RemoveFiles("$RemoteBackupParent/$($old.Name)") | Out-Null
            }
            Write-Log "$RobotName - Kept $KeepOnRobot most recent, deleted $($toDelete.Count) old backup(s)."
        }
        else {
            Write-Log "$RobotName - $($backupFolders.Count) backup(s) on controller, no cleanup needed."
        }

        return [PSCustomObject]@{ Robot = $RobotName; DestFolder = $DestFolder; Status = $status; Note = $folderName }
    }
    catch {
        Write-Log "$RobotName - ERROR: $_" "ERROR"
        return [PSCustomObject]@{ Robot = $RobotName; DestFolder = $DestFolder; Status = "Error"; Note = $_.Exception.Message }
    }
    finally {
        $session.Dispose()
    }
}


# --- Main --------------------------------------------------------------------

Write-Log "=========================================="
Write-Log "  ABB Robot Backup Run - $($runDate.ToString('yyyy-MM-dd HH:mm'))"
Write-Log "  Destination: $NetworkBackupRoot"
Write-Log "=========================================="

if (-not (Test-Path $RobotListCSV)) {
    Write-Log "Robot list not found: $RobotListCSV" "ERROR"
    exit 1
}

$robots = @(Import-Csv $RobotListCSV)
Write-Log "Loaded $($robots.Count) robot(s) from $RobotListCSV"

foreach ($robot in $robots) {
    $result = Invoke-RobotBackup `
        -RobotName   $robot.RobotName `
        -IP          $robot.IP `
        -FtpUser     $robot.FTPUser `
        -FtpPassword $robot.FTPPassword `
        -DestFolder  $robot.DestFolder
    $results.Add($result)
}

# --- Summary -----------------------------------------------------------------

Write-Log "=========================================="
Write-Log "  SUMMARY"
Write-Log "=========================================="

$downloaded     = @($results | Where-Object { $_.Status -eq "Downloaded" })
$alreadyCurrent = @($results | Where-Object { $_.Status -eq "AlreadyCurrent" })
$offline        = @($results | Where-Object { $_.Status -eq "Offline" })
$errors         = @($results | Where-Object { $_.Status -eq "Error" })

Write-Log "  Downloaded     : $($downloaded.Count)" "OK"
Write-Log "  Already current: $($alreadyCurrent.Count)"

if ($offline.Count -gt 0) {
    Write-Log "  Offline        : $($offline.Count)" "WARN"
    Write-Log "  Offline robots : $(($offline | ForEach-Object { "$($_.Robot) [$($_.DestFolder)]" }) -join ', ')" "WARN"
}
else {
    Write-Log "  Offline        : 0"
}

if ($errors.Count -gt 0) {
    Write-Log "  Errors         : $($errors.Count)" "ERROR"
    foreach ($e in $errors) {
        Write-Log "  $($e.Robot): $($e.Note)" "ERROR"
    }
}
else {
    Write-Log "  Errors         : 0"
}

Write-Log "  Log saved to   : $logFile"
Write-Log "=========================================="
