-- ==============================================================================
-- Migration: V1.1.3__silver_gold_dynamic_tables.sql
-- Description: Declarative Multi-Database Medallion Pipeline using Dynamic Tables
-- Use Case:
--   - Silver: Flattens raw JSON, joins batch product catalog, computes profit margin
--   - Gold: Incrementally aggregates executive hourly revenue & profit KPIs
-- ==============================================================================

USE ROLE DATA_ENGINEER_ROLE;
USE WAREHOUSE TRANSFORM_WH;

-- -----------------------------------------------------------------------------
-- 1. SILVER LAYER: Declarative Cleaned & Enriched Dynamic Table (SILVER_DB)
-- -----------------------------------------------------------------------------
-- Best Fit: SQL-based JSON flattening + dimension join with continuous 1-min SLA.
-- No procedural tasks or manual stream management required!
CREATE OR REPLACE DYNAMIC TABLE SILVER_DB.CONFORMED.DT_ORDERS_FLATTENED
    TARGET_LAG = '1 minute'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Silver Layer: Cleaned, conformed orders flattened from Bronze JSON with catalog join'
AS
WITH flattened_orders AS (
    SELECT
        -- Order Header Attributes (Extracted via dot/colon notation from VARIANT)
        e.payload:order.order_id::STRING                            AS order_id,
        e.payload:event_id::STRING                                  AS event_id,
        e.payload:event_type::STRING                                AS event_type,
        COALESCE(e.payload:timestamp::TIMESTAMP_NTZ,
                 e.ingested_at::TIMESTAMP_NTZ)                      AS order_timestamp,

        -- Customer Profile
        e.payload:order.customer.customer_id::STRING                AS customer_id,
        e.payload:order.customer.name::STRING                       AS customer_name,
        e.payload:order.customer.email::STRING                      AS customer_email,
        COALESCE(e.payload:order.customer.region::STRING, 'GLOBAL') AS customer_region,
        e.payload:order.customer.tier::STRING                       AS customer_tier,

        -- Payment Details
        e.payload:order.payment.method::STRING                      AS payment_method,
        e.payload:order.payment.card_last4::STRING                  AS payment_card_last4,
        e.payload:order.payment.currency::STRING                    AS currency,
        e.payload:order.payment.total_amount::NUMBER(12,2)          AS order_total_amount,

        -- Flattened Order Line Items (Array unnesting via LATERAL FLATTEN)
        f.value:item_id::STRING                                     AS item_id,
        f.value:product_name::STRING                                AS item_product_name,
        f.value:category::STRING                                    AS item_category,
        f.value:quantity::NUMBER(10, 0)                             AS quantity,
        f.value:unit_price::NUMBER(12, 2)                           AS unit_price,

        -- Audit Lineage
        e.source_file                                               AS bronze_source_file,
        e.ingested_at                                               AS bronze_ingested_at
    FROM BRONZE_DB.RAW.RAW_ORDERS e,
    LATERAL FLATTEN(input => e.payload:order.items) f
    WHERE e.payload:order.order_id IS NOT NULL
)
SELECT
    fo.order_id,
    fo.event_id,
    fo.event_type,
    fo.order_timestamp,
    fo.customer_id,
    fo.customer_name,
    fo.customer_email,
    fo.customer_region,
    fo.customer_tier,
    fo.payment_method,
    fo.payment_card_last4,
    fo.currency,
    fo.order_total_amount,
    fo.item_id,
    COALESCE(cat.product_name, fo.item_product_name)                AS product_name,
    COALESCE(cat.category, fo.item_category, 'General')            AS product_category,
    fo.quantity,
    fo.unit_price,
    ROUND(fo.quantity * fo.unit_price, 2)                          AS line_total_amount,
    COALESCE(cat.supplier_cost, 0.00)                               AS supplier_cost,
    ROUND((fo.unit_price - COALESCE(cat.supplier_cost, 0.00)) * fo.quantity, 2) AS line_gross_profit,
    fo.bronze_source_file,
    fo.bronze_ingested_at
FROM flattened_orders fo
LEFT JOIN BRONZE_DB.RAW.PRODUCT_CATALOG_RAW cat
    ON fo.item_id = cat.product_id;


-- -----------------------------------------------------------------------------
-- 2. GOLD LAYER: Declarative Business KPI Mart (GOLD_DB)
-- -----------------------------------------------------------------------------
-- Best Fit: Multi-database cascaded aggregation meeting business reporting SLA.
-- Snowflake automatically manages the cross-database dependency graph:
-- BRONZE_DB.RAW_ORDERS -> SILVER_DB.DT_ORDERS_FLATTENED -> GOLD_DB.DT_HOURLY_SALES_KPIS
CREATE OR REPLACE DYNAMIC TABLE GOLD_DB.ANALYTICS.DT_HOURLY_SALES_KPIS
    TARGET_LAG = '1 minute'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Gold Layer: Incremental hourly executive sales, revenue, and margin KPIs'
AS
SELECT
    TO_DATE(order_timestamp)                                    AS sales_date,
    DATE_PART('hour', order_timestamp)                          AS sales_hour,
    product_category,
    customer_region,
    COUNT(DISTINCT order_id)                                    AS total_orders,
    COUNT(DISTINCT customer_id)                                 AS unique_customers,
    SUM(quantity)                                               AS total_units_sold,
    ROUND(SUM(line_total_amount), 2)                            AS total_revenue,
    ROUND(SUM(line_gross_profit), 2)                            AS total_gross_profit,
    ROUND((SUM(line_gross_profit) / NULLIF(SUM(line_total_amount), 0)) * 100, 2) AS profit_margin_pct,
    ROUND(AVG(line_total_amount), 2)                            AS avg_basket_item_value,
    MAX(order_timestamp)                                        AS last_order_processed_at
FROM SILVER_DB.CONFORMED.DT_ORDERS_FLATTENED
GROUP BY
    TO_DATE(order_timestamp),
    DATE_PART('hour', order_timestamp),
    product_category,
    customer_region;
