-- =============================================================
-- 03_raw_vendor_invoices.sql
-- Creates and seeds LEARNING_DB.RAW.VENDOR_INVOICES (50 invoices).
--
-- Business scenarios baked into data:
--   - 24 PAID invoices
--   - 18 PENDING invoices (Mike Davis has most: 6)
--   - 8 OVERDUE invoices (3 tied to HIGH risk vendors)
--   - IT category total spend exceeds $500k
--   - Business units: BU_WEST, BU_EAST, BU_CENTRAL
-- =============================================================

USE DATABASE LEARNING_DB;
USE SCHEMA RAW;

CREATE OR REPLACE TABLE LEARNING_DB.RAW.VENDOR_INVOICES (
    INVOICE_ID      VARCHAR(20)    NOT NULL,
    VENDOR_ID       VARCHAR(20)    NOT NULL,
    INVOICE_DATE    DATE           NOT NULL,
    DUE_DATE        DATE           NOT NULL,
    INVOICE_AMOUNT  NUMBER(15, 2)  NOT NULL,
    PAID_AMOUNT     NUMBER(15, 2),
    STATUS          VARCHAR(10)    NOT NULL,
    BUSINESS_UNIT   VARCHAR(20),
    CATEGORY        VARCHAR(100),
    COST_CENTER     VARCHAR(20),
    APPROVER        VARCHAR(200),
    PAYMENT_METHOD  VARCHAR(10),
    PO_NUMBER       VARCHAR(30),
    NOTES           VARCHAR(500),
    CONSTRAINT pk_vendor_invoices PRIMARY KEY (INVOICE_ID)
);

INSERT INTO LEARNING_DB.RAW.VENDOR_INVOICES VALUES
-- ── PAID invoices (24) ─────────────────────────────────────────────────
('INV-001', 'V002', '2026-01-15', '2026-03-01',  85000.00,  85000.00, 'PAID', 'BU_WEST',    'Facilities',   'CC-101', 'Sarah Johnson', 'ACH',   'PO-0101', 'Q1 janitorial services contract'),
('INV-002', 'V004', '2026-01-20', '2026-02-19',  35000.00,  35000.00, 'PAID', 'BU_EAST',    'Logistics',    'CC-102', 'Emily Chen',    'WIRE',  'PO-0102', 'January freight charges'),
('INV-003', 'V006', '2026-01-25', '2026-03-25', 120000.00, 120000.00, 'PAID', 'BU_CENTRAL', 'Security',     'CC-103', 'Robert Brown',  'ACH',   'PO-0103', 'Q1 security staffing'),
('INV-004', 'V008', '2026-02-01', '2026-03-17',  45000.00,  45000.00, 'PAID', 'BU_WEST',    'Consulting',   'CC-104', 'Emily Chen',    'CHECK', 'PO-0104', 'HR process audit'),
('INV-005', 'V009', '2026-02-05', '2026-03-07',  28000.00,  28000.00, 'PAID', 'BU_EAST',    'Facilities',   'CC-105', 'Robert Brown',  'ACH',   'PO-0105', 'HVAC maintenance February'),
('INV-006', 'V010', '2026-02-10', '2026-03-12',  75000.00,  75000.00, 'PAID', 'BU_CENTRAL', 'Legal',        'CC-106', 'James Wilson',  'WIRE',  'PO-0106', 'Contract review retainer Q1'),
('INV-007', 'V012', '2026-02-15', '2026-03-17',  42000.00,  42000.00, 'PAID', 'BU_WEST',    'Logistics',    'CC-107', 'Mike Davis',    'ACH',   'PO-0107', 'International freight Feb'),
('INV-008', 'V013', '2026-02-20', '2026-04-21', 180000.00, 180000.00, 'PAID', 'BU_EAST',    'Construction', 'CC-108', 'Robert Brown',  'WIRE',  'PO-0108', 'Phase 2 renovation milestone'),
('INV-009', 'V014', '2026-02-25', '2026-03-27',  95000.00,  95000.00, 'PAID', 'BU_CENTRAL', 'IT',           'CC-109', 'Emily Chen',    'ACH',   'PO-0109', 'Cloud analytics platform Q1'),
('INV-010', 'V015', '2026-03-01', '2026-04-15',  65000.00,  65000.00, 'PAID', 'BU_WEST',    'Telecom',      'CC-110', 'James Wilson',  'WIRE',  'PO-0110', 'Fiber connectivity Q1'),
('INV-011', 'V016', '2026-03-05', '2026-04-04',  32000.00,  32000.00, 'PAID', 'BU_EAST',    'Environmental','CC-111', 'Sarah Johnson', 'CHECK', 'PO-0111', 'Waste management March'),
('INV-012', 'V018', '2026-03-10', '2026-04-09',  55000.00,  55000.00, 'PAID', 'BU_CENTRAL', 'IT',           'CC-112', 'Robert Brown',  'ACH',   'PO-0112', 'Hardware repair and maintenance'),
('INV-013', 'V019', '2026-03-15', '2026-03-30',  18000.00,  18000.00, 'PAID', 'BU_WEST',    'Catering',     'CC-113', 'Emily Chen',    'CHECK', 'PO-0113', 'March executive dining'),
('INV-014', 'V020', '2026-03-20', '2026-04-19',  48000.00,  48000.00, 'PAID', 'BU_EAST',    'Travel',       'CC-114', 'James Wilson',  'ACH',   'PO-0114', 'Q1 executive travel program'),
('INV-015', 'V001', '2026-03-25', '2026-04-24', 125000.00, 125000.00, 'PAID', 'BU_CENTRAL', 'IT',           'CC-115', 'Sarah Johnson', 'WIRE',  'PO-0115', 'Enterprise software licenses Q1'),
('INV-016', 'V002', '2026-03-30', '2026-05-14',  92000.00,  92000.00, 'PAID', 'BU_WEST',    'Facilities',   'CC-116', 'Mike Davis',    'ACH',   'PO-0116', 'Building management April'),
('INV-017', 'V003', '2026-04-01', '2026-04-16',  78000.00,  78000.00, 'PAID', 'BU_EAST',    'IT',           'CC-117', 'Robert Brown',  'WIRE',  'PO-0117', 'Network infrastructure upgrade'),
('INV-018', 'V004', '2026-04-05', '2026-05-05',  41000.00,  41000.00, 'PAID', 'BU_CENTRAL', 'Logistics',    'CC-118', 'Emily Chen',    'ACH',   'PO-0118', 'April freight and warehousing'),
('INV-019', 'V006', '2026-04-10', '2026-06-09',  98000.00,  98000.00, 'PAID', 'BU_WEST',    'Security',     'CC-119', 'Sarah Johnson', 'WIRE',  'PO-0119', 'Q2 security services'),
('INV-020', 'V007', '2026-04-15', '2026-05-15', 145000.00, 145000.00, 'PAID', 'BU_EAST',    'IT',           'CC-120', 'Mike Davis',    'ACH',   'PO-0120', 'Datacenter colocation April'),
('INV-021', 'V009', '2026-04-20', '2026-05-20',  22000.00,  22000.00, 'PAID', 'BU_CENTRAL', 'Facilities',   'CC-121', 'Robert Brown',  'CHECK', 'PO-0121', 'HVAC maintenance April'),
('INV-022', 'V010', '2026-04-25', '2026-05-25',  55000.00,  55000.00, 'PAID', 'BU_WEST',    'Legal',        'CC-122', 'James Wilson',  'WIRE',  'PO-0122', 'IP licensing review Q2'),
('INV-023', 'V011', '2026-05-01', '2026-06-15',  88000.00,  88000.00, 'PAID', 'BU_EAST',    'IT',           'CC-123', 'Sarah Johnson', 'ACH',   'PO-0123', 'SD-WAN deployment phase 1'),
('INV-024', 'V013', '2026-05-05', '2026-07-04', 210000.00, 210000.00, 'PAID', 'BU_CENTRAL', 'Construction', 'CC-124', 'Emily Chen',    'WIRE',  'PO-0124', 'Phase 3 renovation deposit'),

-- ── PENDING invoices (18) — Mike Davis has 6, others have 3 each ───────
-- Mike Davis: INV-025 through INV-030 (6 pending)
('INV-025', 'V001', '2026-05-01', '2026-05-31', 150000.00,      0.00, 'PENDING', 'BU_WEST',    'IT',           'CC-201', 'Mike Davis',    'WIRE',  'PO-0201', 'May enterprise software renewal'),
('INV-026', 'V002', '2026-05-05', '2026-06-19',  68000.00,      0.00, 'PENDING', 'BU_EAST',    'Facilities',   'CC-202', 'Mike Davis',    'ACH',   'PO-0202', 'May facilities management'),
('INV-027', 'V003', '2026-05-08', '2026-05-23',  92000.00,      0.00, 'PENDING', 'BU_CENTRAL', 'IT',           'CC-203', 'Mike Davis',    'WIRE',  'PO-0203', 'Network expansion phase 2 - URGENT due in 1 day'),
('INV-028', 'V005', '2026-05-10', '2026-05-25',  38000.00,      0.00, 'PENDING', 'BU_WEST',    'Supplies',     'CC-204', 'Mike Davis',    'CHECK', 'PO-0204', 'Office supplies bulk order May'),
('INV-029', 'V007', '2026-05-12', '2026-06-11', 175000.00,      0.00, 'PENDING', 'BU_EAST',    'IT',           'CC-205', 'Mike Davis',    'ACH',   'PO-0205', 'Datacenter expansion Q2'),
('INV-030', 'V011', '2026-05-14', '2026-06-28', 115000.00,      0.00, 'PENDING', 'BU_CENTRAL', 'IT',           'CC-206', 'Mike Davis',    'WIRE',  'PO-0206', 'MPLS circuit upgrade'),
-- Sarah Johnson: 3 pending
('INV-031', 'V004', '2026-05-01', '2026-05-31',  42000.00,      0.00, 'PENDING', 'BU_WEST',    'Logistics',    'CC-207', 'Sarah Johnson', 'ACH',   'PO-0207', 'May freight and distribution'),
('INV-032', 'V006', '2026-05-03', '2026-07-02',  88000.00,      0.00, 'PENDING', 'BU_EAST',    'Security',     'CC-208', 'Sarah Johnson', 'WIRE',  'PO-0208', 'Q2 security guard services'),
('INV-033', 'V008', '2026-05-06', '2026-06-20',  52000.00,      0.00, 'PENDING', 'BU_CENTRAL', 'Consulting',   'CC-209', 'Sarah Johnson', 'CHECK', 'PO-0209', 'HR transformation project'),
-- Emily Chen: 3 pending
('INV-034', 'V012', '2026-05-08', '2026-06-07',  35000.00,      0.00, 'PENDING', 'BU_WEST',    'Logistics',    'CC-210', 'Emily Chen',    'ACH',   'PO-0210', 'International freight May'),
('INV-035', 'V013', '2026-05-10', '2026-07-09', 250000.00,      0.00, 'PENDING', 'BU_EAST',    'Construction', 'CC-211', 'Emily Chen',    'WIRE',  'PO-0211', 'Phase 4 renovation contract'),
('INV-036', 'V014', '2026-05-12', '2026-06-11',  78000.00,      0.00, 'PENDING', 'BU_CENTRAL', 'IT',           'CC-212', 'Emily Chen',    'ACH',   'PO-0212', 'Cloud analytics Q2 subscription'),
-- James Wilson: 3 pending
('INV-037', 'V015', '2026-05-14', '2026-06-28',  62000.00,      0.00, 'PENDING', 'BU_WEST',    'Telecom',      'CC-213', 'James Wilson',  'WIRE',  'PO-0213', 'May telecom and connectivity'),
('INV-038', 'V016', '2026-05-01', '2026-05-31',  28000.00,      0.00, 'PENDING', 'BU_EAST',    'Environmental','CC-214', 'James Wilson',  'CHECK', 'PO-0214', 'Environmental compliance May'),
('INV-039', 'V018', '2026-05-05', '2026-06-04',  72000.00,      0.00, 'PENDING', 'BU_CENTRAL', 'IT',           'CC-215', 'James Wilson',  'ACH',   'PO-0215', 'IT equipment repair Q2'),
-- Robert Brown: 3 pending
('INV-040', 'V019', '2026-05-08', '2026-05-23',  21000.00,      0.00, 'PENDING', 'BU_WEST',    'Catering',     'CC-216', 'Robert Brown',  'CHECK', 'PO-0216', 'May executive catering'),
('INV-041', 'V020', '2026-05-10', '2026-06-09',  55000.00,      0.00, 'PENDING', 'BU_EAST',    'Travel',       'CC-217', 'Robert Brown',  'ACH',   'PO-0217', 'Q2 executive travel booking'),
('INV-042', 'V009', '2026-05-12', '2026-06-11',  34000.00,      0.00, 'PENDING', 'BU_CENTRAL', 'Facilities',   'CC-218', 'Robert Brown',  'WIRE',  'PO-0218', 'HVAC full inspection May'),

-- ── OVERDUE invoices (8) — 3 from HIGH risk vendors ────────────────────
-- HIGH risk: V001, V003, V005
('INV-043', 'V001', '2026-03-15', '2026-04-14', 185000.00,  50000.00, 'OVERDUE', 'BU_WEST',    'IT',           'CC-301', 'Sarah Johnson', 'WIRE',  'PO-0301', 'ESCALATED: Feb software licenses partial payment only'),
('INV-044', 'V003', '2026-03-20', '2026-04-04', 125000.00,      0.00, 'OVERDUE', 'BU_EAST',    'IT',           'CC-302', 'Mike Davis',    'ACH',   'PO-0302', 'ESCALATED: Network audit — vendor disputing scope'),
('INV-045', 'V005', '2026-03-25', '2026-04-09',  62000.00,  20000.00, 'OVERDUE', 'BU_CENTRAL', 'Supplies',     'CC-303', 'Robert Brown',  'CHECK', 'PO-0303', 'ESCALATED: Q1 office supplies partial payment'),
-- Other overdue
('INV-046', 'V007', '2026-04-01', '2026-04-16', 145000.00,      0.00, 'OVERDUE', 'BU_WEST',    'IT',           'CC-304', 'Emily Chen',    'WIRE',  'PO-0304', 'OVERDUE: Colocation fee — PO approval delayed'),
('INV-047', 'V013', '2026-03-15', '2026-04-14', 280000.00, 100000.00, 'OVERDUE', 'BU_EAST',    'Construction', 'CC-305', 'James Wilson',  'ACH',   'PO-0305', 'OVERDUE: Phase 2 renovation milestone dispute'),
('INV-048', 'V002', '2026-04-01', '2026-05-16',  95000.00,      0.00, 'OVERDUE', 'BU_CENTRAL', 'Facilities',   'CC-306', 'Mike Davis',    'WIRE',  'PO-0306', 'OVERDUE: April facilities — budget reallocation pending'),
('INV-049', 'V015', '2026-04-05', '2026-05-20',  78000.00,  25000.00, 'OVERDUE', 'BU_WEST',    'Telecom',      'CC-307', 'Sarah Johnson', 'CHECK', 'PO-0307', 'OVERDUE: Connectivity services — billing discrepancy'),
('INV-050', 'V018', '2026-04-10', '2026-05-10',  55000.00,      0.00, 'OVERDUE', 'BU_EAST',    'IT',           'CC-308', 'Robert Brown',  'ACH',   'PO-0308', 'OVERDUE: Equipment maintenance — awaiting PO extension');

-- Verify load
SELECT STATUS, COUNT(*) AS invoice_count, SUM(INVOICE_AMOUNT) AS total_amount
FROM LEARNING_DB.RAW.VENDOR_INVOICES
GROUP BY STATUS
ORDER BY STATUS;

SELECT CATEGORY, SUM(INVOICE_AMOUNT) AS category_spend
FROM LEARNING_DB.RAW.VENDOR_INVOICES
GROUP BY CATEGORY
ORDER BY category_spend DESC;
