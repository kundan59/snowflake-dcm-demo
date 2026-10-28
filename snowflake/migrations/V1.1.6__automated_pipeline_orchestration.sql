-- ==============================================================================
-- Migration: V1.1.6__automated_pipeline_orchestration.sql
-- Description: 100% Automated, Self-Running Data Pipeline Architecture
-- Features:
--   1. Automated streaming order generator task (runs on schedule)
--   2. Pre-seeded Product Catalog master data
--   3. Automated CDC stream-to-fraud task activation
--   4. One-click START/STOP stored procedures for the demo
--   5. Real-time pipeline health monitoring view
-- ==============================================================================

USE ROLE ACCOUNTADMIN;

-- -----------------------------------------------------------------------------
-- 1. PRE-SEED PRODUCT CATALOG MASTER DATA (BRONZE_DB)
-- -----------------------------------------------------------------------------
INSERT INTO BRONZE_DB.RAW.PRODUCT_CATALOG_RAW (product_id, product_name, category, supplier_cost, retail_price, is_active)
SELECT * FROM (
    VALUES 
        ('ITM-101', 'Snowpark Compute Node', 'Cloud Infrastructure', 140.00, 249.50, TRUE),
        ('ITM-102', 'High-IOPS Lakehouse Volume', 'Cloud Infrastructure', 65.00, 120.00, TRUE),
        ('ITM-201', 'Cortex Generative AI Suite', 'Analytics & AI', 190.00, 399.00, TRUE),
        ('ITM-301', 'DataOps Governance Suite', 'DataOps & Security', 80.00, 175.50, TRUE)
) AS src (product_id, product_name, category, supplier_cost, retail_price, is_active)
WHERE NOT EXISTS (SELECT 1 FROM BRONZE_DB.RAW.PRODUCT_CATALOG_RAW WHERE product_id = src.product_id);


-- -----------------------------------------------------------------------------
-- 2. AUTOMATED STREAMING ORDER INGESTION TASK (Simulates 24/7 checkouts)
-- -----------------------------------------------------------------------------
-- Generates 3 live nested JSON orders into BRONZE_DB every 1 minute automatically.
CREATE OR REPLACE TASK BRONZE_DB.STAGING.TSK_AUTOMATED_ORDER_STREAM
    WAREHOUSE = INGESTION_WH
    SCHEDULE = '1 MINUTE'
    COMMENT = 'Autonomous task generating realistic orders into Bronze raw landing'
AS
INSERT INTO BRONZE_DB.RAW.RAW_ORDERS (payload, source_file, ingested_at)
SELECT 
    OBJECT_CONSTRUCT(
        'event_id', 'evt_' || UUID_STRING(),
        'event_type', 'order_placed',
        'timestamp', CURRENT_TIMESTAMP()::STRING,
        'order', OBJECT_CONSTRUCT(
            'order_id', 'ORD-' || UNIFORM(10000, 99999, RANDOM()),
            'customer', OBJECT_CONSTRUCT(
                'customer_id', 'CUST-' || UNIFORM(100, 999, RANDOM()),
                'name', CASE UNIFORM(1, 4, RANDOM())
                    WHEN 1 THEN 'Sarah Connor'
                    WHEN 2 THEN 'John Doe'
                    WHEN 3 THEN 'Carlos Gomez'
                    ELSE 'Elena Silva'
                END,
                'email', CASE UNIFORM(1, 4, RANDOM())
                    WHEN 1 THEN 'sarah.connor@cyberdyne.org'
                    WHEN 2 THEN 'john.doe@enterprise.com'
                    WHEN 3 THEN 'carlos.gomez@suspicious.net'
                    ELSE 'elena.silva@saopaulo.br'
                END,
                'region', CASE UNIFORM(1, 4, RANDOM())
                    WHEN 1 THEN 'EMEA'
                    WHEN 2 THEN 'US'
                    WHEN 3 THEN 'LATAM'
                    ELSE 'APAC'
                END,
                'tier', CASE UNIFORM(1, 3, RANDOM())
                    WHEN 1 THEN 'PLATINUM'
                    WHEN 2 THEN 'GOLD'
                    ELSE 'BRONZE'
                END
            ),
            'payment', OBJECT_CONSTRUCT(
                'method', 'CREDIT_CARD',
                'card_last4', LPAD(UNIFORM(1000, 9999, RANDOM())::STRING, 4, '0'),
                'currency', 'USD',
                'total_amount', ROUND(UNIFORM(150, 850, RANDOM())::FLOAT, 2)
            ),
            'items', ARRAY_CONSTRUCT(
                OBJECT_CONSTRUCT('item_id', 'ITM-101', 'product_name', 'Snowpark Compute Node', 'quantity', UNIFORM(1, 2, RANDOM()), 'unit_price', 249.50),
                OBJECT_CONSTRUCT('item_id', 'ITM-201', 'product_name', 'Cortex Generative AI Suite', 'quantity', UNIFORM(1, 2, RANDOM()), 'unit_price', 399.00)
            )
        )
    ),
    'auto_stream_feed.json',
    CURRENT_TIMESTAMP()
FROM TABLE(GENERATOR(ROWCOUNT => 3));


-- -----------------------------------------------------------------------------
-- 3. STORED PROCEDURES: ONE-CLICK START & STOP PIPELINE
-- -----------------------------------------------------------------------------

-- Start Pipeline: Resumes all tasks so the pipeline runs in the background
CREATE OR REPLACE PROCEDURE UTILS_DB.PUBLIC.SP_START_PIPELINE()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    ALTER TASK BRONZE_DB.STAGING.TSK_AUTOMATED_ORDER_STREAM RESUME;
    ALTER TASK SILVER_DB.FRAUD.TSK_ANOMALY_DETECTION_ENGINE RESUME;
    RETURN 'Pipeline STARTED: Streaming ingestion and fraud detection tasks are now running automatically every 1 minute.';
END;
$$;

-- Stop Pipeline: Suspends tasks when the demo is complete to save credits
CREATE OR REPLACE PROCEDURE UTILS_DB.PUBLIC.SP_STOP_PIPELINE()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    ALTER TASK BRONZE_DB.STAGING.TSK_AUTOMATED_ORDER_STREAM SUSPEND;
    ALTER TASK SILVER_DB.FRAUD.TSK_ANOMALY_DETECTION_ENGINE SUSPEND;
    RETURN 'Pipeline STOPPED: Background tasks suspended.';
END;
$$;


-- -----------------------------------------------------------------------------
-- 4. REAL-TIME PIPELINE MONITORING VIEW
-- -----------------------------------------------------------------------------
-- Gives the presenter a single-screen real-time heartbeat view of all 3 databases
CREATE OR REPLACE VIEW UTILS_DB.PUBLIC.V_LIVE_PIPELINE_STATUS AS
SELECT 
    '1. BRONZE_DB (Raw Ingest)' AS pipeline_stage,
    'RAW_ORDERS' AS object_name,
    COUNT(*) AS total_records,
    MAX(ingested_at) AS latest_record_time,
    'Scheduled Stream Task' AS automation_engine
FROM BRONZE_DB.RAW.RAW_ORDERS
UNION ALL
SELECT 
    '2. SILVER_DB (Conformed)' AS pipeline_stage,
    'DT_ORDERS_FLATTENED' AS object_name,
    COUNT(*) AS total_records,
    MAX(order_timestamp) AS latest_record_time,
    'Declarative Dynamic Table (1m Lag)' AS automation_engine
FROM SILVER_DB.CONFORMED.DT_ORDERS_FLATTENED
UNION ALL
SELECT 
    '3. SILVER_DB (Fraud Anomaly)' AS pipeline_stage,
    'FLAGGED_SUSPICIOUS_ORDERS' AS object_name,
    COUNT(*) AS total_records,
    MAX(last_updated_at) AS latest_record_time,
    'Imperative Stream & Task (1m Schedule)' AS automation_engine
FROM SILVER_DB.FRAUD.FLAGGED_SUSPICIOUS_ORDERS
UNION ALL
SELECT 
    '4. GOLD_DB (Analytics Mart)' AS pipeline_stage,
    'DT_HOURLY_SALES_KPIS' AS object_name,
    COUNT(*) AS total_records,
    MAX(last_order_processed_at) AS latest_record_time,
    'Declarative Dynamic Table (Cascaded)' AS automation_engine
FROM GOLD_DB.ANALYTICS.DT_HOURLY_SALES_KPIS;

GRANT USAGE ON DATABASE UTILS_DB TO ROLE DATA_ANALYST_ROLE;
GRANT USAGE ON SCHEMA UTILS_DB.PUBLIC TO ROLE DATA_ANALYST_ROLE;
GRANT SELECT ON VIEW UTILS_DB.PUBLIC.V_LIVE_PIPELINE_STATUS TO ROLE DATA_ANALYST_ROLE;
