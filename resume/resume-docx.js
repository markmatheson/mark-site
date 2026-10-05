const fs = require('fs');
const { Document, Packer, Paragraph, TextRun, AlignmentType, LevelFormat, BorderStyle,
  TabStopType } = require('docx');

const FONT = 'Calibri';
const ACCENT = '1F3864';
const RIGHT = 10800; // text width in DXA for 0.75" margins on Letter

// Text with [PLACEHOLDERS] highlighted yellow so Mark can spot what needs a real number
function runs(text, opts = {}) {
  return text.split(/(\[[^\]]+\])/).filter(Boolean).map(part =>
    new TextRun({ text: part, font: FONT, size: 21, ...opts,
      ...(part.startsWith('[') ? { highlight: 'yellow', bold: true } : {}) }));
}

const section = title => new Paragraph({
  spacing: { before: 200, after: 80 },
  border: { bottom: { style: BorderStyle.SINGLE, size: 8, color: ACCENT, space: 2 } },
  children: [new TextRun({ text: title.toUpperCase(), bold: true, font: FONT, size: 23, color: ACCENT })],
});

const bullet = text => new Paragraph({
  numbering: { reference: 'bullets', level: 0 },
  spacing: { after: 40 },
  children: runs(text),
});

const job = (title, company, dates) => new Paragraph({
  spacing: { before: 120, after: 40 },
  tabStops: [{ type: TabStopType.RIGHT, position: RIGHT }],
  children: [
    new TextRun({ text: title, bold: true, font: FONT, size: 22 }),
    new TextRun({ text: ` | ${company}`, font: FONT, size: 22 }),
    new TextRun({ text: `\t${dates}`, font: FONT, size: 21, italics: true }),
  ],
});

const skill = (label, text) => new Paragraph({
  spacing: { after: 40 },
  children: [new TextRun({ text: `${label}: `, bold: true, font: FONT, size: 21 }), ...runs(text)],
});

const children = [
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 40 },
    children: [new TextRun({ text: 'MARK A. MATHESON', bold: true, font: FONT, size: 36, color: ACCENT })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 40 },
    children: runs('Inman, SC  |  (864) 386-1518  |  mark@markmatheson.dev  |  markmatheson.dev') }),

  section('Summary'),
  new Paragraph({ spacing: { after: 40 }, children: runs(
    'Field service and automation engineer with 15+ years troubleshooting, commissioning, and improving ' +
    'electromechanical robotic systems in high-uptime operations: automotive paint robotics at BMW, robot cell ' +
    'commissioning for ABB, and life-critical medical equipment for Medtronic. Works the front line between ' +
    'operators, maintainers, and engineering: diagnoses failures in the field, drives root cause, and feeds fixes ' +
    'back into the design. Experienced bringing new lines and robot cells online, from install through ' +
    'production handoff.') }),

  section('Core Skills'),
  skill('Troubleshooting & RCA', 'Robotics, electrical, electromechanical, and fluid/pneumatic systems; fault diagnosis under production pressure'),
  skill('Launch & Commissioning', 'New robot cells (sealer, paint, pick & place), BMW IPP and Wax line commissioning team, customer-site installs'),
  skill('Continuous Improvement', 'Cycle time reduction, downtime recovery, quality defect elimination, issue tracking to closure'),
  skill('Documentation & Training', 'Technical procedures, engineering field changes, onsite customer training'),
  skill('Software & Tools', 'ABB RobotStudio / RAPID, Siemens Process Simulate, Dürr 3D Onsite, CAD and 3D printing for custom tooling'),
  skill('Networking & Systems', 'UniFi network configuration, Proxmox virtualization, Linux, Home Assistant (homelab); CCNA in progress'),

  section('Professional Experience'),
  job('Robot Specialist', 'BMW Manufacturing, Greer, SC', 'Feb 2023 – Present'),
  bullet('Lead technical development of paint shop automation; own robot programming for new models, design changes, and continuous improvement across ABB, Dürr, and Fanuc equipment.'),
  bullet('First responder for planned and unplanned downtime: diagnose robot, electrical, and process faults and restore production, sustaining 95% equipment availability across the paint shop robot fleet.'),
  bullet('Key contributor to holding 60-second cycle times per station through path optimization and process re-sequencing, running operations in parallel, such as firing vision measurement and calculating corrections while the robot completes a tool change.'),
  bullet('Report, track, and drive issues to resolution with engineering, maintenance, and production teams.'),
  bullet('Run offline trials of new materials in the robot lab to validate process changes before they reach production.'),
  bullet('Design and 3D print custom robot tooling in CAD for fast, low-cost fixes.'),

  job('Field Service Engineer', 'Medtronic', 'Jan 2021 – Feb 2023'),
  bullet('Owned a 32-account territory covering South Carolina, western North Carolina, and east Tennessee, working independently across a three-state region.'),
  bullet('Installed, maintained, repaired, and upgraded life-critical ventilation systems (Puritan Bennett 980/840) at hospital customer sites.'),
  bullet('Diagnosed malfunctions across integrated hardware, subsystems, and software to restore equipment in minimum time in a zero-failure patient-safety environment.'),
  bullet('Executed engineering field changes, upgrades, and removals under controlled procedures with full service documentation.'),
  bullet('Trained customer biomedical staff onsite and served as primary technical contact for all territory accounts.'),

  job('Field Service Engineer', 'ABB', 'Nov 2017 – Dec 2020'),
  bullet('Commissioned new robot cells for sealer and paint applications at customer plants, from install through production handoff.'),
  bullet('Programmed a 16-robot masking plug cell for BMW on IRB robots and vision learned on the job: launched on schedule at a 60-second cycle and 95% plug success; named ABB Field Service Employee of the Month (June 2018).'),
  bullet('Programmed Flex Vision guidance and pick-and-place applications; integrated IRC5/IRC5P controllers and IPS paint systems.'),
  bullet('Delivered cycle time improvements, robot brake repairs, and onsite troubleshooting using RobotStudio, RobView, and Shop Floor Editor.'),

  job('Robot Programmer', 'BMW Manufacturing, Greer, SC', 'Aug 2011 – Nov 2017'),
  bullet('Created paint programs for new models; ran paint trial bodies and fine-pointed robot paths.'),
  bullet('Troubleshot and corrected paint defects; set up color tables and brush parameters for Bell RB1000 applicators.'),
  bullet('Used simulation software for hot edits to minimize production impact.'),
  bullet('Came up from the paint line floor (major/spot repair, E-coat sand, inspection & polish, robot operator).'),

  job('Diesel Technician', 'Morgan Corporation', 'Sep 2010 – Jul 2011'),
  bullet('Overhauled diesel equipment and completed offsite repairs to minimize equipment downtime.'),

  section('Education & Certifications'),
  bullet('Associate Degree, Management & Diesel Technology, WyoTech, Blairsville, PA (2010)'),
  bullet('ABB: RobotStudio, IRC5P Electrical, IPS, SafeMove 2, Flex Vision'),
  bullet('Fanuc: Dispense Tool and Programming'),
  bullet('Medtronic: Puritan Bennett 980 and 840 Ventilator Service'),
];

const doc = new Document({
  numbering: { config: [{ reference: 'bullets', levels: [{ level: 0, format: LevelFormat.BULLET, text: '•',
    alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 360, hanging: 240 } } } }] }] },
  sections: [{
    properties: { page: { size: { width: 12240, height: 15840 },
      margin: { top: 1008, bottom: 1008, left: 1080, right: 1080 } } },
    children,
  }],
});

Packer.toBuffer(doc).then(buf => {
  fs.writeFileSync(process.argv[2], buf);
  console.log('wrote', process.argv[2]);
});
