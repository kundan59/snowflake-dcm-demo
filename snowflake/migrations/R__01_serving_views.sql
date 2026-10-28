-- ==============================================================================
-- Repeatable Migration: R__01_serving_views.sql
-- Description: Downstream Serving Views in GOLD_DB for BI Dashboards & Streamlit
-- ==============================================================================

USE ROLE DATA_ENGINEER_ROLE;
USE DATABASE GOLD_DB;
USE SCHEMA REPORTING;

-- -----------------------------------------------------------------------------
-- 1. EXECUTIVE SALES & MARGIN VIEW (Secure View for BI / PowerBI / Tableau)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE SECURE VIEW GOLD_DB.REPORTING.V_EXECUTIVE_SALES_OVERVIEW AS
SELECT
    sales_date,
    sales_hour,
    product_category,
    customer_region,
    total_orders,
    unique_customers,
    total_units_sold,
    total_revenue,
    total_gross_profit,
    profit_margin_pct,
    avg_basket_item_value,
    last_order_processed_at
FROM GOLD_DB.ANALYTICS.DT_HOURLY_SALES_KPIS;

-- -----------------------------------------------------------------------------
-- 2. HIGH RISK FRAUD AUDIT VIEW
-- -----------------------------------------------------------------------------
CREATE OR REPLACE SECURE VIEW GOLD_DB.REPORTING.V_FRAUD_SECURITY_DASHBOARD AS
SELECT
    order_id,
    customer_id,
    customer_name,
    customer_email,
    customer_region,
    order_total_amount,
    flag_reason,
    risk_score,
    review_status,
    first_detected_at
FROM SILVER_DB.FRAUD.FLAGGED_SUSPICIOUS_ORDERS;

-- Grant permissions to Analyst and Consumer roles
GRANT SELECT ON VIEW GOLD_DB.REPORTING.V_EXECUTIVE_SALES_OVERVIEW TO ROLE DATA_ANALYST_ROLE;
GRANT SELECT ON VIEW GOLD_DB.REPORTING.V_EXECUTIVE_SALES_OVERVIEW TO ROLE BI_CONSUMER_ROLE;
GRANT SELECT ON VIEW GOLD_DB.REPORTING.V_FRAUD_SECURITY_DASHBOARD TO ROLE DATA_ANALYST_ROLE;
