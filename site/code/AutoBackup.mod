MODULE AutoBackup
    
    LOCAL PERS bool Backup_Complete:=FALSE;
    LOCAL PERS bool Clock_Started:=FALSE;
    LOCAL PERS num Timer:=0;
    TASK PERS string dateSaved:="2026-10-10";
    !PERS num nCurrJobID;
    PERS num weekday;
    PERS num hour;

    !
    !***********************************************************
    !

    PROC main()
        !
        weekday:=GetTime(\WDay);
        hour:=GetTime(\Hour);
        !
        IF dateSaved<>CDate() AND weekday=6 AND hour>6 RobotBackUp;
        !
        Backup_Complete:=FALSE;
        !
        Waittime 5;
    ENDPROC

    !
    !***********************************************************
    !

    PROC RobotBackUp()
        !
        WHILE Backup_Complete=FALSE DO
            !
            ! Wait for both JobInProgress AND JobPending to be clear before
            ! starting the idle timer. This prevents triggering during a line gap
            ! when the next job is already queued and on its way into the cell.
            IF JobInProgress=0 AND JobPending=0 AND Clock_Started=FALSE THEN
                !
                ClkStart clock1;
                Clock_Started:=TRUE;
                !
            ENDIF
            !
            Timer:=ClkRead(clock1);
            !
            IF Timer>=300 AND JobInProgress=0 AND JobPending=0 THEN
                !
                ! 5 minutes of no JobInProgress and no JobPending means production
                ! is genuinely stopped (normal cycle time is 60 sec - a 5 min idle
                ! window will never occur during a running shift, only a stopped line).
                ! No queue interference needed - safe to backup without affecting production.
                !
                ! Pulse the backup signal
                PulseDO\PLength:=0.2, doBackup;
                !
                dateSaved:=CDate();
                Backup_Complete:=TRUE;
                !
                ClkStop clock1;
                ClkReset clock1;
                Timer:=0;
                Clock_Started:=FALSE;
                !
            ELSEIF JobInProgress=1 OR JobPending=1 THEN
                !
                ! A job is running or queued - reset the idle timer and wait
                ClkStop clock1;
                ClkReset clock1;
                Timer:=0;
                Clock_Started:=FALSE;
                !
            ENDIF
            !
        ENDWHILE
        !
    ENDPROC
    
ENDMODULE