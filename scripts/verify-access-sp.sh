#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize script (parse args, validate env vars, set subscription)
# Note: verify scripts don't need --dry-run, but we use init_script for consistency
DRY_RUN=false
init_script

echo "=== Service Principal Access Verification ==="
log_info "Subscription: $SUBSCRIPTION_ID"
echo ""

ERRORS=0
WARNINGS=0

# Check Azure CLI authentication
echo "1. Checking Azure CLI authentication..."
if az account show --output none 2>/dev/null; then
  log_success "Azure CLI authenticated"
else
  log_error "Azure CLI not authenticated"
  ERRORS=$((ERRORS + 1))
fi

# Set active subscription
az account set --subscription "$SUBSCRIPTION_ID"

# Load Service Principal IDs from service-principals.env
SP_IDS_FILE="${SCRIPT_DIR}/service-principals.env"
echo "2. Loading Service Principal IDs..."
if [ ! -f "$SP_IDS_FILE" ]; then
  log_error "File not found: $SP_IDS_FILE"
  log_info "Run setup-access.sh first to create Service Principals and generate this file."
  ERRORS=$((ERRORS + 1))
else
  log_success "File exists: $SP_IDS_FILE"
  if ! load_env_file "$SP_IDS_FILE"; then
    log_error "Failed to load Service Principal IDs from $SP_IDS_FILE"
    ERRORS=$((ERRORS + 1))
  else
    log_success "Service Principal IDs loaded"
  fi
fi
echo ""

# Verify Storage Blob Data Contributor role on all Storage Accounts for each Service Principal
echo "3. Verifying Storage Blob Data Contributor role assignments..."
echo ""

GRANTED=0
TOTAL=0

for ENV in dev test stage prod; do
  RG_NAME="rg-${PROJECT}-${ENV}"
  SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"
  SA_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/${SA_NAME}"
  ENV_UPPER=$(echo "$ENV" | tr '[:lower:]' '[:upper:]')
  APP_ID_VAR="${ENV_UPPER}_SP_APP_ID"
  SP_NAME="sp-gha-${PROJECT}-infra-${ENV}"
  
  eval "APP_ID=\$$APP_ID_VAR"
  
  echo "=== Verifying access for ${SP_NAME} (${ENV} environment) ==="
  
  # Verify APP_ID is set
  if [ -z "$APP_ID" ]; then
    log_error "${APP_ID_VAR} not found in service-principals.env"
    ERRORS=$((ERRORS + 1))
    echo ""
    continue
  fi
  
  log_info "App ID: $APP_ID"
  
  # Check if Storage Account exists
  if ! az storage account show \
    --name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --output none 2>/dev/null; then
    log_error "Storage Account ${SA_NAME} does not exist"
    ERRORS=$((ERRORS + 1))
    echo ""
    continue
  fi
  
  # Check if Service Principal exists in Azure AD
  if ! az ad sp show --id "$APP_ID" --output none 2>/dev/null; then
    log_error "Service Principal ${SP_NAME} (App ID: ${APP_ID}) not found in Azure AD"
    ERRORS=$((ERRORS + 1))
    echo ""
    continue
  fi
  
  TOTAL=$((TOTAL + 1))
  
  # Check if role assignment exists
  ROLE_ASSIGNMENT=$(az role assignment list \
    --assignee "$APP_ID" \
    --scope "$SA_SCOPE" \
    --role "Storage Blob Data Contributor" \
    --query "[].{Principal:principalName, Role:roleDefinitionName, Scope:scope}" \
    --output table 2>/dev/null)
  
  if echo "$ROLE_ASSIGNMENT" | grep -q "Storage Blob Data Contributor"; then
    log_success "Storage Blob Data Contributor role assigned on ${SA_NAME} for ${SP_NAME}"
    GRANTED=$((GRANTED + 1))
  else
    log_error "Storage Blob Data Contributor role missing on ${SA_NAME} for ${SP_NAME}"
    ERRORS=$((ERRORS + 1))
  fi
  
  echo ""
done

# Summary
echo "=== Verification Summary ==="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  log_success "All verifications passed!"
  echo ""
  echo "Verified:"
  echo "  - Service Principals checked: ${TOTAL}"
  echo "  - Storage Blob Data Contributor role assigned: ${GRANTED}/${TOTAL} Service Principals"
  exit 0
elif [ $ERRORS -eq 0 ]; then
  log_warning "Verification completed with ${WARNINGS} warning(s)"
  echo ""
  echo "Status:"
  echo "  - Service Principals checked: ${TOTAL}"
  echo "  - Storage Blob Data Contributor role assigned: ${GRANTED}/${TOTAL} Service Principals"
  exit 0
else
  log_error "Verification failed with ${ERRORS} error(s) and ${WARNINGS} warning(s)"
  echo ""
  echo "Status:"
  echo "  - Service Principals checked: ${TOTAL}"
  echo "  - Storage Blob Data Contributor role assigned: ${GRANTED}/${TOTAL} Service Principals"
  exit 1
fi

