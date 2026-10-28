-- ==============================================================================
-- Script: imperative_alternative_streams_tasks.sql
-- Topic: Imperative Orchestration (Streams & Tasks) vs Declarative (Dynamic Tables)
-- ==============================================================================

USE ROLE DATA_ENGINEER_ROLE;
USE WAREHOUSE TRANSFORM_WH;

-- -----------------------------------------------------------------------------
-- ARCHITECTURAL COMPARISON:
-- In imperative Snowflake architectures, engineers write:
--  1. Target physical table DDL
--  2. A CDC Stream on the source table
--  3. A scheduled Task executing procedural MERGE logic
--  4. Manual DAG task dependency trees (AFTER parent_task)
--
-- With DYNAMIC TABLES (Declarative ELT), Snowflake infers the dependency DAG,
-- tracks CDC under the hood, and refreshes incrementally to meet the target SLA.
-- -----------------------------------------------------------------------------

-- 1. Create a Stream on the Bronze Table to track Change Data Capture (CDC)
CREATE OR REPLACE STREAM BRONZE_DB.RAW.STREAM_RAW_ORDERS ON TABLE BRONZE_DB.RAW.RAW_ORDERS
    APPEND_ONLY = TRUE
    COMMENT = 'CDC Stream capturing arriving JSON rows in Bronze table';

-- 2. Create the Destination Physical Table (Manual Schema Maintenance required)
CREATE OR REPLACE TABLE SILVER_DB.CONFORMED.ORDERS_IMPERATIVE_TARGET (
    order_id STRING,
    customer_id STRING,
    customer_email STRING,
    customer_region STRING,
    item_id STRING,
    product_name STRING,
    quantity NUMBER,
    unit_price NUMBER(12,2),
    line_total_amount NUMBER(12,2),
    event_timestamp TIMESTAMP_NTZ,
    stream_action VARCHAR(10),
    processed_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 3. Create the Scheduled Task with CDC Guard Condition
CREATE OR REPLACE TASK SILVER_DB.CONFORMED.TSK_PROCESS_ORDERS_CDC
    WAREHOUSE = TRANSFORM_WH
    SCHEDULE = '1 MINUTE'
    COMMENT = 'Imperative task executing MERGE/INSERT when new data arrives in stream'
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE_DB.RAW.STREAM_RAW_ORDERS')
AS
INSERT INTO SILVER_DB.CONFORMED.ORDERS_IMPERATIVE_TARGET (
    order_id, customer_id, customer_email, customer_region,
    item_id, product_name, quantity, unit_price, line_total_amount,
    event_timestamp, stream_action
)
SELECT
    s.payload:order.order_id::STRING,
    s.payload:order.customer.customer_id::STRING,
    s.payload:order.customer.email::STRING,
    COALESCE(s.payload:order.customer.region::STRING, 'NA'),
    f.value:item_id::STRING,
    f.value:product_name::STRING,
    f.value:quantity::NUMBER,
    f.value:unit_price::NUMBER(12,2),
    ROUND(f.value:quantity::NUMBER * f.value:unit_price::NUMBER(12,2), 2),
    COALESCE(s.payload:timestamp::TIMESTAMP_NTZ, s.ingested_at::TIMESTAMP_NTZ),
    METADATA$ACTION
FROM BRONZE_DB.RAW.STREAM_RAW_ORDERS s,
LATERAL FLATTEN(input => s.payload:order.items) f;

-- -----------------------------------------------------------------------------
-- KEY TAKEAWAY COMPARISON:
-- • Dynamic Tables: 1 declarative SQL query replaces the Stream, the Table DDL, 
--   the Task, and the schedule logic!
-- • Use Streams & Tasks when: You need procedural IF/ELSE, complex MERGE / 
--   type-2 SCD mutations, external API calls, or stored procedures.
-- • Use Dynamic Tables when: You have SQL-based joins, multi-tier Medallion 
--   pipelines, and need declarative freshness SLAs.
-- -----------------------------------------------------------------------------
