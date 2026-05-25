-- =============================================================
-- 05_raw_payroll.sql
-- Creates and seeds LEARNING_DB.RAW.PAYROLL (26 records).
-- Simulates QuickBooks weekly payroll export for field labor.
-- Covers May 2026 pay periods across 9 active projects.
--
-- Business scenarios baked into data:
--   SCENARIO A — Labor cost driver on over-budget project:
--                P001 Downtown Office → 56 OT hours in May
--                $24,080 total labor (highest $ and highest % of budget at 2.8%)
--                Carlos Ruiz (Electrician) clocking 16 OT hrs week of 05-17
--                driving the electrical budget overrun
--   SCENARIO B — Schedule-recovery overtime:
--                P002 Highway Bridge Repair → 30 OT hours
--                Behind schedule (48% vs 65% expected) → workers pushed hard
--   SCENARIO C — Highest labor % of budget:
--                P001: $24,080 labor / $850k budget = 2.83%
--                P007: $7,036 / $780k = 0.90%
--                P015: $4,992 / $675k = 0.74%
--
-- Pay periods (week ending): 2026-05-03, 05-10, 05-17, 05-24
-- Status: PROCESSED for weeks 05-03 thru 05-17, PENDING for 05-24
-- Overtime rate = 1.5× regular rate (Davis-Bacon / union scale)
-- Projects covered: P001 P002 P003 P005 P007 P009 P011 P013 P015
-- =============================================================

USE DATABASE LEARNING_DB;
USE SCHEMA RAW;

CREATE OR REPLACE TABLE LEARNING_DB.RAW.PAYROLL (
    PAY_ID             VARCHAR(20)    NOT NULL,
    PROJECT_ID         VARCHAR(20)    NOT NULL,
    EMPLOYEE_NAME      VARCHAR(100)   NOT NULL,
    EMPLOYEE_ROLE      VARCHAR(50)    NOT NULL,
    TRADE              VARCHAR(50),
    WEEK_ENDING_DATE   DATE           NOT NULL,
    REGULAR_HOURS      NUMBER(6, 2)   NOT NULL,
    OVERTIME_HOURS     NUMBER(6, 2)   NOT NULL DEFAULT 0,
    REGULAR_RATE       NUMBER(8, 2)   NOT NULL,
    OVERTIME_RATE      NUMBER(8, 2)   NOT NULL,
    REGULAR_PAY        NUMBER(12, 2)  NOT NULL,
    OVERTIME_PAY       NUMBER(12, 2)  NOT NULL DEFAULT 0,
    TOTAL_PAY          NUMBER(12, 2)  NOT NULL,
    COST_CODE          VARCHAR(20),
    QUICKBOOKS_ID      VARCHAR(30)    NOT NULL,
    STATUS             VARCHAR(12)    NOT NULL,
    NOTES              VARCHAR(300),
    CONSTRAINT pk_payroll PRIMARY KEY (PAY_ID)
);

INSERT INTO LEARNING_DB.RAW.PAYROLL VALUES

-- ── P001 Downtown Office Renovation — 8 entries, $24,080 May labor ───────────
-- Highest labor cost $  and highest labor % of budget (2.83%) in the portfolio.
-- Carlos Ruiz (Electrician) accumulates 28 OT hrs over two weeks — key driver
-- of the electrical budget overrun tracked in JOB_COSTS.

('PR-001', 'P001', 'John Martinez',  'Superintendent',    'General',    '2026-05-03',  40.00,  8.00,  65.00,  97.50,  2600.00,   780.00,  3380.00, '01-GenReq',     'QB-2026-PR-001', 'PROCESSED', 'Phase 3 closeout supervision'),
('PR-002', 'P001', 'Carlos Ruiz',    'Electrician',       'Electrical', '2026-05-03',  40.00, 12.00,  72.00, 108.00,  2880.00,  1296.00,  4176.00, '16-Electrical', 'QB-2026-PR-002', 'PROCESSED', 'Electrical trim Phase 3 — 12 OT hrs to hit milestone'),
('PR-003', 'P001', 'Tom Bradley',    'Carpenter',         'Carpentry',  '2026-05-10',  40.00,  4.00,  52.00,  78.00,  2080.00,   312.00,  2392.00, '09-Finishes',   'QB-2026-PR-003', 'PROCESSED', 'Millwork and door hardware install floors 5-8'),
('PR-004', 'P001', 'Maria Santos',   'Project Engineer',  'General',    '2026-05-10',  40.00,  0.00,  48.00,  72.00,  1920.00,     0.00,  1920.00, '01-GenReq',     'QB-2026-PR-004', 'PROCESSED', 'RFI and submittal management'),
('PR-005', 'P001', 'Carlos Ruiz',    'Electrician',       'Electrical', '2026-05-17',  40.00, 16.00,  72.00, 108.00,  2880.00,  1728.00,  4608.00, '16-Electrical', 'QB-2026-PR-005', 'PROCESSED', '16 OT hrs — fixtures and panel terminations, electrical budget at risk'),
('PR-006', 'P001', 'John Martinez',  'Superintendent',    'General',    '2026-05-17',  40.00,  8.00,  65.00,  97.50,  2600.00,   780.00,  3380.00, '01-GenReq',     'QB-2026-PR-006', 'PROCESSED', 'Coordinating MEP closeout, pushing for June 30 delivery'),
('PR-007', 'P001', 'James Lee',      'Laborer',           'General',    '2026-05-24',  40.00,  0.00,  38.00,  57.00,  1520.00,     0.00,  1520.00, '01-GenReq',     'QB-2026-PR-007', 'PENDING',   'Site cleanup and punch list support'),
('PR-008', 'P001', 'Tom Bradley',    'Carpenter',         'Carpentry',  '2026-05-24',  40.00,  8.00,  52.00,  78.00,  2080.00,   624.00,  2704.00, '09-Finishes',   'QB-2026-PR-008', 'PENDING',   'Final millwork punch items — 8 OT to meet turnover date'),

-- ── P002 Highway Bridge Repair — 3 entries, $8,741 May labor ─────────────────
-- 30 OT hours driven by schedule-recovery push (48% actual vs 65% planned).

('PR-009', 'P002', 'Dave Wilson',    'Superintendent',    'General',    '2026-05-03',  40.00, 10.00,  65.00,  97.50,  2600.00,   975.00,  3575.00, '01-GenReq',     'QB-2026-PR-009', 'PROCESSED', '10 OT hrs — Saturday work to recover schedule gap'),
('PR-010', 'P002', 'Miguel Torres',  'Laborer',           'General',    '2026-05-10',  40.00,  8.00,  38.00,  57.00,  1520.00,   456.00,  1976.00, '01-GenReq',     'QB-2026-PR-010', 'PROCESSED', 'Deck prep and formwork — extended shift'),
('PR-011', 'P002', 'Robert Chen',    'Foreman',           'Concrete',   '2026-05-17',  40.00, 12.00,  55.00,  82.50,  2200.00,   990.00,  3190.00, '03-Concrete',   'QB-2026-PR-011', 'PROCESSED', '12 OT hrs — overnight pour to meet CDOT inspection window'),

-- ── P013 Southgate Shopping Expansion — 3 entries, $7,052 May labor ──────────

('PR-012', 'P013', 'Ana Rodriguez',  'Superintendent',    'General',    '2026-05-03',  40.00,  0.00,  65.00,  97.50,  2600.00,     0.00,  2600.00, '01-GenReq',     'QB-2026-PR-012', 'PROCESSED', 'Phase 2 kick-off supervision'),
('PR-013', 'P013', 'Kevin Park',     'Carpenter',         'Carpentry',  '2026-05-10',  40.00,  8.00,  52.00,  78.00,  2080.00,   624.00,  2704.00, '06-Framing',    'QB-2026-PR-013', 'PROCESSED', 'Structural framing Level 2 — weekend push'),
('PR-014', 'P013', 'Luis Garcia',    'Laborer',           'General',    '2026-05-17',  40.00,  4.00,  38.00,  57.00,  1520.00,   228.00,  1748.00, '01-GenReq',     'QB-2026-PR-014', 'PROCESSED', 'Material handling and site support'),

-- ── P003 Riverside Apartments Phase 2 — 2 entries, $4,520 May labor ──────────

('PR-015', 'P003', 'Frank Johnson',  'Superintendent',    'General',    '2026-05-03',  40.00,  0.00,  65.00,  97.50,  2600.00,     0.00,  2600.00, '01-GenReq',     'QB-2026-PR-015', 'PROCESSED', 'Phase 2 structural coordination'),
('PR-016', 'P003', 'Amy Williams',   'Project Engineer',  'General',    '2026-05-10',  40.00,  0.00,  48.00,  72.00,  1920.00,     0.00,  1920.00, '01-GenReq',     'QB-2026-PR-016', 'PROCESSED', 'Submittal log and owner correspondence'),

-- ── P009 Regional Water Treatment Plant — 3 entries, $9,406 May labor ────────

('PR-017', 'P009', 'Steve Martin',   'Superintendent',    'General',    '2026-05-03',  40.00,  4.00,  65.00,  97.50,  2600.00,   390.00,  2990.00, '01-GenReq',     'QB-2026-PR-017', 'PROCESSED', 'Process equipment installation coordination'),
('PR-018', 'P009', 'Brian Lee',      'Plumber',           'Plumbing',   '2026-05-10',  40.00,  8.00,  68.00, 102.00,  2720.00,   816.00,  3536.00, '15-Mechanical', 'QB-2026-PR-018', 'PROCESSED', 'Process piping Phase 2 — county inspection deadline'),
('PR-019', 'P009', 'Chris Brown',    'Electrician',       'Electrical', '2026-05-17',  40.00,  0.00,  72.00, 108.00,  2880.00,     0.00,  2880.00, '16-Electrical', 'QB-2026-PR-019', 'PROCESSED', 'Control panel wiring and I/O testing'),

-- ── P007 Peaks Retail Strip Mall — 2 entries, $7,036 May labor ───────────────

('PR-020', 'P007', 'Pete Wilson',    'Foreman',           'General',    '2026-05-03',  40.00,  8.00,  55.00,  82.50,  2200.00,   660.00,  2860.00, '01-GenReq',     'QB-2026-PR-020', 'PROCESSED', 'Tenant finish coordination — 8 OT to meet lease deadline'),
('PR-021', 'P007', 'Jason Kim',      'Electrician',       'Electrical', '2026-05-10',  40.00, 12.00,  72.00, 108.00,  2880.00,  1296.00,  4176.00, '16-Electrical', 'QB-2026-PR-021', 'PROCESSED', 'Tenant panel and service connections — change order work'),

-- ── P005 Industrial Warehouse Complex — 2 entries, $4,992 May labor ──────────

('PR-022', 'P005', 'Mark Davis',     'Superintendent',    'General',    '2026-05-03',  40.00,  0.00,  65.00,  97.50,  2600.00,     0.00,  2600.00, '01-GenReq',     'QB-2026-PR-022', 'PROCESSED', 'Mezzanine steel coordination with Continental Steel'),
('PR-023', 'P005', 'Tony Lopez',     'Carpenter',         'Carpentry',  '2026-05-17',  40.00,  4.00,  52.00,  78.00,  2080.00,   312.00,  2392.00, '06-Framing',    'QB-2026-PR-023', 'PROCESSED', 'Dock door framing and overhead door blocking'),

-- ── P011 Westfield Parking Structure — 1 entry, $2,695 May labor ─────────────

('PR-024', 'P011', 'Sam Taylor',     'Foreman',           'Concrete',   '2026-05-10',  40.00,  6.00,  55.00,  82.50,  2200.00,   495.00,  2695.00, '03-Concrete',   'QB-2026-PR-024', 'PROCESSED', 'Level 3 deck pour prep — extended shift for early morning pour'),

-- ── P015 Lincoln Elementary Addition — 2 entries, $4,992 May labor ───────────

('PR-025', 'P015', 'Lisa Chen',      'Superintendent',    'General',    '2026-05-03',  40.00,  0.00,  65.00,  97.50,  2600.00,     0.00,  2600.00, '01-GenReq',     'QB-2026-PR-025', 'PROCESSED', 'School board coordination and inspection scheduling'),
('PR-026', 'P015', 'David Park',     'Carpenter',         'Carpentry',  '2026-05-17',  40.00,  4.00,  52.00,  78.00,  2080.00,   312.00,  2392.00, '09-Finishes',   'QB-2026-PR-026', 'PROCESSED', 'Classroom casework and whiteboard framing');

-- ── Verification queries ────────────────────────────────────────────────────

-- SCENARIO A: Total labor cost on Downtown Office (P001) this month
SELECT
    p.PROJECT_NAME,
    COUNT(*)                    AS payroll_entries,
    SUM(py.REGULAR_HOURS)       AS total_regular_hrs,
    SUM(py.OVERTIME_HOURS)      AS total_overtime_hrs,
    SUM(py.TOTAL_PAY)           AS total_labor_cost
FROM LEARNING_DB.RAW.PAYROLL py
JOIN LEARNING_DB.RAW.PROJECTS p ON py.PROJECT_ID = p.PROJECT_ID
WHERE py.PROJECT_ID = 'P001'
  AND DATE_TRUNC('month', py.WEEK_ENDING_DATE) = '2026-05-01'
GROUP BY p.PROJECT_NAME;
-- Expected: 8 entries | 56 OT hrs | $24,080

-- SCENARIO B: Overtime hours by project (May 2026)
SELECT
    p.PROJECT_NAME,
    SUM(py.OVERTIME_HOURS) AS total_overtime_hrs,
    SUM(py.OVERTIME_PAY)   AS total_overtime_cost
FROM LEARNING_DB.RAW.PAYROLL py
JOIN LEARNING_DB.RAW.PROJECTS p ON py.PROJECT_ID = p.PROJECT_ID
WHERE DATE_TRUNC('month', py.WEEK_ENDING_DATE) = '2026-05-01'
GROUP BY p.PROJECT_NAME
ORDER BY total_overtime_hrs DESC;
-- Expected top: P001=56 hrs, P002=30 hrs, P007=20 hrs

-- SCENARIO C: Highest labor cost % of approved budget
SELECT
    p.PROJECT_NAME,
    p.PROJECT_MANAGER,
    p.BUDGET,
    SUM(py.TOTAL_PAY)                                    AS labor_cost_may,
    ROUND((SUM(py.TOTAL_PAY) / p.BUDGET) * 100, 2)      AS labor_pct_of_budget
FROM LEARNING_DB.RAW.PAYROLL py
JOIN LEARNING_DB.RAW.PROJECTS p ON py.PROJECT_ID = p.PROJECT_ID
WHERE DATE_TRUNC('month', py.WEEK_ENDING_DATE) = '2026-05-01'
GROUP BY p.PROJECT_NAME, p.PROJECT_MANAGER, p.BUDGET
ORDER BY labor_pct_of_budget DESC;
-- Expected top: P001 = 2.83%, P007 = 0.90%, P015 = 0.74%

-- Full May summary by project
SELECT
    p.PROJECT_NAME,
    SUM(py.REGULAR_HOURS)  AS reg_hrs,
    SUM(py.OVERTIME_HOURS) AS ot_hrs,
    SUM(py.REGULAR_PAY)    AS reg_pay,
    SUM(py.OVERTIME_PAY)   AS ot_pay,
    SUM(py.TOTAL_PAY)      AS total_pay
FROM LEARNING_DB.RAW.PAYROLL py
JOIN LEARNING_DB.RAW.PROJECTS p ON py.PROJECT_ID = p.PROJECT_ID
GROUP BY p.PROJECT_NAME
ORDER BY total_pay DESC;
-- Grand total: $73,514 across 9 projects, 26 entries
