-- ==============================================================================
-- AUTOMATED LIVE DEMO: OMNIRETAIL 360 DATA PLATFORM
--
--
-- Run each step sequentially during your.
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE TRANSFORM_WH;

-- =============================================================================
-- STEP 0: START THE AUTONOMOUS PIPELINE
-- ==============================================================================
-- Activates the automated stream generator and CDC fraud detection tasks.
-- Real orders will flow into BRONZE_DB -> SILVER_DB -> GOLD_DB every 60 seconds automatically.
CALL UTILS_DB.PUBLIC.SP_START_PIPELINE();


-- ==============================================================================
-- STEP 1 : INSPECT AUTOMATED PIPELINE HEARTBEAT
-- ==============================================================================
-- Speaker: " entire pipeline is running autonomously across dedicated databases.
-- Bronze ingests raw streaming JSON, Silver cleans and flattens it via Dynamic Tables,
-- Streams & Tasks continuously audits for fraud, and Gold aggregates revenue KPIs."
SELECT * 
FROM UTILS_DB.PUBLIC.V_LIVE_PIPELINE_STATUS;


-- ==============================================================================
-- STEP 2: VERIFY CONFORMED SILVER LAYER & CATALOG PROFIT MARGINS
-- ==============================================================================
-- Speaker: "Snowflake's Dynamic Table automatically unnested the JSON items array 
-- via LATERAL FLATTEN and joined our master catalog to calculate gross profit margin."
SELECT 
    order_id,
    customer_name,
    customer_region,
    product_name,
    quantity,
    unit_price,
    line_total_amount,
    supplier_cost,
    line_gross_profit,
    order_timestamp
FROM SILVER_DB.CONFORMED.DT_ORDERS_FLATTENED
ORDER BY order_timestamp DESC
LIMIT 5;


-- ==============================================================================
-- STEP 3 : REAL-TIME FRAUD ALERTS (STREAMS & TASKS IN ACTION)
-- ==============================================================================
-- Speaker: "Why do we need Streams & Tasks when we have Dynamic Tables?
-- Because Dynamic Tables are declarative. For procedural IF/ELSE, conditional MERGE,
-- and automated anomaly alerting, Streams & Tasks are the best fit.
-- Notice how high-risk orders were automatically detected and flagged with risk scores!"
SELECT 
    order_id,
    customer_name,
    customer_region,
    order_total_amount,
    flag_reason,
    risk_score,
    review_status,
    first_detected_at
FROM SILVER_DB.FRAUD.FLAGGED_SUSPICIOUS_ORDERS
ORDER BY first_detected_at DESC
LIMIT 5;


-- ==============================================================================
-- STEP 4 : SNOWFLAKE HORIZON GOVERNANCE
-- ==============================================================================

-- 4.1 As Administrator: Full cleartext email and credit card, all regions visible
USE ROLE ACCOUNTADMIN;

SELECT 
    order_id,
    customer_name,
    customer_email,      -- Full plaintext email
    payment_card_last4,  -- Full card digits
    customer_region,     -- All regions (EMEA, US, LATAM, APAC)
    line_total_amount
FROM SILVER_DB.CONFORMED.DT_ORDERS_FLATTENED
LIMIT 5;

-- 4.2 Switch to Analyst: Policies apply dynamically in real time!
USE ROLE DATA_ANALYST_ROLE;
USE WAREHOUSE BI_WH;

SELECT 
    order_id,
    customer_name,
    customer_email,      -- Automatically MASKED to sa****@cyberdyne.org!
    payment_card_last4,  -- Automatically MASKED to XXXX!
    customer_region,     -- Automatically FILTERED by Row Access Policy!
    line_total_amount
FROM SILVER_DB.CONFORMED.DT_ORDERS_FLATTENED
LIMIT 5;

-- Reset back to Administrator:
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE TRANSFORM_WH;


-- ==============================================================================
-- STEP 5: GOLD HOURLY REVENUE KPIS & ZERO-COPY CLONE
-- ==============================================================================
-- 5.1 Gold Layer: Executive sales, volume, and profit margins aggregated automatically
SELECT 
    sales_date,
    product_category,
    customer_region,
    total_orders,
    total_revenue,
    total_gross_profit,
    profit_margin_pct
FROM GOLD_DB.ANALYTICS.DT_HOURLY_SALES_KPIS
ORDER BY total_revenue DESC;

-- 5.2 Superpower: Instant Zero-Copy Clone of Silver DB in 1.5 seconds at $0 storage cost!
CREATE OR REPLACE DATABASE SILVER_DB_DEV CLONE SILVER_DB;

SELECT 'Instant DEV clone ready!' AS status, COUNT(*) AS records 
FROM SILVER_DB_DEV.CONFORMED.DT_ORDERS_FLATTENED;


-- ==============================================================================
-- POST-DEMO CLEANUP: STOP BACKGROUND SIMULATION
-- ==============================================================================
CALL UTILS_DB.PUBLIC.SP_STOP_PIPELINE();
