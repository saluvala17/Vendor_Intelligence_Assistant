-- =============================================================
-- 02_raw_vendor_master.sql
-- Creates and seeds LEARNING_DB.RAW.VENDOR_MASTER with 20 vendors.
--
-- Business scenarios baked into data:
--   - 3 HIGH risk vendors (V001, V003, V005) with outstanding AP
--   - 3 contracts expiring within 90 days of 2026-05-22
--   - IT category vendors (V001, V003, V007, V011, V014, V018)
--   - Mix of NET15 / NET30 / NET45 / NET60 payment terms
--   - Account managers: Sarah Johnson, Mike Davis, Robert Brown,
--     Emily Chen, James Wilson
-- =============================================================

USE DATABASE LEARNING_DB;
USE SCHEMA RAW;

CREATE OR REPLACE TABLE LEARNING_DB.RAW.VENDOR_MASTER (
    VENDOR_ID          VARCHAR(20)    NOT NULL,
    VENDOR_NAME        VARCHAR(200)   NOT NULL,
    VENDOR_TYPE        VARCHAR(100),
    COUNTRY            VARCHAR(100),
    PAYMENT_TERMS      VARCHAR(10)    NOT NULL,
    CREDIT_LIMIT       NUMBER(15, 2),
    CONTRACT_START     DATE,
    CONTRACT_END       DATE,
    RISK_RATING        VARCHAR(10)    NOT NULL,
    ACCOUNT_MANAGER    VARCHAR(200),
    STATUS             VARCHAR(10)    NOT NULL,
    ANNUAL_SPEND       NUMBER(15, 2),
    TAX_ID             VARCHAR(50),
    PREFERRED_CURRENCY VARCHAR(5),
    CREATED_DATE       DATE,
    CONSTRAINT pk_vendor_master PRIMARY KEY (VENDOR_ID)
);

INSERT INTO LEARNING_DB.RAW.VENDOR_MASTER VALUES
-- HIGH risk vendors with expiring contracts (V001, V003, V005)
('V001', 'TechSolutions Inc',         'IT',           'USA',     'NET30', 500000,  '2024-01-01', '2026-07-15', 'HIGH',   'Sarah Johnson', 'ACTIVE',   480000,  'TAX-001-US', 'USD', '2024-01-01'),
('V003', 'CloudNet Systems',           'IT',           'USA',     'NET15', 300000,  '2024-03-15', '2026-06-30', 'HIGH',   'Robert Brown',  'ACTIVE',   290000,  'TAX-003-US', 'USD', '2024-03-15'),
('V005', 'Office Supplies Direct',     'Supplies',     'USA',     'NET15', 100000,  '2024-05-01', '2026-05-31', 'HIGH',   'James Wilson',  'ACTIVE',    95000,  'TAX-005-US', 'USD', '2024-05-01'),

-- MEDIUM risk vendors
('V002', 'Global Facilities Corp',     'Facilities',   'United Kingdom', 'NET45', 750000, '2023-06-01', '2027-06-01', 'MEDIUM', 'Mike Davis',   'ACTIVE',   620000,  'TAX-002-UK', 'GBP', '2023-06-01'),
('V007', 'DataCenter Pro',             'IT',           'USA',     'NET30', 600000,  '2023-07-01', '2027-01-01', 'MEDIUM', 'Mike Davis',    'ACTIVE',   550000,  'TAX-007-US', 'USD', '2023-07-01'),
('V009', 'Maintenance Masters',        'Facilities',   'Mexico',  'NET30', 150000,  '2023-09-01', '2027-09-01', 'MEDIUM', 'Robert Brown',  'ACTIVE',   120000,  'TAX-009-MX', 'USD', '2023-09-01'),
('V011', 'NetWork Connect',            'IT',           'USA',     'NET45', 450000,  '2024-02-01', '2027-01-01', 'MEDIUM', 'Sarah Johnson', 'ACTIVE',   420000,  'TAX-011-US', 'USD', '2024-02-01'),
('V013', 'BuildRight Contractors',     'Construction', 'USA',     'NET60', 800000,  '2022-06-01', '2028-06-01', 'MEDIUM', 'Robert Brown',  'ACTIVE',   720000,  'TAX-013-US', 'USD', '2022-06-01'),
('V015', 'Telecom Services Ltd',       'Telecom',      'United Kingdom', 'NET45', 300000, '2023-08-01', '2027-08-01', 'MEDIUM', 'James Wilson', 'ACTIVE',  250000,  'TAX-015-UK', 'GBP', '2023-08-01'),
('V017', 'MarketReach Media',          'Marketing',    'USA',     'NET15', 120000,  '2024-03-01', '2026-09-01', 'MEDIUM', 'Mike Davis',    'INACTIVE',  100000,  'TAX-017-US', 'USD', '2024-03-01'),
('V018', 'TechRepair Pro',             'IT',           'USA',     'NET30', 200000,  '2023-11-01', '2027-11-01', 'MEDIUM', 'Robert Brown',  'ACTIVE',   180000,  'TAX-018-US', 'USD', '2023-11-01'),

-- LOW risk vendors
('V004', 'Logistics Pro LLC',          'Logistics',    'Canada',  'NET30', 200000,  '2023-01-01', '2027-01-01', 'LOW',    'Emily Chen',    'ACTIVE',   150000,  'TAX-004-CA', 'CAD', '2023-01-01'),
('V006', 'Premium Security Services',  'Security',     'USA',     'NET60', 400000,  '2022-01-01', '2027-12-31', 'LOW',    'Sarah Johnson', 'ACTIVE',   320000,  'TAX-006-US', 'USD', '2022-01-01'),
('V008', 'HR Consulting Group',        'Consulting',   'USA',     'NET45', 250000,  '2024-01-15', '2028-01-15', 'LOW',    'Emily Chen',    'ACTIVE',   180000,  'TAX-008-US', 'USD', '2024-01-15'),
('V010', 'Legal Advisory LLC',         'Legal',        'USA',     'NET30', 350000,  '2023-03-01', '2028-03-01', 'LOW',    'James Wilson',  'ACTIVE',   280000,  'TAX-010-US', 'USD', '2023-03-01'),
('V012', 'Freight Forward Inc',        'Logistics',    'Germany', 'NET30', 200000,  '2023-05-01', '2027-05-01', 'LOW',    'Mike Davis',    'ACTIVE',   160000,  'TAX-012-DE', 'EUR', '2023-05-01'),
('V014', 'Cloud Analytics Corp',       'IT',           'USA',     'NET30', 350000,  '2024-04-01', '2027-04-01', 'LOW',    'Emily Chen',    'ACTIVE',   300000,  'TAX-014-US', 'USD', '2024-04-01'),
('V016', 'Environmental Solutions',    'Environmental','USA',     'NET30', 180000,  '2024-01-01', '2027-01-01', 'LOW',    'Sarah Johnson', 'ACTIVE',   140000,  'TAX-016-US', 'USD', '2024-01-01'),
('V019', 'Catering Solutions Inc',     'Catering',     'USA',     'NET15', 80000,   '2024-05-01', '2027-05-01', 'LOW',    'Emily Chen',    'ACTIVE',    65000,  'TAX-019-US', 'USD', '2024-05-01'),
('V020', 'Executive Travel Corp',      'Travel',       'USA',     'NET30', 250000,  '2023-10-01', '2027-10-01', 'LOW',    'James Wilson',  'ACTIVE',   200000,  'TAX-020-US', 'USD', '2023-10-01');

-- Verify load
SELECT RISK_RATING, COUNT(*) AS vendor_count
FROM LEARNING_DB.RAW.VENDOR_MASTER
GROUP BY RISK_RATING
ORDER BY RISK_RATING;
