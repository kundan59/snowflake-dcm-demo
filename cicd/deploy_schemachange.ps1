# ==============================================================================
# Local Schemachange Deployment Script (PowerShell)
# ==============================================================================
param (
    [string]$SnowflakeAccount = $env:SNOWFLAKE_ACCOUNT,
    [string]$SnowflakeUser = $env:SNOWFLAKE_USER,
    [string]$SnowflakePassword = $env:SNOWFLAKE_PASSWORD,
    [string]$SnowflakeRole = "ACCOUNTADMIN",
    [string]$SnowflakeWarehouse = "TRANSFORM_WH",
    [string]$SnowflakeDatabase = "MODERN_DATA_PLATFORM",
    [switch]$DryRun
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Executing Schemachange Database Migrations" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Check if schemachange is installed
if (-not (Get-Command schemachange -ErrorAction SilentlyContinue)) {
    Write-Host "Installing schemachange via pip..." -ForegroundColor Yellow
    pip install schemachange
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$MigrationsDir = Join-Path $ProjectRoot "snowflake\migrations"

Write-Host "Migrations Directory: $MigrationsDir" -ForegroundColor Cyan
Write-Host "Target Database     : $SnowflakeDatabase" -ForegroundColor Cyan
Write-Host "Target Role         : $SnowflakeRole" -ForegroundColor Cyan

# Construct schemachange command
$cmd = "schemachange deploy --root-folder `"$MigrationsDir`" " +
       "--snowflake-account `"$SnowflakeAccount`" " +
       "--snowflake-user `"$SnowflakeUser`" " +
       "--snowflake-role `"$SnowflakeRole`" " +
       "--snowflake-warehouse `"$SnowflakeWarehouse`" " +
       "--snowflake-database `"$SnowflakeDatabase`" " +
       "--change-history-table `"UTILS_DB.CHANGELOG.CHANGE_HISTORY`""

if ($DryRun) {
    Write-Host "`n[DRY RUN MODE ENABLED]" -ForegroundColor Yellow
    $cmd += " --dry-run"
}

Write-Host "`nRunning schemachange..." -ForegroundColor Yellow
Invoke-Expression $cmd
