# ⏱️ 5-Minute Live Demo Presenter's Guide
**Presenter:** Kundan Kumar, Technical Lead (Data & AI Competency)  
**Session Title:** *Engineering Modern Data Pipelines with Snowflake*  
**Architecture:** *OmniRetail 360* (100% Automated, Self-Running Data Platform)

---

## ⚡ Quick Demo Overview (Total Duration: 5 to 7 Minutes)

You do **not** need to manually create files, run batch inserts, or trigger table refreshes during the session. Everything runs **autonomously on schedules**:
- A background generator task feeds JSON checkout transactions into `BRONZE_DB` every minute.
- Dynamic Tables automatically refresh incrementally (`BRONZE_DB -> SILVER_DB -> GOLD_DB`) meeting a 1-minute SLA.
- A CDC Stream on Silver continuously detects incoming orders and a scheduled Task automatically flags high-risk transactions.
- Horizon policies dynamically protect sensitive fields in-place.

---

## 🎬 Minute-by-Minute Speaker Script

### ⏱️ Minute 0: Start the Autonomous Engine (Before You Speak)
In your Snowsight Worksheet, execute:
```sql
CALL UTILS_DB.PUBLIC.SP_START_PIPELINE();
```
*(Tip: You can run this 5 minutes before your session begins so that the pipeline already has a steady flow of automated data).*

---

### ⏱️ Minute 1: The Pipeline Heartbeat View
* **In Snowsight Worksheet, Run Step 1:**
  ```sql
  SELECT * FROM UTILS_DB.PUBLIC.V_LIVE_PIPELINE_STATUS;
  ```
* **What to Say:**  
  > *"Welcome everyone. What you see on screen is our live, autonomous OmniRetail 360 platform running across dedicated Medallion databases: `BRONZE_DB`, `SILVER_DB`, and `GOLD_DB`.*  
  > *Notice that data is actively flowing: raw JSON orders are arriving into Bronze, Silver is continuously flattening the schema using Dynamic Tables, Streams & Tasks are running real-time fraud checks, and Gold is compiling executive revenue KPIs—all without manual intervention."*

---

### ⏱️ Minute 2: Silver Conformed Layer & Catalog Profit Margins
* **In Snowsight Worksheet, Run Step 2:**
  ```sql
  SELECT order_id, customer_name, customer_region, product_name, quantity, 
         unit_price, line_total_amount, supplier_cost, line_gross_profit, order_timestamp 
  FROM SILVER_DB.CONFORMED.DT_ORDERS_FLATTENED 
  ORDER BY order_timestamp DESC LIMIT 5;
  ```
* **What to Say:**  
  > *"Here in the Silver layer, Snowflake's Dynamic Table automatically unnested incoming order items using `LATERAL FLATTEN` on native `VARIANT` JSON, and joined our master product catalog to calculate line-level gross profit. Snowflake automatically manages the incremental change data capture."*

---

### ⏱️ Minute 3: Real-Time Fraud Alerts (Streams & Tasks in Action)
* **In Snowsight Worksheet, Run Step 3:**
  ```sql
  SELECT order_id, customer_name, customer_region, order_total_amount, 
         flag_reason, risk_score, review_status, first_detected_at 
  FROM SILVER_DB.FRAUD.FLAGGED_SUSPICIOUS_ORDERS 
  ORDER BY first_detected_at DESC LIMIT 5;
  ```
* **What to Say:**  
  > *"Why do we need Streams and Tasks when we have Dynamic Tables? Because Dynamic Tables are declarative. If your business requires procedural logic, conditional `MERGE` statements, or automated anomaly alerting, Streams & Tasks are the ideal pattern.*  
  > *A Stream captured incoming orders, and our scheduled Task automatically evaluated risk thresholds and logged high-value anomalies for investigation."*

---

### ⏱️ Minute 4: Snowflake Horizon Governance (Audience "WOW" Moment)
* **In Snowsight Worksheet, Run Step 4.1 (As Admin):**
  ```sql
  USE ROLE ACCOUNTADMIN;
  SELECT order_id, customer_name, customer_email, payment_card_last4, customer_region 
  FROM SILVER_DB.CONFORMED.DT_ORDERS_FLATTENED LIMIT 5;
  ```
  *(Point to the screen: emails, cards, and all regions are visible in plaintext).*

* **Now Run Step 4.2 (Switch to Analyst):**
  ```sql
  USE ROLE DATA_ANALYST_ROLE;
  USE WAREHOUSE BI_WH;
  SELECT order_id, customer_name, customer_email, payment_card_last4, customer_region 
  FROM SILVER_DB.CONFORMED.DT_ORDERS_FLATTENED LIMIT 5;
  ```
* **What to Say:**  
  > *"With Snowflake Horizon, security travels in-place with the data. When I switch to the Analyst role, the exact same table query dynamically masks emails to `sa****@cyberdyne.org`, masks payment cards to `XXXX`, and filters out unauthorized regional rows—without creating a single duplicate table!"*

---

### ⏱️ Minute 5: Gold Revenue KPIs & Zero-Copy Clone
* **In Snowsight Worksheet, Run Step 5.1 & 5.2:**
  ```sql
  -- View Gold KPIs:
  SELECT * FROM GOLD_DB.ANALYTICS.DT_HOURLY_SALES_KPIS ORDER BY total_revenue DESC;

  -- Create Zero-Copy Clone:
  CREATE OR REPLACE DATABASE SILVER_DB_DEV CLONE SILVER_DB;
  ```
* **What to Say:**  
  > *"Our Gold Dynamic Table aggregates executive hourly revenue and profit margins continuously. And when our developers need a test environment, Snowflake's zero-copy cloning branches our entire Silver database in 1.5 seconds at zero additional storage cost."*

---

### ⏱️ Post-Demo Cleanup: Stop Background Tasks
When your session ends, pause background tasks to conserve credits:
```sql
CALL UTILS_DB.PUBLIC.SP_STOP_PIPELINE();
```
