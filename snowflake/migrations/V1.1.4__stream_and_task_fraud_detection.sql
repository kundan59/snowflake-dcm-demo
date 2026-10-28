-- ==============================================================================
-- Migration: V1.1.4__stream_and_task_fraud_detection.sql
-- Description: Imperative CDC Stream and Task Orchestration for Real-Time Fraud & Anomaly Audit
-- Why Streams & Tasks Best Fit Here:
--   - Dynamic Tables excel at declarative SQL aggregations & DAGs.
--   - Streams & Tasks are REQUIRED when you need:
--       1. Procedural MERGE / Upsert mutations.
--       2. Threshold-based alerting & conditional IF/ELSE branching.
--       3. Event-driven actions (e.g., flagging suspicious transactions for fraud teams).
-- ==============================================================================

USE ROLE DATA_ENGINEER_ROLE;
USE WAREHOUSE TRANSFORM_WH;
USE DATABASE SILVER_DB;
USE SCHEMA FRAUD;

-- -----------------------------------------------------------------------------
-- 1. DESTINATION TABLE: Flagged Suspicious Orders & Fraud Audit
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SILVER_DB.FRAUD.FLAGGED_SUSPICIOUS_ORDERS (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    customer_name VARCHAR(255),
    customer_email VARCHAR(255),
    customer_region VARCHAR(50),
    order_total_amount NUMBER(12,2),
    flag_reason VARCHAR(255),
    risk_score NUMBER(3,0),
    review_status VARCHAR(50) DEFAULT 'PENDING_INVESTIGATION',
    first_detected_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    last_updated_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_fraud_order PRIMARY KEY (order_id)
)
COMMENT = 'Silver Layer: Anomaly and fraud detection audit table maintained via Streams & Tasks';


-- -----------------------------------------------------------------------------
-- 2. CDC STREAM: Change Data Capture on Flattened Orders
-- -----------------------------------------------------------------------------
-- Captures newly arrived orders in Silver Layer.
-- Note: Snowflake supports Streams directly on Dynamic Tables!
CREATE OR REPLACE STREAM SILVER_DB.FRAUD.STREAM_ORDERS_FOR_FRAUD 
    ON DYNAMIC TABLE SILVER_DB.CONFORMED.DT_ORDERS_FLATTENED
    COMMENT = 'CDC stream capturing newly flattened orders for imperative fraud evaluation';


-- -----------------------------------------------------------------------------
-- 3. SCHEDULED TASK: Imperative Orchestration with CDC Guard Condition
-- -----------------------------------------------------------------------------
-- Guard condition: Only wakes up the warehouse WHEN stream has data (Zero wasted credits!)
-- Executes an imperative MERGE statement into the fraud audit table.
CREATE OR REPLACE TASK SILVER_DB.FRAUD.TSK_ANOMALY_DETECTION_ENGINE
    WAREHOUSE = TRANSFORM_WH
    SCHEDULE = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('SILVER_DB.FRAUD.STREAM_ORDERS_FOR_FRAUD')
    COMMENT = 'Imperative task evaluating fraud thresholds and executing MERGE upsert'
AS
MERGE INTO SILVER_DB.FRAUD.FLAGGED_SUSPICIOUS_ORDERS target
USING (
    SELECT 
        order_id,
        customer_id,
        customer_name,
        customer_email,
        customer_region,
        order_total_amount,
        CASE 
            WHEN order_total_amount >= 500.00 AND customer_tier = 'BRONZE' 
                THEN 'HIGH_VALUE_FIRST_TIME_BUYER'
            WHEN order_total_amount >= 400.00 AND customer_region = 'LATAM' 
                THEN 'CROSS_BORDER_ANOMALY'
            ELSE 'VELOCITY_REVIEW'
        END AS flag_reason,
        CASE 
            WHEN order_total_amount >= 500.00 THEN 90
            WHEN order_total_amount >= 300.00 THEN 65
            ELSE 40
        END AS risk_score
    FROM SILVER_DB.FRAUD.STREAM_ORDERS_FOR_FRAUD
    WHERE METADATA$ACTION = 'INSERT'
      AND order_total_amount >= 300.00 -- High-value threshold for manual fraud review
    QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY line_total_amount DESC) = 1
) source
ON target.order_id = source.order_id
WHEN MATCHED THEN
    UPDATE SET 
        target.risk_score = GREATEST(target.risk_score, source.risk_score),
        target.last_updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (order_id, customer_id, customer_name, customer_email, customer_region, 
            order_total_amount, flag_reason, risk_score, review_status, first_detected_at, last_updated_at)
    VALUES (source.order_id, source.customer_id, source.customer_name, source.customer_email, source.customer_region,
            source.order_total_amount, source.flag_reason, source.risk_score, 'PENDING_INVESTIGATION', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());

-- In production, activate the task:
-- ALTER TASK SILVER_DB.FRAUD.TSK_ANOMALY_DETECTION_ENGINE RESUME;
