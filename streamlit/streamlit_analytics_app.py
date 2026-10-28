"""
Streamlit in Snowflake (SiS) Demo Application
Can be run natively inside Snowflake Snowsight (Streamlit tab) or locally via:
  pip install streamlit snowflake-snowpark-python
  streamlit run streamlit_analytics_app.py
"""

import streamlit as st
import pandas as pd

# Page Configuration
st.set_page_config(
    page_title="OmniRetail 360 - Modern Data Pipeline",
    page_icon="❄️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom Styling
st.markdown("""
<style>
    .main-title {
        font-size: 2.2rem;
        font-weight: 700;
        color: #29B5E8;
        margin-bottom: 0px;
    }
    .sub-title {
        font-size: 1.0rem;
        color: #8892B0;
        margin-bottom: 25px;
    }
</style>
""", unsafe_allow_html=True)

st.markdown('<p class="main-title">❄️ OmniRetail 360 Data Platform</p>', unsafe_allow_html=True)
st.markdown('<p class="sub-title">Medallion Databases (BRONZE_DB -> SILVER_DB -> GOLD_DB) • Dynamic Tables • Streams & Tasks • Horizon</p>', unsafe_allow_html=True)

# ------------------------------------------------------------------------------
# Database Session Connection (Compatible with Snowsight Native & Local Snowpark)
# ------------------------------------------------------------------------------
@st.cache_resource
def get_snowflake_session():
    try:
        from snowflake.snowpark.context import get_active_session
        return get_active_session()
    except Exception:
        return None

session = get_snowflake_session()

# Sidebar Controls
st.sidebar.title("Pipeline Control Center")

current_role = st.sidebar.selectbox(
    "Active Governance Role (Horizon Test)",
    ["ACCOUNTADMIN", "DATA_ANALYST_ROLE"],
    index=0,
    help="Switch between Admin and Analyst to see Snowflake Horizon Dynamic Data Masking and Row Access Policies live!"
)

st.sidebar.markdown("---")
st.sidebar.markdown("**Architecture Mapping:**")
st.sidebar.markdown("📥 **Snowpipe:** Continuous Real-Time JSON Ingest")
st.sidebar.markdown("📦 **COPY INTO:** Periodic Supplier Catalog Batch Ingest")
st.sidebar.markdown("🥈 **Dynamic Tables:** Declarative Medallion Transforms")
st.sidebar.markdown("⚡ **Streams & Tasks:** Imperative Fraud Detection")
st.sidebar.markdown("---")

# Refresh button
if st.sidebar.button("🔄 Trigger Dynamic Table Refresh"):
    if session:
        try:
            session.sql("ALTER DYNAMIC TABLE SILVER_DB.CONFORMED.DT_ORDERS_FLATTENED REFRESH").collect()
            session.sql("ALTER DYNAMIC TABLE GOLD_DB.ANALYTICS.DT_HOURLY_SALES_KPIS REFRESH").collect()
            st.sidebar.success("Dynamic Tables Refreshed!")
        except Exception as e:
            st.sidebar.error(f"Error: {e}")
    else:
        st.sidebar.info("Demo Mode: Session simulated.")

# ------------------------------------------------------------------------------
# Helper Data Query Function
# ------------------------------------------------------------------------------
def fetch_data(query_sql: str, fallback_df: pd.DataFrame):
    if session:
        try:
            return session.sql(query_sql).to_pandas()
        except Exception:
            return fallback_df
    return fallback_df

# Fallback Sample Data
mock_metrics_df = pd.DataFrame({
    "DATABASE": ["BRONZE_DB.RAW", "SILVER_DB.CONFORMED", "SILVER_DB.FRAUD", "GOLD_DB.ANALYTICS"],
    "OBJECT": ["RAW_ORDERS (Table)", "DT_ORDERS_FLATTENED (Dynamic Table)", "FLAGGED_SUSPICIOUS_ORDERS (Table)", "DT_HOURLY_SALES_KPIS (Dynamic Table)"],
    "PIPELINE PATTERN": ["Snowpipe (Serverless)", "Declarative Dynamic Table (1m Lag)", "Streams & Tasks (Imperative CDC)", "Declarative Dynamic Table (Cascaded)"],
    "STATUS": ["Active (Continuous)", "Healthy (Lag Met)", "Evaluated", "Healthy (Lag Met)"]
})

mock_orders_df = pd.DataFrame({
    "ORDER_ID": ["ORD-EMEA-9001", "ORD-US-9002", "ORD-LATAM-9003"],
    "CUSTOMER_NAME": ["Sarah Connor", "John Doe", "Carlos Gomez"],
    "CUSTOMER_EMAIL": [
        "sarah.connor@cyberdyne.org" if current_role == "ACCOUNTADMIN" else "sa****@cyberdyne.org",
        "john.doe@enterprise.com" if current_role == "ACCOUNTADMIN" else "jo****@enterprise.com",
        "carlos.gomez@suspicious.net" if current_role == "ACCOUNTADMIN" else "ca****@suspicious.net"
    ],
    "PAYMENT_CARD": ["4242", "8899", "1111"] if current_role == "ACCOUNTADMIN" else ["XXXX", "XXXX", "XXXX"],
    "REGION": ["EMEA", "US", "LATAM"],
    "PRODUCT_NAME": ["Snowpark Compute Node", "High-IOPS Flash Volume", "Cortex Generative AI"],
    "TOTAL_AMOUNT": [648.50, 120.00, 748.50]
})

# Filter mock orders by RAP if role is DATA_ANALYST_ROLE (only EMEA and APAC allowed)
if current_role == "DATA_ANALYST_ROLE":
    mock_orders_df = mock_orders_df[mock_orders_df["REGION"].isin(["EMEA", "APAC"])]

mock_fraud_df = pd.DataFrame({
    "ORDER_ID": ["ORD-LATAM-9003"],
    "CUSTOMER_NAME": ["Carlos Gomez"],
    "REGION": ["LATAM"],
    "ORDER_TOTAL": [748.50],
    "FLAG_REASON": ["HIGH_VALUE_FIRST_TIME_BUYER"],
    "RISK_SCORE": [90],
    "REVIEW_STATUS": ["PENDING_INVESTIGATION"]
})

mock_revenue_df = pd.DataFrame({
    "CATEGORY": ["Cloud Infrastructure", "Analytics & AI", "DataOps & Security"],
    "REVENUE": [42500.0, 68900.0, 31200.0],
    "PROFIT": [21200.0, 39500.0, 18400.0]
})

# ------------------------------------------------------------------------------
# Dashboard Layout
# ------------------------------------------------------------------------------

# 1. Pipeline KPIs
kpi1, kpi2, kpi3, kpi4 = st.columns(4)
with kpi1:
    st.metric("Total Platform Revenue", "$142,600", "+18.4%")
with kpi2:
    st.metric("Gross Profit Margin", "55.4%", "+2.3%")
with kpi3:
    st.metric("High-Risk Anomaly Alerts", "1 Order", "Streams & Tasks")
with kpi4:
    st.metric("Dynamic Table Refresh SLA", "1 min", "Target Met")

st.markdown("---")

# 2. Medallion Pipeline Architecture Status
st.subheader("📊 End-to-End Pipeline Health Across Databases")
st.dataframe(mock_metrics_df, use_container_width=True, hide_index=True)

# 3. Live Analytics & Horizon Governance Demonstration
st.subheader("🛡️ Live Silver Layer Data (Dynamic Data Masking & Row Access Policy)")
st.info(f"Currently inspecting as role: **{current_role}**. Notice how the email, card number, and regional row filtering adapt automatically!")

silver_query = """
SELECT 
    order_id, customer_name, customer_email, payment_card_last4,
    customer_region, product_name, line_total_amount
FROM SILVER_DB.CONFORMED.DT_ORDERS_FLATTENED
LIMIT 10;
"""
silver_display_df = fetch_data(silver_query, mock_orders_df)
st.dataframe(silver_display_df, use_container_width=True, hide_index=True)

# 4. Streams & Tasks Fraud Detection Section
st.subheader("⚡ Streams & Tasks Real-Time Fraud & Anomaly Audit (`SILVER_DB.FRAUD`)")
st.dataframe(mock_fraud_df, use_container_width=True, hide_index=True)

# 5. Gold Layer Visualization
col_left, col_right = st.columns(2)

with col_left:
    st.subheader("📈 Revenue by Product Category (Gold Mart)")
    st.bar_chart(mock_revenue_df.set_index("CATEGORY")["REVENUE"])

with col_right:
    st.subheader("💰 Gross Profit Margin Breakdown")
    st.bar_chart(mock_revenue_df.set_index("CATEGORY")["PROFIT"])

# 6. Architecture Summary Footer
st.markdown("---")
st.markdown("""
**How the 5 Core Components Fit into this Single Solution:**
1. **Azure ADLS Gen2:** Central cloud lakehouse holding streaming orders (JSON) & batch catalog (CSV).
2. **Snowpipe (Serverless):** Ingests real-time checkout orders into `BRONZE_DB.RAW.RAW_ORDERS`.
3. **COPY INTO (User WH):** Bulk loads supplier master catalog into `BRONZE_DB.RAW.PRODUCT_CATALOG_RAW`.
4. **Dynamic Tables (Declarative):** Flattens nested JSON, joins catalog for profit margins, and computes hourly KPIs (`SILVER_DB` & `GOLD_DB`).
5. **Streams & Tasks (Imperative):** Evaluates anomaly thresholds and MERGEs flagged high-value orders for fraud review.
""")
