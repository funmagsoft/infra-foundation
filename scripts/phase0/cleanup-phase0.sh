#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize script (parse args, validate env vars, set subscription)
# Note: cleanup script doesn't need --dry-run, but we use init_script for consistency
DRY_RUN=false
init_script

echo "=== Phase 0 Complete Cleanup ==="
log_warning "This will delete ALL resources created in Phase 0!"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  log_info "Aborted."
  exit 1
fi

az account set --subscription "$SUBSCRIPTION_ID"

# Step 1: Delete Service Principals
echo ""
echo "=== Step 1: Deleting Service Principals ==="
for ENV in dev test stage prod; do
  SP_NAME="sp-gha-${PROJECT}-${ENV}"
  APP_ID=$(az ad sp list --filter "displayName eq '${SP_NAME}'" --query "[0].appId" -o tsv 2>/dev/null || echo "")
  
  if [ -n "$APP_ID" ] && [ "$APP_ID" != "null" ] && [ "$APP_ID" != "" ]; then
    echo "Deleting ${SP_NAME} (${APP_ID})..."
    az ad sp delete --id "$APP_ID" 2>/dev/null || true
    log_success "Deleted ${SP_NAME}"
  else
    log_error "${SP_NAME} not found"
  fi
done

# Step 2: Delete Resource Groups
echo ""
echo "=== Step 2: Deleting Resource Groups ==="
for ENV in dev test stage prod; do
  RG_NAME="rg-${PROJECT}-${ENV}"
  
  if az group show --name "$RG_NAME" --output none 2>/dev/null; then
    echo "Deleting ${RG_NAME}..."
    az group delete --name "$RG_NAME" --yes --no-wait
    log_success "Deletion initiated for ${RG_NAME}"
  else
    log_error "${RG_NAME} not found"
  fi
done

echo ""
echo "=== Cleanup Complete ==="
echo "Resource Groups are being deleted asynchronously (may take 5-15 minutes)"
