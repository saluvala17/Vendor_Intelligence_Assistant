-- =============================================================
-- 01_setup_schemas.sql
-- Creates the LEARNING_DB database and all required schemas.
-- Run this first as SYSADMIN or ACCOUNTADMIN.
-- =============================================================

-- Create the database
CREATE DATABASE IF NOT EXISTS LEARNING_DB;

-- Use the database
USE DATABASE LEARNING_DB;

-- Raw landing zone — source data as-is from upstream systems
CREATE SCHEMA IF NOT EXISTS LEARNING_DB.RAW;

-- dbt staging models — cleansed and typed views
CREATE SCHEMA IF NOT EXISTS LEARNING_DB.STAGING;

-- dbt mart models — business-ready aggregated tables
CREATE SCHEMA IF NOT EXISTS LEARNING_DB.MART;

-- CI/CD target schema — dbt test runs land here, not in STAGING
CREATE SCHEMA IF NOT EXISTS LEARNING_DB.CI_STAGING;

-- Confirm setup
SHOW SCHEMAS IN DATABASE LEARNING_DB;
