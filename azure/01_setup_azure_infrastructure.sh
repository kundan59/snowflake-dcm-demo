#!/usr/bin/env bash
# ==============================================================================
# Azure Infrastructure Provisioning for Snowflake Snowpipe Demo (Bash / Cloud Shell)
# ==============================================================================
set -euo pipefail

RESOURCE_GROUP="rg-snowflake-modern-pipeline"
LOCATION="eastus"
RANDOM_SUFFIX=$((RANDOM % 9000 + 1000))
STORAGE_ACCOUNT="stsnowpipedemo${RANDOM_SUFFIX}"
CONTAINER_NAME="raw-events"
QUEUE_NAME="snowpipe-ingest-queue"

echo "=== Provisioning Azure Infrastructure for Snowflake Pipeline ==="
echo "Resource Group  : $RESOURCE_GROUP"
echo "Location        : $LOCATION"
echo "Storage Account : $STORAGE_ACCOUNT"
echo "Container       : $CONTAINER_NAME"
echo "Queue           : $QUEUE_NAME"
echo "================================================================"

# 1. Resource Group
echo "[1/5] Creating Resource Group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" -o table

# 2. Storage Account
echo "[2/5] Creating Storage Account..."
az storage account create \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --allow-blob-public-access false \
    -o table

STORAGE_ID=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
STORAGE_KEY=$(az storage account keys list --account-name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query "[0].value" -o tsv)

# 3. Blob Container
echo "[3/5] Creating Container..."
az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    -o table

# 4. Storage Queue
echo "[4/5] Creating Storage Queue..."
az storage queue create \
    --name "$QUEUE_NAME" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    -o table

QUEUE_ID="$STORAGE_ID/queueservices/default/queues/$QUEUE_NAME"

# 5. Event Grid System Topic & Subscription
echo "[5/5] Creating Event Grid System Topic & Subscription..."
TOPIC_NAME="evgt-${STORAGE_ACCOUNT}"
SUBSCRIPTION_NAME="sub-snowpipe-events"

az eventgrid system-topic create \
    --name "$TOPIC_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --topic-type "Microsoft.Storage.StorageAccounts" \
    --source "$STORAGE_ID" \
    -o table

az eventgrid system-topic event-subscription create \
    --name "$SUBSCRIPTION_NAME" \
    --system-topic-name "$TOPIC_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --endpoint-type storagequeue \
    --endpoint "$QUEUE_ID" \
    --included-event-types "Microsoft.Storage.BlobCreated" \
    --subject-begins-with "/blobServices/default/containers/${CONTAINER_NAME}/blobs/" \
    -o table

TENANT_ID=$(az account show --query tenantId -o tsv)
QUEUE_URI="https://${STORAGE_ACCOUNT}.queue.core.windows.net/${QUEUE_NAME}"

echo ""
echo "=== AZURE CONFIGURATION FOR SNOWFLAKE ==="
echo "AZURE_TENANT_ID                 : $TENANT_ID"
echo "AZURE_STORAGE_URL               : azure://${STORAGE_ACCOUNT}.blob.core.windows.net/${CONTAINER_NAME}/"
echo "AZURE_STORAGE_QUEUE_PRIMARY_URI : $QUEUE_URI"
echo "STORAGE_ACCOUNT_NAME            : $STORAGE_ACCOUNT"
echo "========================================="
