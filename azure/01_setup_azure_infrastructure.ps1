# ==============================================================================
# Azure Infrastructure Provisioning for Snowflake Snowpipe Demo
# Automates: Resource Group, ADLS Gen2 Storage Account, Blob Container,
#            Storage Queue, and Event Grid System Topic for Snowpipe auto-ingest.
# ==============================================================================

param (
    [string]$ResourceGroupName = "rg-snowflake-modern-pipeline",
    [string]$Location = "eastus",
    [string]$StorageAccountName = "stsnowpipedemo$((Get-Random -Minimum 1000 -Maximum 9999))",
    [string]$ContainerName = "raw-events",
    [string]$QueueName = "snowpipe-ingest-queue"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Provisioning Azure Infrastructure for Snowflake Pipeline" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Resource Group   : $ResourceGroupName"
Write-Host "Location         : $Location"
Write-Host "Storage Account  : $StorageAccountName"
Write-Host "Blob Container   : $ContainerName"
Write-Host "Storage Queue    : $QueueName"
Write-Host "=========================================================="

# 1. Create Resource Group
Write-Host "`n[1/5] Creating Resource Group: $ResourceGroupName..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location -o table

# 2. Create Storage Account (Standard LRS, Blob & Data Lake Gen2 enabled)
Write-Host "`n[2/5] Creating Storage Account: $StorageAccountName..." -ForegroundColor Yellow
az storage account create `
    --name $StorageAccountName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --sku Standard_LRS `
    --kind StorageV2 `
    --hns false `
    --allow-blob-public-access false `
    -o table

$StorageAccountId = (az storage account show --name $StorageAccountName --resource-group $ResourceGroupName --query id -o tsv)
$StorageKey = (az storage account keys list --account-name $StorageAccountName --resource-group $ResourceGroupName --query "[0].value" -o tsv)

# 3. Create Blob Container
Write-Host "`n[3/5] Creating Blob Container: $ContainerName..." -ForegroundColor Yellow
az storage container create `
    --name $ContainerName `
    --account-name $StorageAccountName `
    --account-key $StorageKey `
    -o table

# 4. Create Azure Storage Queue (for Snowpipe notification intake)
Write-Host "`n[4/5] Creating Storage Queue: $QueueName..." -ForegroundColor Yellow
az storage queue create `
    --name $QueueName `
    --account-name $StorageAccountName `
    --account-key $StorageKey `
    -o table

$QueueId = "$StorageAccountId/queueservices/default/queues/$QueueName"

# 5. Create Event Grid System Topic & Event Subscription
Write-Host "`n[5/5] Creating Event Grid System Topic & Event Subscription..." -ForegroundColor Yellow
$TopicName = "evgt-$StorageAccountName"
$SubscriptionName = "sub-snowpipe-events"

az eventgrid system-topic create `
    --name $TopicName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --topic-type "Microsoft.Storage.StorageAccounts" `
    --source $StorageAccountId `
    -o table

az eventgrid system-topic event-subscription create `
    --name $SubscriptionName `
    --system-topic-name $TopicName `
    --resource-group $ResourceGroupName `
    --endpoint-type storagequeue `
    --endpoint $QueueId `
    --included-event-types "Microsoft.Storage.BlobCreated" `
    --subject-begins-with "/blobServices/default/containers/$ContainerName/blobs/" `
    -o table

$TenantId = (az account show --query tenantId -o tsv)
$QueueUri = "https://$StorageAccountName.queue.core.windows.net/$QueueName"

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "AZURE PROVISIONING COMPLETE! SAVE THESE VALUES FOR SNOWFLAKE:" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "AZURE_TENANT_ID                     : $TenantId" -ForegroundColor Cyan
Write-Host "AZURE_STORAGE_URL                   : azure://$StorageAccountName.blob.core.windows.net/$ContainerName/" -ForegroundColor Cyan
Write-Host "AZURE_STORAGE_QUEUE_PRIMARY_URI     : $QueueUri" -ForegroundColor Cyan
Write-Host "STORAGE_ACCOUNT_NAME                : $StorageAccountName" -ForegroundColor Cyan
Write-Host "STORAGE_ACCOUNT_KEY (Keep secret)   : $StorageKey" -ForegroundColor Magenta
Write-Host "==========================================================" -ForegroundColor Green
