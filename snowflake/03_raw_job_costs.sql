-- =============================================================
-- 03_raw_job_costs.sql
-- Creates and seeds LEARNING_DB.RAW.JOB_COSTS (50 cost entries).
-- Covers subcontractor invoices, materials, equipment, and labor.
--
-- Business scenarios baked into data:
--   SCENARIO 2 — Subcontractor lien risk (3 subs with overdue invoices):
--                Peak Electric Co     → P001, P007 OVERDUE
--                Rocky Mountain Plumbing → P002, P009 OVERDUE
--                Summit Concrete Works → P013, P005 OVERDUE
--   SCENARIO 3 — Electrical category overrun:
--                Budget $180k → Actual invoiced $225k across all projects
--   SCENARIO 5 — Approval bottleneck:
--                Mike Davis has 7 PENDING approvals totalling $340k
--
-- Status split: 24 PAID | 18 PENDING | 8 OVERDUE
-- Approvers: Mike Davis (7 pending), Sarah Johnson, Robert Brown,
--            Emily Chen, James Wilson
-- =============================================================

USE DATABASE LEARNING_DB;
USE SCHEMA RAW;

CREATE OR REPLACE TABLE LEARNING_DB.RAW.JOB_COSTS (
    COST_ID         VARCHAR(20)    NOT NULL,
    PROJECT_ID      VARCHAR(20)    NOT NULL,
    COST_DATE       DATE           NOT NULL,
    DUE_DATE        DATE           NOT NULL,
    VENDOR_NAME     VARCHAR(200)   NOT NULL,
    COST_TYPE       VARCHAR(20)    NOT NULL,
    CATEGORY        VARCHAR(100),
    DESCRIPTION     VARCHAR(500)   NOT NULL,
    INVOICE_AMOUNT  NUMBER(15, 2)  NOT NULL,
    PAID_AMOUNT     NUMBER(15, 2),
    STATUS          VARCHAR(10)    NOT NULL,
    APPROVER        VARCHAR(200),
    PAYMENT_METHOD  VARCHAR(10),
    COST_CODE       VARCHAR(20),
    NOTES           VARCHAR(500),
    CONSTRAINT pk_job_costs PRIMARY KEY (COST_ID)
);

INSERT INTO LEARNING_DB.RAW.JOB_COSTS VALUES
-- ── PAID cost entries (24) ──────────────────────────────────────────────────
('JC-001', 'P003', '2026-01-10', '2026-02-09',  'Rocky Mountain Framing LLC',    'SUBCONTRACTOR', 'Framing',     'Framing package Phase 1 — Riverside Apartments',          85000.00,  85000.00, 'PAID', 'Sarah Johnson', 'CHECK', '06-Framing',   'Completed on schedule'),
('JC-002', 'P005', '2026-01-15', '2026-02-14',  'Continental Steel Supply',      'MATERIAL',      'Steel',       'Structural steel delivery Phase 1 — Warehouse',           128000.00, 128000.00,'PAID', 'James Wilson',  'WIRE',  '05-Steel',     'Full delivery received and inspected'),
('JC-003', 'P001', '2026-01-20', '2026-02-19',  'Peak Electric Co',              'SUBCONTRACTOR', 'Electrical',    'Electrical rough-in Phase 1 — Downtown Office',             8500.00,   8500.00, 'PAID', 'Mike Davis',    'CHECK', '16-Electrical','ELECTRICAL BUDGET TRACKING — Phase 1 of 3'),
('JC-004', 'P004', '2026-01-25', '2026-02-24',  'Front Range Concrete',          'MATERIAL',      'Concrete',    'Foundation concrete pour — City Hall Annex',               22000.00,  22000.00, 'PAID', 'Emily Chen',    'ACH',   '03-Concrete',  'Passed structural inspection'),
('JC-005', 'P006', '2026-02-01', '2026-03-03',  'High Plains HVAC',              'SUBCONTRACTOR', 'HVAC',        'HVAC rough-in — Jefferson Gymnasium',                      58000.00,  58000.00, 'PAID', 'Sarah Johnson', 'CHECK', '15-Mechanical','Installation complete, testing pending'),
('JC-006', 'P009', '2026-02-05', '2026-03-22',  'Apex Equipment Rental',         'EQUIPMENT',     'Equipment',   'Crane and excavator rental February — Water Plant',        32000.00,  32000.00, 'PAID', 'Emily Chen',    'ACH',   '01-GenReq',    'Monthly equipment rental'),
('JC-007', 'P010', '2026-02-10', '2026-03-12',  'Mountain Lumber Co',            'MATERIAL',      'Framing',     'Framing lumber delivery Phase 1 — Alpine Homes',           45000.00,  45000.00, 'PAID', 'James Wilson',  'CHECK', '06-Framing',   'Delivered to Vail site'),
('JC-008', 'P013', '2026-02-15', '2026-04-16',  'Summit Concrete Works',         'SUBCONTRACTOR', 'Concrete',    'Foundation pour Phase 1 — Southgate Expansion',            95000.00,  95000.00, 'PAID', 'Robert Brown',  'WIRE',  '03-Concrete',  'Passed structural inspection'),
('JC-009', 'P007', '2026-02-20', '2026-03-22',  'Peak Electric Co',              'SUBCONTRACTOR', 'Electrical',    'Electrical service entrance rough-in — Strip Mall',          6500.00,   6500.00, 'PAID', 'Mike Davis',    'CHECK', '16-Electrical','ELECTRICAL BUDGET TRACKING — Phase 1 of 3'),
('JC-010', 'P008', '2026-02-25', '2026-03-27',  'Colorado Roofing Inc',          'SUBCONTRACTOR', 'Roofing',     'Roofing Phase 1 install — Harmony Medical',                48000.00,  48000.00, 'PAID', 'Robert Brown',  'ACH',   '07-Roofing',   'Membrane installed, awaiting inspection'),
('JC-011', 'P015', '2026-03-01', '2026-03-31',  'Front Range Painting',          'SUBCONTRACTOR', 'Painting',    'Interior painting Phase 1 — Lincoln Elementary',           16000.00,  16000.00, 'PAID', 'James Wilson',  'CHECK', '09-Finishes',  'Classrooms 101-108 complete'),
('JC-012', 'P003', '2026-03-05', '2026-04-04',  'Apex Equipment Rental',         'EQUIPMENT',     'Equipment',   'Tower crane rental March — Riverside Apartments',           24000.00,  24000.00, 'PAID', 'Robert Brown',  'ACH',   '01-GenReq',    'Monthly rental'),
('JC-013', 'P001', '2026-03-10', '2026-04-09',  'Denver Drywall Pro',            'SUBCONTRACTOR', 'Drywall',     'Drywall Phase 1 hang and finish — Downtown Office',         65000.00,  65000.00, 'PAID', 'Mike Davis',    'CHECK', '09-Finishes',  'Floors 1-4 complete'),
('JC-014', 'P012', '2026-03-15', '2026-04-14',  'Rocky Mountain Plumbing',       'SUBCONTRACTOR', 'Plumbing',    'Plumbing rough-in — Station 7 Firehouse',                  38000.00,  38000.00, 'PAID', 'Mike Davis',    'CHECK', '15-Mechanical','Passed rough-in inspection'),
('JC-015', 'P009', '2026-03-20', '2026-05-04',  'State Electrical Contractors',  'SUBCONTRACTOR', 'Electrical',    'Control system electrical Phase 1 — Water Plant',           28000.00,  28000.00, 'PAID', 'Emily Chen',    'WIRE',  '16-Electrical','ELECTRICAL BUDGET TRACKING — Phase 1 of 2'),
('JC-016', 'P005', '2026-03-25', '2026-05-09',  'Colorado Concrete Co',          'SUBCONTRACTOR', 'Concrete',    'Warehouse slab pour — Industrial Complex',                  88000.00,  88000.00, 'PAID', 'James Wilson',  'ACH',   '03-Concrete',  'Passed flatwork inspection'),
('JC-017', 'P011', '2026-04-01', '2026-05-01',  'Front Range Concrete',          'MATERIAL',      'Concrete',    'Parking deck Level 1 pour — Westfield Structure',           62000.00,  62000.00, 'PAID', 'Sarah Johnson', 'CHECK', '03-Concrete',  'Level 1 complete'),
('JC-018', 'P006', '2026-04-05', '2026-05-05',  'Alpine Flooring Co',            'SUBCONTRACTOR', 'Flooring',    'Gymnasium hardwood floor install — Jefferson High',          32000.00,  32000.00, 'PAID', 'Sarah Johnson', 'ACH',   '09-Finishes',  'Floor sanded and sealed'),
('JC-019', 'P010', '2026-04-10', '2026-05-10',  'Vail Stone Works',              'MATERIAL',      'Masonry',     'Exterior stone facade materials — Alpine Homes',            58000.00,  58000.00, 'PAID', 'James Wilson',  'CHECK', '04-Masonry',   'Materials delivered to site'),
('JC-020', 'P004', '2026-04-15', '2026-05-15',  'Denver Interior Systems',       'SUBCONTRACTOR', 'Drywall',     'Interior partition walls — City Hall Annex',                35000.00,  35000.00, 'PAID', 'Emily Chen',    'ACH',   '09-Finishes',  'All partitions installed'),
('JC-021', 'P008', '2026-04-20', '2026-05-20',  'Front Range Electrical',        'SUBCONTRACTOR', 'Electrical',    'Medical clinic electrical rough-in — Harmony',              12000.00,  12000.00, 'PAID', 'Robert Brown',  'CHECK', '16-Electrical','ELECTRICAL BUDGET TRACKING — Phase 1 of 2'),
('JC-022', 'P015', '2026-04-25', '2026-05-25',  'Jefferson Mechanical',          'SUBCONTRACTOR', 'HVAC',        'HVAC installation — Lincoln Elementary Addition',           52000.00,  52000.00, 'PAID', 'James Wilson',  'WIRE',  '15-Mechanical','Passed mechanical rough-in inspection'),
('JC-023', 'P003', '2026-05-01', '2026-06-15',  'Colorado Plumbing Pros',        'SUBCONTRACTOR', 'Plumbing',    'Plumbing fixtures Phase 2 — Riverside Apartments',          72000.00,  72000.00, 'PAID', 'Robert Brown',  'ACH',   '15-Mechanical','Paid early — retainage hold applied'),
('JC-024', 'P013', '2026-05-05', '2026-07-04',  'Continental Steel Supply',      'MATERIAL',      'Steel',       'Steel beam delivery Expansion Phase 2 — Southgate',        165000.00, 165000.00,'PAID', 'Robert Brown',  'WIRE',  '05-Steel',     'Paid early to secure delivery slot'),

-- ── PENDING cost entries (18) — Mike Davis has 7 ($340k unapproved) ─────────

-- Mike Davis approvals: JC-025 through JC-031 (7 invoices = $340k)
('JC-025', 'P001', '2026-05-01', '2026-05-31',  'Peak Electric Co',              'SUBCONTRACTOR', 'Electrical',    'Final electrical trim and fixtures Phase 3 — Downtown Office', 52000.00, 0.00, 'PENDING', 'Mike Davis',    'CHECK', '16-Electrical','ELECTRICAL BUDGET TRACKING — awaiting approval'),
('JC-026', 'P007', '2026-05-05', '2026-06-04',  'Colorado Roofing Inc',          'SUBCONTRACTOR', 'Roofing',     'Final roofing and waterproofing — Strip Mall',               42000.00,     0.00, 'PENDING', 'Mike Davis',    'ACH',   '07-Roofing',   'Punch list items outstanding'),
('JC-027', 'P012', '2026-05-08', '2026-06-07',  'Front Range Painting',          'SUBCONTRACTOR', 'Painting',    'Interior and exterior paint — Firehouse Renovation',         20000.00,     0.00, 'PENDING', 'Mike Davis',    'CHECK', '09-Finishes',  'Final coat applied'),
('JC-028', 'P013', '2026-05-10', '2026-06-09',  'Summit Concrete Works',         'SUBCONTRACTOR', 'Concrete',    'Parking structure deck Level 2 pour — Southgate',           112000.00,     0.00, 'PENDING', 'Mike Davis',    'WIRE',  '03-Concrete',  'Schedule recovery plan required'),
('JC-029', 'P001', '2026-05-12', '2026-06-11',  'Denver Drywall Pro',            'SUBCONTRACTOR', 'Drywall',     'Final drywall tape and finish Phase 2 — Downtown Office',    35000.00,     0.00, 'PENDING', 'Mike Davis',    'CHECK', '09-Finishes',  'Floors 5-8 complete'),
('JC-030', 'P009', '2026-05-14', '2026-06-28',  'State Electrical Contractors',  'SUBCONTRACTOR', 'Electrical',    'Secondary electrical distribution Phase 2 — Water Plant',    38000.00,     0.00, 'PENDING', 'Mike Davis',    'WIRE',  '16-Electrical','ELECTRICAL BUDGET TRACKING — $225k total category risk'),
('JC-031', 'P007', '2026-05-16', '2026-06-15',  'High Plains HVAC',              'SUBCONTRACTOR', 'HVAC',        'HVAC trim-out and test balancing — Strip Mall',              41000.00,     0.00, 'PENDING', 'Mike Davis',    'CHECK', '15-Mechanical','Commissioning scheduled for 2026-06-01'),

-- Sarah Johnson pending (3)
('JC-032', 'P006', '2026-05-01', '2026-05-31',  'Denver Glass and Glazing',      'SUBCONTRACTOR', 'Glazing',     'Gymnasium windows and curtain wall — Jefferson High',        32000.00,     0.00, 'PENDING', 'Sarah Johnson', 'CHECK', '08-Glazing',   'Glass delivery expected 2026-05-28'),
('JC-033', 'P011', '2026-05-05', '2026-06-19',  'Rocky Mountain Concrete',       'SUBCONTRACTOR', 'Concrete',    'Level 3 parking deck pour — Westfield Structure',            82000.00,     0.00, 'PENDING', 'Sarah Johnson', 'ACH',   '03-Concrete',  'Pour scheduled 2026-05-30'),
('JC-034', 'P002', '2026-05-08', '2026-06-22',  'Bridge Structural Inc',         'SUBCONTRACTOR', 'Steel',       'Bridge deck steel Phase 2 — Highway Bridge Repair',         148000.00,     0.00, 'PENDING', 'Sarah Johnson', 'WIRE',  '05-Steel',     'Schedule recovery in progress — 17% gap from plan'),

-- Emily Chen pending (3)
('JC-035', 'P004', '2026-05-01', '2026-05-31',  'Front Range Electrical',        'SUBCONTRACTOR', 'Electrical',    'Final electrical trim City Hall — nearly complete',           15000.00,     0.00, 'PENDING', 'Emily Chen',    'CHECK', '16-Electrical','ELECTRICAL BUDGET TRACKING — final entry'),
('JC-036', 'P009', '2026-05-05', '2026-06-19',  'Apex Equipment Rental',         'EQUIPMENT',     'Equipment',   'Crane rental May through June — Water Plant',                38000.00,     0.00, 'PENDING', 'Emily Chen',    'ACH',   '01-GenReq',    'Two-month rental'),
('JC-037', 'P008', '2026-05-08', '2026-06-07',  'Colorado Medical Millwork',     'SUBCONTRACTOR', 'Millwork',    'Custom medical cabinetry install — Harmony Clinic',          62000.00,     0.00, 'PENDING', 'Emily Chen',    'WIRE',  '06-Millwork',  'Lead time 6 weeks — on schedule'),

-- James Wilson pending (3)
('JC-038', 'P010', '2026-05-01', '2026-05-31',  'Vail Custom Tile',              'SUBCONTRACTOR', 'Flooring',    'Luxury tile bathrooms and kitchen — Alpine Homes',           45000.00,     0.00, 'PENDING', 'James Wilson',  'CHECK', '09-Finishes',  'Premium materials imported — on site'),
('JC-039', 'P015', '2026-05-05', '2026-06-04',  'Denver Interior Systems',       'SUBCONTRACTOR', 'Drywall',     'Classroom drywall Phase 2 — Lincoln Elementary',             28000.00,     0.00, 'PENDING', 'James Wilson',  'ACH',   '09-Finishes',  'Rooms 201-212 in progress'),
('JC-040', 'P005', '2026-05-08', '2026-06-07',  'Continental Steel Supply',      'MATERIAL',      'Steel',       'Structural steel delivery Phase 3 — Warehouse Complex',     172000.00,     0.00, 'PENDING', 'James Wilson',  'WIRE',  '05-Steel',     'Final steel delivery for mezzanine level'),

-- Robert Brown pending (2)
('JC-041', 'P003', '2026-05-10', '2026-06-24',  'Alpine Plumbing Co',            'SUBCONTRACTOR', 'Plumbing',    'Plumbing fixtures install Phase 2 — Riverside Apartments',   55000.00,     0.00, 'PENDING', 'Robert Brown',  'CHECK', '15-Mechanical','Fixtures on site, install starting 2026-05-26'),
('JC-042', 'P013', '2026-05-12', '2026-06-26',  'Denver Landscaping Group',      'SUBCONTRACTOR', 'Landscaping', 'Site landscaping and hardscape — Southgate Expansion',       35000.00,     0.00, 'PENDING', 'Robert Brown',  'ACH',   '02-Sitework',  'Cannot start until structure complete'),

-- ── OVERDUE cost entries (8) — 3 subcontractors with lien risk ─────────────

-- LIEN RISK: Peak Electric Co — unpaid on P001 and P007
('JC-043', 'P001', '2026-03-15', '2026-04-14',  'Peak Electric Co',              'SUBCONTRACTOR', 'Electrical',    'Electrical rough-in Phase 2 — PAYMENT DISPUTE',              45000.00,  12000.00, 'OVERDUE', 'Mike Davis',    'CHECK', '16-Electrical','LIEN RISK — contractor sent notice of intent 2026-05-10. ELECTRICAL BUDGET OVERRUN.'),
('JC-044', 'P007', '2026-03-20', '2026-04-04',  'Peak Electric Co',              'SUBCONTRACTOR', 'Electrical',    'Panel installation — change order disputed',                  20000.00,      0.00, 'OVERDUE', 'Mike Davis',    'WIRE',  '16-Electrical','LIEN RISK — 49 days overdue. Change order documentation missing. ELECTRICAL OVERRUN.'),

-- LIEN RISK: Rocky Mountain Plumbing — unpaid on P002 and P009
('JC-045', 'P002', '2026-03-25', '2026-04-09',  'Rocky Mountain Plumbing',       'SUBCONTRACTOR', 'Plumbing',    'Drainage and dewatering Phase 1 — Bridge Repair',            52000.00,  12000.00, 'OVERDUE', 'Sarah Johnson', 'CHECK', '15-Mechanical','LIEN RISK — project behind schedule contributing to payment delay'),
('JC-046', 'P009', '2026-04-01', '2026-04-16',  'Rocky Mountain Plumbing',       'SUBCONTRACTOR', 'Plumbing',    'Process piping installation Phase 1 — Water Plant',          88000.00,      0.00, 'OVERDUE', 'Emily Chen',    'WIRE',  '15-Mechanical','LIEN RISK — 37 days overdue. Contractor threatening work stoppage.'),

-- LIEN RISK: Summit Concrete Works — unpaid on P013 and P005
('JC-047', 'P013', '2026-03-15', '2026-04-14',  'Summit Concrete Works',         'SUBCONTRACTOR', 'Concrete',    'Foundation pour Phase 2 — billing dispute quantity',        135000.00,  45000.00, 'OVERDUE', 'Robert Brown',  'CHECK', '03-Concrete',  'LIEN RISK — 39 days overdue. Quantity dispute on 2,200 CY pour.'),
('JC-048', 'P005', '2026-04-05', '2026-05-05',  'Summit Concrete Works',         'SUBCONTRACTOR', 'Concrete',    'Warehouse slab pour — delay penalty withheld',               72000.00,      0.00, 'OVERDUE', 'James Wilson',  'ACH',   '03-Concrete',  'LIEN RISK — 18 days overdue. Delay penalty deducted — subcontractor objects.'),

-- Other overdue entries
('JC-049', 'P003', '2026-04-10', '2026-05-10',  'Apex Equipment Rental',         'EQUIPMENT',     'Equipment',   'Tower crane rental April — Riverside Apartments',            28000.00,      0.00, 'OVERDUE', 'Robert Brown',  'CHECK', '01-GenReq',    '13 days overdue — invoice lost in routing, re-processing'),
('JC-050', 'P011', '2026-04-15', '2026-05-15',  'Mountain Lumber Co',            'MATERIAL',      'Framing',     'Lumber delivery Phase 2 — Westfield Parking Structure',      24000.00,   8000.00, 'OVERDUE', 'Sarah Johnson', 'ACH',   '06-Framing',   '8 days overdue — partial payment issued, balance pending approval');

-- ── Verification queries ────────────────────────────────────────────────────

-- Status summary
SELECT STATUS, COUNT(*) AS entry_count,
       SUM(INVOICE_AMOUNT) AS total_invoiced,
       SUM(PAID_AMOUNT) AS total_paid,
       SUM(INVOICE_AMOUNT - COALESCE(PAID_AMOUNT,0)) AS total_outstanding
FROM LEARNING_DB.RAW.JOB_COSTS
GROUP BY STATUS ORDER BY STATUS;

-- SCENARIO 3: Electrical category budget vs actual
-- Budget: $180,000 | Expected actual: $225,000
SELECT CATEGORY, COUNT(*) AS invoice_count,
       SUM(INVOICE_AMOUNT) AS total_invoiced,
       SUM(PAID_AMOUNT) AS total_paid,
       SUM(INVOICE_AMOUNT - COALESCE(PAID_AMOUNT,0)) AS outstanding
FROM LEARNING_DB.RAW.JOB_COSTS
WHERE CATEGORY = 'Electrical'
GROUP BY CATEGORY;

-- SCENARIO 5: Pending approvals by approver
SELECT APPROVER, COUNT(*) AS pending_count,
       SUM(INVOICE_AMOUNT) AS pending_amount
FROM LEARNING_DB.RAW.JOB_COSTS
WHERE STATUS = 'PENDING'
GROUP BY APPROVER
ORDER BY pending_amount DESC;

-- SCENARIO 2: Lien risk — overdue subcontractors
SELECT VENDOR_NAME,
       SUM(INVOICE_AMOUNT) AS total_invoiced,
       SUM(COALESCE(PAID_AMOUNT,0)) AS total_paid,
       SUM(INVOICE_AMOUNT - COALESCE(PAID_AMOUNT,0)) AS outstanding,
       COUNT(*) AS overdue_invoices
FROM LEARNING_DB.RAW.JOB_COSTS
WHERE STATUS = 'OVERDUE'
GROUP BY VENDOR_NAME
ORDER BY outstanding DESC;
