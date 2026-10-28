#!/usr/bin/env bash
# ==============================================================================
# Local / CI Schemachange Deployment Script (Bash)
# ==============================================================================
set -euo pipefail

SNOWFLAKE_ACCOUNT="${SNOWFLAKE_ACCOUNT:-}"
SNOWFLAKE_USER="${SNOWFLAKE_USER:-}"
SNOWFLAKE_ROLE="${SNOWFLAKE_ROLE:-ACCOUNTADMIN}"
SNOWFLAKE_WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-TRANSFORM_WH}"
SNOWFLAKE_DATABASE="${SNOWFLAKE_DATABASE:-MODERN_DATA_PLATFORM}"
DRY_RUN="${DRY_RUN:-false}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MIGRATIONS_DIR="$PROJECT_ROOT/snowflake/migrations"

echo "=== Schemachange Database Migration Runner ==="
echo "Migrations Directory: $MIGRATIONS_DIR"
echo "Target Database     : $SNOWFLAKE_DATABASE"
echo "Target Role         : $SNOWFLAKE_ROLE"

if ! command -v schemachange &> /dev/null; then
    echo "Installing schemachange..."
    pip install schemachange
fi

CMD=(
    schemachange deploy
    --root-folder "$MIGRATIONS_DIR"
    --snowflake-account "$SNOWFLAKE_ACCOUNT"
    --snowflake-user "$SNOWFLAKE_USER"
    --snowflake-role "$SNOWFLAKE_ROLE"
    --snowflake-warehouse "$SNOWFLAKE_WAREHOUSE"
    --snowflake-database "$SNOWFLAKE_DATABASE"
    --change-history-table "UTILS_DB.CHANGELOG.CHANGE_HISTORY"
    --create-change-history-table
)

if [ "$DRY_RUN" = "true" ]; then
    echo "[DRY RUN ENABLED]"
    CMD+=(--dry-run)
fi

echo "Executing: ${CMD[*]}"
"${CMD[@]}"
