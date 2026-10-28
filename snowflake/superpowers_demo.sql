-- ==============================================================================
-- Script: superpowers_demo.sql
-- Topic: Operational Agility: Snowflake's Unique Superpowers
-- Features: Zero-Copy Cloning, Time Travel, UNDROP, Data Sharing
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE SILVER_DB;
USE WAREHOUSE TRANSFORM_WH;

-- =============================================================================
-- SUPERPOWER 1: ZERO-COPY CLONING (Instant Environment Branches)
-- =============================================================================
-- In traditional databases, copying a 10TB database takes hours and doubles
-- storage costs. In Snowflake, metadata pointers create an instant clone in seconds.

-- 1. Create a complete, isolated Dev environment cloned directly from production
CREATE OR REPLACE DATABASE SILVER_DB_DEV 
    CLONE SILVER_DB;

-- 2. Verify: The Dev environment contains all tables, dynamic tables, and schemas
SHOW TABLES IN SILVER_DB_DEV.CONFORMED;

-- 3. Safely test disruptive changes in DEV without affecting PROD:
-- Any edits in DEV write to new micro-partitions; PROD remains 100% untouched!
DELETE FROM SILVER_DB_DEV.CONFORMED.DT_ORDERS_FLATTENED 
WHERE customer_region = 'EMEA';

-- PROD still has all records:
SELECT COUNT(*) AS prod_count FROM SILVER_DB.CONFORMED.DT_ORDERS_FLATTENED;
SELECT COUNT(*) AS dev_count FROM SILVER_DB_DEV.CONFORMED.DT_ORDERS_FLATTENED;


-- =============================================================================
-- SUPERPOWER 2: TIME TRAVEL (Continuous Data Protection & Disaster Recovery)
-- =============================================================================
-- Simulate a developer running an accidental UPDATE/DELETE without a WHERE clause,
-- and recover the table state using Time Travel.

-- 1. Create a demo test table
CREATE OR REPLACE TABLE SILVER_DB.CONFORMED.ORDERS_AUDIT_DEMO AS 
SELECT * FROM SILVER_DB.CONFORMED.DT_ORDERS_FLATTENED;

SELECT order_id, customer_name, line_total_amount FROM SILVER_DB.CONFORMED.ORDERS_AUDIT_DEMO LIMIT 5;

-- 2. SIMULATION: Accidental UPDATE that zeroes out amounts
UPDATE SILVER_DB.CONFORMED.ORDERS_AUDIT_DEMO 
SET line_total_amount = 0.00;

-- Confirm data was altered:
SELECT SUM(line_total_amount) AS ruined_total FROM SILVER_DB.CONFORMED.ORDERS_AUDIT_DEMO;

-- 3. RESCUE USING TIME TRAVEL (Query state of table as it existed 2 minutes ago):
SELECT SUM(line_total_amount) AS recovered_total 
FROM SILVER_DB.CONFORMED.ORDERS_AUDIT_DEMO AT(OFFSET => -60 * 2);

-- 4. Instant rollback to the historical snapshot:
CREATE OR REPLACE TABLE SILVER_DB.CONFORMED.ORDERS_AUDIT_DEMO AS 
SELECT * FROM SILVER_DB.CONFORMED.ORDERS_AUDIT_DEMO AT(OFFSET => -60 * 2);

SELECT SUM(line_total_amount) AS restored_total FROM SILVER_DB.CONFORMED.ORDERS_AUDIT_DEMO;


-- =============================================================================
-- SUPERPOWER 3: UNDROP TABLE (Accidental DROP Recovery)
-- =============================================================================

-- 1. Accidental DROP:
DROP TABLE SILVER_DB.CONFORMED.ORDERS_AUDIT_DEMO;

-- 2. Instant Recovery: One single SQL command restores the table with all micro-partitions
UNDROP TABLE SILVER_DB.CONFORMED.ORDERS_AUDIT_DEMO;

-- 3. Verify table is completely intact:
SELECT COUNT(*) AS restored_records FROM SILVER_DB.CONFORMED.ORDERS_AUDIT_DEMO;


-- =============================================================================
-- SUPERPOWER 4: SECURE DATA SHARING (Zero-Copy Collaboration)
-- =============================================================================
-- Share live governed data without FTP exports, APIs, or sync delays.

CREATE OR REPLACE SHARE SHARE_EXECUTIVE_SALES_PARTNER
    COMMENT = 'Live zero-copy share for external business partners or consumers';

-- Grant database usage to the share
GRANT USAGE ON DATABASE GOLD_DB TO SHARE SHARE_EXECUTIVE_SALES_PARTNER;
GRANT USAGE ON SCHEMA GOLD_DB.REPORTING TO SHARE SHARE_EXECUTIVE_SALES_PARTNER;

-- Grant select on secure views (underlying base tables are NOT exposed)
GRANT SELECT ON VIEW GOLD_DB.REPORTING.V_EXECUTIVE_SALES_OVERVIEW 
    TO SHARE SHARE_EXECUTIVE_SALES_PARTNER;
