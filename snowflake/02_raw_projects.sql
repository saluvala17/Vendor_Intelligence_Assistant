-- =============================================================
-- 02_raw_projects.sql
-- Creates and seeds LEARNING_DB.RAW.PROJECTS for Apex Build Co.
-- 15 construction projects across Colorado.
--
-- Business scenarios baked into data:
--   SCENARIO 1 — Over budget:       P001 Downtown Office Renovation
--                                   Budget $850k → Actual $920k (+8.2%)
--   SCENARIO 2 — Behind schedule:   P002 Highway Bridge Repair
--                                   Expected 65% complete → Actual 48%
--                                   Liquidated damages risk
--   SCENARIO 4 — HIGH risk projects: P001, P002, P007, P013
--   Expiring within 90 days (by 2026-08-21):
--                                   P001 (2026-06-30), P002 (2026-07-31),
--                                   P004 (2026-06-15), P012 (2026-07-31),
--                                   P013 (2026-06-30)
--   Project Managers: Mike Davis, Sarah Johnson, Robert Brown,
--                     Emily Chen, James Wilson
-- =============================================================

USE DATABASE LEARNING_DB;
USE SCHEMA RAW;

CREATE OR REPLACE TABLE LEARNING_DB.RAW.PROJECTS (
    PROJECT_ID               VARCHAR(20)    NOT NULL,
    PROJECT_NAME             VARCHAR(200)   NOT NULL,
    CLIENT_NAME              VARCHAR(200)   NOT NULL,
    PROJECT_TYPE             VARCHAR(50),
    LOCATION                 VARCHAR(200),
    PROJECT_MANAGER          VARCHAR(200),
    CONTRACT_VALUE           NUMBER(15, 2),
    BUDGET                   NUMBER(15, 2),
    ACTUAL_COST_TO_DATE      NUMBER(15, 2),
    START_DATE               DATE,
    EXPECTED_END_DATE        DATE,
    ACTUAL_END_DATE          DATE,
    STATUS                   VARCHAR(20)    NOT NULL,
    COMPLETION_PCT           NUMBER(5, 2),
    EXPECTED_COMPLETION_PCT  NUMBER(5, 2),
    RISK_LEVEL               VARCHAR(10)    NOT NULL,
    PAYMENT_TERMS            VARCHAR(10),
    RETAINAGE_PCT            NUMBER(4, 2),
    PERMIT_NUMBER            VARCHAR(50),
    CREATED_DATE             DATE,
    CONSTRAINT pk_projects PRIMARY KEY (PROJECT_ID)
);

INSERT INTO LEARNING_DB.RAW.PROJECTS VALUES
-- ── HIGH RISK PROJECTS ──────────────────────────────────────────────────────

-- SCENARIO 1: Over budget — $850k budget, $920k actual (+$70k / 8.2% over)
('P001', 'Downtown Office Renovation',     'Metro Property Group',      'Commercial',      'Denver, CO',           'Mike Davis',    950000,   850000,   920000, '2025-09-01', '2026-06-30', NULL,         'ACTIVE',    85.00,  90.00, 'HIGH',   'NET30', 10.00, 'BLDG-2025-4412', '2025-08-15'),

-- SCENARIO 2: Behind schedule — 48% actual vs 65% expected → liquidated damages risk
('P002', 'Highway Bridge Repair',          'CDOT',                      'Infrastructure',  'Colorado Springs, CO', 'Sarah Johnson', 1350000,  1200000,   575000, '2025-08-01', '2026-07-31', NULL,         'ACTIVE',    48.00,  65.00, 'HIGH',   'NET45',  5.00, 'CDOT-2025-0891', '2025-07-20'),

-- HIGH risk with subcontractor payment dispute on active job
('P007', 'Peaks Retail Strip Mall',        'Peaks Commercial RE',        'Commercial',      'Boulder, CO',          'Mike Davis',    880000,   780000,   495000, '2025-11-01', '2026-08-31', NULL,         'ACTIVE',    63.00,  63.00, 'HIGH',   'NET30', 10.00, 'BLDG-2025-6638', '2025-10-15'),

-- HIGH risk, behind schedule (58% actual vs 88% expected based on timeline)
('P013', 'Southgate Shopping Expansion',   'Southgate Retail LLC',       'Commercial',      'Englewood, CO',        'Robert Brown',  2800000,  2500000,  1500000, '2025-07-01', '2026-06-30', NULL,         'ACTIVE',    58.00,  88.00, 'HIGH',   'NET45', 10.00, 'BLDG-2025-2203', '2025-06-15'),

-- ── MEDIUM RISK PROJECTS ────────────────────────────────────────────────────

('P003', 'Riverside Apartments Phase 2',   'Greenfield Developers',      'Residential',     'Denver, CO',           'Robert Brown',  2350000,  2100000,  1260000, '2025-10-15', '2026-10-15', NULL,         'ACTIVE',    60.00,  58.00, 'MEDIUM', 'NET30', 10.00, 'BLDG-2025-5519', '2025-10-01'),
('P006', 'Jefferson High Gymnasium',       'Jefferson County Schools',   'Education',       'Lakewood, CO',         'Sarah Johnson',  480000,   425000,   318000, '2025-12-01', '2026-08-01', NULL,         'ACTIVE',    75.00,  70.00, 'MEDIUM', 'NET30', 10.00, 'SCHD-2025-1122', '2025-11-15'),
('P009', 'Regional Water Treatment Plant', 'Douglas County',             'Infrastructure',  'Castle Rock, CO',      'Emily Chen',   3600000,  3200000,  1280000, '2025-10-01', '2027-03-31', NULL,         'ACTIVE',    40.00,  38.00, 'MEDIUM', 'NET45',  5.00, 'UTIL-2025-3348', '2025-09-15'),
('P011', 'Westfield Parking Structure',    'Westfield Properties',       'Commercial',      'Westminster, CO',      'Sarah Johnson', 1000000,   890000,   312000, '2026-02-15', '2026-11-15', NULL,         'ACTIVE',    35.00,  33.00, 'MEDIUM', 'NET45',  5.00, 'BLDG-2026-0221', '2026-02-01'),
('P015', 'Lincoln Elementary Addition',    'Denver Public Schools',      'Education',       'Denver, CO',           'James Wilson',   750000,   675000,   337000, '2026-01-15', '2026-08-31', NULL,         'ACTIVE',    50.00,  48.00, 'MEDIUM', 'NET30', 10.00, 'SCHD-2026-0145', '2026-01-05'),

-- ── LOW RISK PROJECTS ───────────────────────────────────────────────────────

('P004', 'City Hall Annex',                'City of Aurora',             'Government',      'Aurora, CO',           'Emily Chen',    720000,   650000,   598000, '2025-06-01', '2026-06-15', NULL,         'ACTIVE',    92.00,  95.00, 'LOW',    'NET30',  5.00, 'GOV-2025-0087',  '2025-05-20'),
('P005', 'Industrial Warehouse Complex',   'Summit Logistics Inc',       'Industrial',      'Pueblo, CO',           'James Wilson',  2050000,  1800000,   900000, '2026-01-01', '2026-12-31', NULL,         'ACTIVE',    50.00,  40.00, 'LOW',    'NET45',  5.00, 'BLDG-2026-0013', '2025-12-15'),
('P008', 'Harmony Medical Clinic',         'Harmony Health Partners',    'Commercial',      'Fort Collins, CO',     'Robert Brown',   620000,   560000,   252000, '2026-02-01', '2026-09-30', NULL,         'ACTIVE',    45.00,  43.00, 'LOW',    'NET30',  5.00, 'BLDG-2026-0198', '2026-01-20'),
('P010', 'Alpine Luxury Homes',            'Pinnacle Custom Homes',      'Residential',     'Vail, CO',             'James Wilson',  1550000,  1400000,   700000, '2026-01-15', '2026-11-30', NULL,         'ACTIVE',    50.00,  47.00, 'LOW',    'NET30', 10.00, 'RESD-2026-0033', '2026-01-10'),
('P012', 'Station 7 Firehouse Renovation', 'City of Littleton',         'Government',      'Littleton, CO',        'Mike Davis',    365000,   320000,   160000, '2026-01-01', '2026-07-31', NULL,         'ACTIVE',    50.00,  52.00, 'LOW',    'NET30',  5.00, 'GOV-2026-0022',  '2025-12-20'),

-- ── COMPLETED PROJECT ───────────────────────────────────────────────────────

('P014', 'Grand Hotel Lobby Remodel',      'Grand Plaza Hotels',         'Hospitality',     'Denver, CO',           'Emily Chen',    200000,   185000,   192000, '2026-02-01', '2026-05-15', '2026-05-10', 'COMPLETED', 100.00, 100.00, 'LOW',    'NET30',  5.00, 'BLDG-2026-0187', '2026-01-25');

-- ── Verification queries ────────────────────────────────────────────────────
-- Risk breakdown
SELECT RISK_LEVEL, COUNT(*) AS project_count,
       SUM(BUDGET) AS total_budget,
       SUM(ACTUAL_COST_TO_DATE) AS total_actual
FROM LEARNING_DB.RAW.PROJECTS
GROUP BY RISK_LEVEL ORDER BY RISK_LEVEL;

-- Over budget projects
SELECT PROJECT_ID, PROJECT_NAME, BUDGET, ACTUAL_COST_TO_DATE,
       ROUND(((ACTUAL_COST_TO_DATE - BUDGET) / BUDGET) * 100, 1) AS pct_over_budget
FROM LEARNING_DB.RAW.PROJECTS
WHERE ACTUAL_COST_TO_DATE > BUDGET;

-- Behind schedule projects
SELECT PROJECT_ID, PROJECT_NAME, COMPLETION_PCT, EXPECTED_COMPLETION_PCT,
       COMPLETION_PCT - EXPECTED_COMPLETION_PCT AS schedule_variance_pct
FROM LEARNING_DB.RAW.PROJECTS
WHERE COMPLETION_PCT < EXPECTED_COMPLETION_PCT
ORDER BY (COMPLETION_PCT - EXPECTED_COMPLETION_PCT) ASC;
