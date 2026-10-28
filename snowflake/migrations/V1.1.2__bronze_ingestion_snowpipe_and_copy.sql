-- ==============================================================================
-- Migration: V1.1.2__bronze_ingestion_snowpipe_and_copy.sql
-- Description: File Formats, Stages, Snowpipe Continuous Ingest & Batch COPY INTO
-- Use Case:
--   1. Snowpipe: Near real-time order JSON streaming from staged files
--   2. COPY INTO: Batch periodic catalog CSV sync from ERP/Suppliers
-- ==============================================================================

USE ROLE DATA_INGEST_ROLE;
USE WAREHOUSE INGESTION_WH;
USE DATABASE BRONZE_DB;
USE SCHEMA STAGING;

-- -----------------------------------------------------------------------------
-- 1. FILE FORMATS (JSON for Real-Time Orders, CSV for Batch Catalog Sync)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FILE FORMAT BRONZE_DB.STAGING.FF_JSON
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = TRUE
    IGNORE_UTF8_ERRORS = FALSE
    COMPRESSION = AUTO
    COMMENT = 'JSON format for real-time mobile/web checkout order events';

CREATE OR REPLACE FILE FORMAT BRONZE_DB.STAGING.FF_CSV
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('NULL', 'null', '')
    COMMENT = 'CSV format for daily supplier product catalog batch exports';

-- -----------------------------------------------------------------------------
-- 2. STAGES (Internal Stages with External Azure ADLS Gen2 Compatibility)
-- -----------------------------------------------------------------------------
-- Stage for streaming order events (JSON)
CREATE STAGE IF NOT EXISTS BRONZE_DB.STAGING.STAGE_ORDERS_STREAM
    FILE_FORMAT = BRONZE_DB.STAGING.FF_JSON
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for streaming order transactions';

-- Stage for bulk catalog updates (CSV)
CREATE STAGE IF NOT EXISTS BRONZE_DB.STAGING.STAGE_CATALOG_BATCH
    FILE_FORMAT = BRONZE_DB.STAGING.FF_CSV
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for periodic supplier catalog batch sync';

-- -----------------------------------------------------------------------------
-- 3. BRONZE RAW TABLES (Database: BRONZE_DB)
-- -----------------------------------------------------------------------------
USE SCHEMA BRONZE_DB.RAW;

-- Table A: Raw Orders landing table (Semi-structured VARIANT)
CREATE TABLE IF NOT EXISTS BRONZE_DB.RAW.RAW_ORDERS (
    payload VARIANT NOT NULL COMMENT 'Raw nested JSON order payload',
    source_file VARCHAR(500) COMMENT 'Staged file origin',
    file_row_number NUMBER COMMENT 'Row index inside staged file',
    ingested_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'Ingestion timestamp'
)
COMMENT = 'Bronze Raw Landing: Schema-on-read JSON stream ingested via Snowpipe';

-- Table B: Raw Product Catalog master data (Ingested via Batch COPY INTO)
CREATE TABLE IF NOT EXISTS BRONZE_DB.RAW.PRODUCT_CATALOG_RAW (
    product_id VARCHAR(50),
    product_name VARCHAR(255),
    category VARCHAR(100),
    supplier_cost NUMBER(10,2),
    retail_price NUMBER(10,2),
    is_active BOOLEAN,
    batch_loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Bronze Master Data: Bulk product catalog synced via COPY INTO';

-- -----------------------------------------------------------------------------
-- 4. INGESTION PATTERN 1: SNOWPIPE (Serverless Micro-Batch)
-- -----------------------------------------------------------------------------
-- Best Fit: High-frequency, unpredictable arrival, sub-2 minute SLA, serverless billing.
-- On Snowflake internal stages, Snowpipe uses serverless compute pools triggered via REFRESH.
CREATE OR REPLACE PIPE BRONZE_DB.RAW.PIPE_ORDERS_AUTOINGEST
    COMMENT = 'Serverless Snowpipe auto-ingesting order transactions arriving in internal stage'
AS
COPY INTO BRONZE_DB.RAW.RAW_ORDERS (payload, source_file, file_row_number, ingested_at)
FROM (
    SELECT $1, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, CURRENT_TIMESTAMP()
    FROM @BRONZE_DB.STAGING.STAGE_ORDERS_STREAM
)
FILE_FORMAT = (FORMAT_NAME = 'BRONZE_DB.STAGING.FF_JSON')
ON_ERROR = 'SKIP_FILE';

-- -----------------------------------------------------------------------------
-- 5. INGESTION PATTERN 2: BULK COPY INTO (User-Managed Warehouse)
-- -----------------------------------------------------------------------------
-- Best Fit: Scheduled nightly ERP catalog dump, large backfills (>100GB), predictable.
-- Executed on user-managed INGESTION_WH:
-- COPY INTO BRONZE_DB.RAW.PRODUCT_CATALOG_RAW (product_id, product_name, category, supplier_cost, retail_price, is_active, batch_loaded_at)
-- FROM @BRONZE_DB.STAGING.STAGE_CATALOG_BATCH
-- FILE_FORMAT = (FORMAT_NAME = 'BRONZE_DB.STAGING.FF_CSV')
-- ON_ERROR = 'CONTINUE';
