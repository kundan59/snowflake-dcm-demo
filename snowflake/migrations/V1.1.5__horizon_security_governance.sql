-- ==============================================================================
-- Migration: V1.1.5__horizon_security_governance.sql
-- Description: Snowflake Horizon Security - Dynamic Data Masking & Row Access Policies
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE SILVER_DB;
USE SCHEMA GOVERNANCE;

-- -----------------------------------------------------------------------------
-- 1. DYNAMIC DATA MASKING (DDM) POLICIES
-- -----------------------------------------------------------------------------

-- Email Masking: Engineers/Admins see plaintext; Analysts see masked strings
CREATE OR REPLACE MASKING POLICY SILVER_DB.GOVERNANCE.MASK_EMAIL AS (val STRING) 
RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'DATA_ENGINEER_ROLE', 'DATA_INGEST_ROLE') THEN val
        WHEN val IS NULL THEN NULL
        ELSE CONCAT(SUBSTR(val, 1, 2), '****@', SPLIT_PART(val, '@', 2))
    END
COMMENT = 'Horizon DDM: Masks customer email addresses for analyst and consumer roles';

-- Credit Card Masking: Obfuscates payment card numbers
CREATE OR REPLACE MASKING POLICY SILVER_DB.GOVERNANCE.MASK_CARD_LAST4 AS (val STRING) 
RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'DATA_ENGINEER_ROLE') THEN val
        ELSE 'XXXX'
    END
COMMENT = 'Horizon DDM: Obfuscates payment card digits';


-- -----------------------------------------------------------------------------
-- 2. ROW ACCESS POLICIES (RAP)
-- -----------------------------------------------------------------------------

-- Restricts row visibility based on regional entitlement
-- Engineers see global; Analysts see EMEA & APAC; Consumers see EMEA
CREATE OR REPLACE ROW ACCESS POLICY SILVER_DB.GOVERNANCE.RAP_REGIONAL_FILTER AS (region_val STRING) 
RETURNS BOOLEAN ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'DATA_ENGINEER_ROLE', 'DATA_INGEST_ROLE') THEN TRUE
        WHEN CURRENT_ROLE() = 'DATA_ANALYST_ROLE' AND region_val IN ('EMEA', 'APAC') THEN TRUE
        WHEN CURRENT_ROLE() = 'BI_CONSUMER_ROLE'  AND region_val = 'EMEA' THEN TRUE
        ELSE FALSE
    END
COMMENT = 'Horizon RAP: Dynamic row filtering restricting rows by operational region';


-- -----------------------------------------------------------------------------
-- 3. APPLY POLICIES TO SILVER LAYER TABLES
-- -----------------------------------------------------------------------------

-- Apply Masking to Conformed Flattened Orders Dynamic Table
ALTER TABLE SILVER_DB.CONFORMED.DT_ORDERS_FLATTENED 
    MODIFY COLUMN customer_email SET MASKING POLICY SILVER_DB.GOVERNANCE.MASK_EMAIL;

ALTER TABLE SILVER_DB.CONFORMED.DT_ORDERS_FLATTENED 
    MODIFY COLUMN payment_card_last4 SET MASKING POLICY SILVER_DB.GOVERNANCE.MASK_CARD_LAST4;

-- Apply Row Access Policy to Conformed Orders
ALTER TABLE SILVER_DB.CONFORMED.DT_ORDERS_FLATTENED 
    ADD ROW ACCESS POLICY SILVER_DB.GOVERNANCE.RAP_REGIONAL_FILTER ON (customer_region);

-- Apply Masking to Fraud Audit Table
ALTER TABLE SILVER_DB.FRAUD.FLAGGED_SUSPICIOUS_ORDERS 
    MODIFY COLUMN customer_email SET MASKING POLICY SILVER_DB.GOVERNANCE.MASK_EMAIL;

ALTER TABLE SILVER_DB.FRAUD.FLAGGED_SUSPICIOUS_ORDERS 
    ADD ROW ACCESS POLICY SILVER_DB.GOVERNANCE.RAP_REGIONAL_FILTER ON (customer_region);
