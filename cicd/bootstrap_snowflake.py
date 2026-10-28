"""
Bootstrap Snowflake Foundations for CI/CD.
Creates:
- Database: UTILS_DB (if not exists)
- Schema: UTILS_DB.CHANGELOG (if not exists)
- Warehouse: TRANSFORM_WH (if not exists)
- Table: UTILS_DB.CHANGELOG.CHANGE_HISTORY (if not exists)
Ensures schemachange has its tracking database, schema, warehouse, and table
ready prior to running versioned migrations.
"""
import os
import sys
import snowflake.connector

def bootstrap():
    account = os.environ.get("SNOWFLAKE_ACCOUNT")
    user = os.environ.get("SNOWFLAKE_USER")
    password = os.environ.get("SNOWFLAKE_PASSWORD")
    role = os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN")

    if not all([account, user, password]):
        print("Missing required Snowflake connection credentials in environment.")
        print(f"  SNOWFLAKE_ACCOUNT set: {bool(account)}")
        print(f"  SNOWFLAKE_USER set: {bool(user)}")
        print(f"  SNOWFLAKE_PASSWORD set: {bool(password)}")
        sys.exit(1)

    print(f"Connecting to Snowflake account: {account} as user: {user} with role: {role}...")
    try:
        conn = snowflake.connector.connect(
            account=account,
            user=user,
            password=password,
            role=role,
        )
        cs = conn.cursor()

        print("Ensuring database UTILS_DB exists...")
        cs.execute("CREATE DATABASE IF NOT EXISTS UTILS_DB")

        print("Ensuring schema UTILS_DB.CHANGELOG exists...")
        cs.execute("CREATE SCHEMA IF NOT EXISTS UTILS_DB.CHANGELOG")

        print("Ensuring warehouse TRANSFORM_WH exists...")
        cs.execute("CREATE WAREHOUSE IF NOT EXISTS TRANSFORM_WH WAREHOUSE_SIZE = XSMALL AUTO_SUSPEND = 60 INITIALLY_SUSPENDED = TRUE")

        print("Ensuring change history table UTILS_DB.CHANGELOG.CHANGE_HISTORY exists...")
        cs.execute("""
            CREATE TABLE IF NOT EXISTS UTILS_DB.CHANGELOG.CHANGE_HISTORY (
                VERSION VARCHAR,
                DESCRIPTION VARCHAR,
                SCRIPT VARCHAR,
                SCRIPT_TYPE VARCHAR,
                CHECKSUM VARCHAR,
                EXECUTION_TIME NUMBER,
                STATUS VARCHAR,
                INSTALLED_BY VARCHAR,
                INSTALLED_ON TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
            )
        """)

        conn.commit()
        cs.close()
        conn.close()
        print("Snowflake foundation bootstrap completed successfully.")
    except Exception as e:
        print(f"Error during bootstrap: {e}")
        raise e

if __name__ == "__main__":
    bootstrap()
