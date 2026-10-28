# Azure to Snowflake Handshake & RBAC Setup Guide

This guide walks you through connecting **Azure Blob Storage & Event Grid** to **Snowflake** via secure **Storage Integrations** and **Notification Integrations** (no shared access keys stored in Snowflake!).

---

## Architecture Flow

```
[Azure Blob Storage: raw-events]
       │ (BlobCreated Event)
       ▼
[Azure Event Grid System Topic]
       │
       ▼
[Azure Storage Queue: snowpipe-ingest-queue]
       │
       ▼ (Notification Integration / Service Principal)
[Snowflake Snowpipe: BRONZE.PIPE_AZURE_ORDERS]
       │ (Auto-Ingest COPY INTO)
       ▼
[Snowflake Bronze Table: BRONZE.RAW_ORDERS_JSON]
```

---

## Step 1: Execute Azure Infrastructure Script
Run the PowerShell or Bash script from this directory:
```powershell
.\01_setup_azure_infrastructure.ps1
```
Note the printed output variables:
- `AZURE_TENANT_ID`
- `AZURE_STORAGE_URL`
- `AZURE_STORAGE_QUEUE_PRIMARY_URI`

---

## Step 2: Create Storage Integration in Snowflake
In Snowflake Snowsight (using `ACCOUNTADMIN`):

```sql
CREATE OR REPLACE STORAGE INTEGRATION AZURE_BLOB_STORAGE_INT
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'AZURE'
  ENABLED = TRUE
  AZURE_TENANT_ID = '<YOUR_AZURE_TENANT_ID>'
  STORAGE_ALLOWED_LOCATIONS = ('azure://<STORAGE_ACCOUNT>.blob.core.windows.net/raw-events/');

-- Retrieve Snowflake's Azure Service Principal details
DESC STORAGE INTEGRATION AZURE_BLOB_STORAGE_INT;
```

Look for two critical fields in the output:
1. `AZURE_CONSENT_URL`: A Microsoft login URL (e.g., `https://login.microsoftonline.com/users/oauth2/authorize?...`).
2. `AZURE_MULTI_TENANT_APP_NAME`: The Snowflake enterprise app identifier in your Azure AD (e.g., `snowflake_prod_...`).

---

## Step 3: Grant Consent in Azure Portal
1. Copy the `AZURE_CONSENT_URL` from Snowflake output and open it in a browser where you are logged into your Azure account.
2. Review the permissions dialog and click **Accept**.
   - This registers Snowflake's multi-tenant application inside your Azure Entra ID (Azure AD) tenant.

---

## Step 4: Grant Role Assignment to Snowflake App in Azure
Now grant Snowflake access to read the blob container:

1. Open **Azure Portal** -> Navigate to your **Storage Account** (`stsnowpipedemo...`).
2. Click **Access Control (IAM)** -> **Add** -> **Add role assignment**.
3. Role: Select **Storage Blob Data Reader** (or *Storage Blob Data Contributor* if Snowflake writes back).
4. Assign access to: **User, group, or service principal**.
5. Select Members: Search for the `AZURE_MULTI_TENANT_APP_NAME` (or "Snowflake").
6. Click **Review + assign**.

---

## Step 5: Configure Snowpipe Auto-Ingest Notification Integration
In Snowflake:

```sql
CREATE OR REPLACE NOTIFICATION INTEGRATION AZURE_SNOWPIPE_NOTIF_INT
  ENABLED = TRUE
  TYPE = QUEUE
  NOTIFICATION_PROVIDER = AZURE_STORAGE_QUEUE
  AZURE_STORAGE_QUEUE_PRIMARY_URI = '<AZURE_STORAGE_QUEUE_PRIMARY_URI>'
  AZURE_TENANT_ID = '<YOUR_AZURE_TENANT_ID>';

DESC NOTIFICATION INTEGRATION AZURE_SNOWPIPE_NOTIF_INT;
```

1. Copy the `AZURE_CONSENT_URL` from the notification integration and accept in browser.
2. In Azure Portal, on the Storage Account or Queue:
   - Go to **Access Control (IAM)** -> **Add role assignment**.
   - Role: **Storage Queue Data Message Receiver**.
   - Assign to: Snowflake Notification Service Principal app name.

---

## Standalone Demo Tip (No Azure Subscription Required!)
If you are presenting this demo in an environment where you don't have active Azure admin access, **don't worry!**
The demo project includes:
1. An **Internal Snowflake Stage** (`@STAGE_INTERNAL_ORDERS`) with pre-configured sample files.
2. A direct Python generator script that can upload straight to Snowflake using `PUT file://... @STAGE_INTERNAL_ORDERS`.
This lets you deliver 100% of the demo flawlessly in front of the audience without depending on Azure cloud credentials!
