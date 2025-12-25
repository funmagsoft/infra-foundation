#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize script (parse args, validate env vars, set subscription)
# Note: verify scripts don't need --dry-run, but we use init_script for consistency
DRY_RUN=false
init_script

# Get BASE_DIR relative to infra-foundation root
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== GitHub Actions Access Verification ==="
log_info "Script directory: $SCRIPT_DIR"
log_info "Repository base: $BASE_DIR"
log_info "Subscription: $SUBSCRIPTION_ID"
log_info "Tenant: $TENANT_ID"
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

# Check service-principals.env file exists
SP_IDS_FILE="${SCRIPT_DIR}/service-principals.env"
echo "2. Checking service-principals.env file..."
if [ -f "$SP_IDS_FILE" ]; then
  log_success "File exists: $SP_IDS_FILE"
  # Load the file to check variables
  load_env_file "$SP_IDS_FILE"
else
  log_error "File missing: $SP_IDS_FILE"
  log_info "Run setup-access.sh first to create Service Principals"
  ERRORS=$((ERRORS + 1))
fi
echo ""

# Set GitHub organization and repository names (same as setup-access.sh)
FOUNDATION_REPO="${ORGANIZATION}/infra-foundation"
PLATFORM_REPO="${ORGANIZATION}/infra-platform"
WORKLOAD_IDENTITY_REPO="${ORGANIZATION}/infra-workload-identity"

# Verify Service Principals, FIC, and RBAC roles for each environment
echo "3. Verifying Service Principals, FIC, and RBAC roles..."
echo ""

for ENV in dev test stage prod; do
  SP_NAME="sp-gha-${PROJECT}-infra-${ENV}"
  ENV_UPPER=$(echo "$ENV" | tr '[:lower:]' '[:upper:]')
  APP_ID_VAR="${ENV_UPPER}_SP_APP_ID"
  OBJECT_ID_VAR="${ENV_UPPER}_SP_OBJECT_ID"

  eval "APP_ID=\$$APP_ID_VAR"
  eval "OBJECT_ID=\$$OBJECT_ID_VAR"

  RG_NAME="rg-${PROJECT}-${ENV}"
  SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"

  echo "=== Verifying ${SP_NAME} (${ENV} environment) ==="

  # Check if APP_ID is set in environment
  if [ -z "$APP_ID" ]; then
    log_error "${APP_ID_VAR} not found in service-principals.env"
    ERRORS=$((ERRORS + 1))
    echo ""
    continue
  fi

  if [ -z "$OBJECT_ID" ]; then
    log_error "${OBJECT_ID_VAR} not found in service-principals.env"
    ERRORS=$((ERRORS + 1))
    echo ""
    continue
  fi

  log_info "App ID from file: $APP_ID"
  log_info "Object ID from file: $OBJECT_ID"

  # Verify Service Principal exists in Azure AD
  echo "  Checking Service Principal exists..."
  SP_CHECK=$(az ad sp show --id "$APP_ID" --query "{appId:appId, displayName:displayName, id:id}" --output json 2>/dev/null)

  if [ $? -eq 0 ] && [ -n "$SP_CHECK" ]; then
    ACTUAL_APP_ID=$(echo "$SP_CHECK" | jq -r '.appId')
    ACTUAL_DISPLAY_NAME=$(echo "$SP_CHECK" | jq -r '.displayName')
    ACTUAL_OBJECT_ID=$(echo "$SP_CHECK" | jq -r '.id')

    # Verify App ID matches
    if [ "$ACTUAL_APP_ID" == "$APP_ID" ]; then
      log_success "Service Principal exists (App ID matches)"
    else
      log_error "Service Principal App ID mismatch: expected $APP_ID, got $ACTUAL_APP_ID"
      ERRORS=$((ERRORS + 1))
    fi

    # Verify Display Name matches expected
    if [ "$ACTUAL_DISPLAY_NAME" == "$SP_NAME" ]; then
      log_success "Service Principal name matches: $ACTUAL_DISPLAY_NAME"
    else
      log_warning "Service Principal name mismatch: expected $SP_NAME, got $ACTUAL_DISPLAY_NAME"
      WARNINGS=$((WARNINGS + 1))
    fi

    # Verify Object ID matches
    if [ "$ACTUAL_OBJECT_ID" == "$OBJECT_ID" ]; then
      log_success "Object ID matches"
    else
      log_warning "Object ID mismatch: expected $OBJECT_ID, got $ACTUAL_OBJECT_ID"
      WARNINGS=$((WARNINGS + 1))
    fi
  else
    log_error "Service Principal not found in Azure AD (App ID: $APP_ID)"
    ERRORS=$((ERRORS + 1))
    echo ""
    continue
  fi

  # Verify Federated Identity Credentials
  echo "  Checking Federated Identity Credentials..."
  FIC_COUNT=0
  FIC_EXPECTED=3

  # Check FIC for infra-foundation
  FIC_NAME_FOUNDATION="GitHubInfraFoundationEnv-${ENV}"
  if az ad app federated-credential list --id "$APP_ID" --query "[?name=='${FIC_NAME_FOUNDATION}']" --output json 2>/dev/null | jq -e 'length > 0' >/dev/null 2>&1; then
    log_success "FIC exists: ${FIC_NAME_FOUNDATION}"
    FIC_COUNT=$((FIC_COUNT + 1))
  else
    log_error "FIC missing: ${FIC_NAME_FOUNDATION}"
    ERRORS=$((ERRORS + 1))
  fi

  # Check FIC for infra-platform
  FIC_NAME_PLATFORM="GitHubInfraPlatformEnv-${ENV}"
  if az ad app federated-credential list --id "$APP_ID" --query "[?name=='${FIC_NAME_PLATFORM}']" --output json 2>/dev/null | jq -e 'length > 0' >/dev/null 2>&1; then
    log_success "FIC exists: ${FIC_NAME_PLATFORM}"
    FIC_COUNT=$((FIC_COUNT + 1))
  else
    log_error "FIC missing: ${FIC_NAME_PLATFORM}"
    ERRORS=$((ERRORS + 1))
  fi

  # Check FIC for infra-workload-identity
  FIC_NAME_WORKLOAD="GitHubInfraWorkloadIdentityEnv-${ENV}"
  if az ad app federated-credential list --id "$APP_ID" --query "[?name=='${FIC_NAME_WORKLOAD}']" --output json 2>/dev/null | jq -e 'length > 0' >/dev/null 2>&1; then
    log_success "FIC exists: ${FIC_NAME_WORKLOAD}"
    FIC_COUNT=$((FIC_COUNT + 1))
  else
    log_error "FIC missing: ${FIC_NAME_WORKLOAD}"
    ERRORS=$((ERRORS + 1))
  fi

  if [ $FIC_COUNT -eq $FIC_EXPECTED ]; then
    log_success "All ${FIC_EXPECTED} FIC found for ${SP_NAME}"
  else
    log_warning "Only ${FIC_COUNT}/${FIC_EXPECTED} FIC found for ${SP_NAME}"
    WARNINGS=$((WARNINGS + 1))
  fi

  # Verify RBAC Role Assignments
  echo "  Checking RBAC Role Assignments..."

  # Check Contributor role on Resource Group
  RG_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}"
  if az role assignment list \
    --assignee "$APP_ID" \
    --scope "$RG_SCOPE" \
    --role "Contributor" \
    --query "[].{Principal:principalName, Role:roleDefinitionName, Scope:scope}" \
    --output table 2>/dev/null | grep -q "Contributor"; then
    log_success "Contributor role assigned on Resource Group"
  else
    log_error "Contributor role missing on Resource Group"
    ERRORS=$((ERRORS + 1))
  fi

  # Check User Access Administrator role on Resource Group
  if az role assignment list \
    --assignee "$APP_ID" \
    --scope "$RG_SCOPE" \
    --role "User Access Administrator" \
    --query "[].{Principal:principalName, Role:roleDefinitionName, Scope:scope}" \
    --output table 2>/dev/null | grep -q "User Access Administrator"; then
    log_success "User Access Administrator role assigned on Resource Group"
  else
    log_error "User Access Administrator role missing on Resource Group"
    ERRORS=$((ERRORS + 1))
  fi

  # Check Storage Blob Data Contributor role on Storage Account
  SA_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/${SA_NAME}"
  if az role assignment list \
    --assignee "$APP_ID" \
    --scope "$SA_SCOPE" \
    --role "Storage Blob Data Contributor" \
    --query "[].{Principal:principalName, Role:roleDefinitionName, Scope:scope}" \
    --output table 2>/dev/null | grep -q "Storage Blob Data Contributor"; then
    log_success "Storage Blob Data Contributor role assigned on Storage Account"
  else
    log_error "Storage Blob Data Contributor role missing on Storage Account"
    ERRORS=$((ERRORS + 1))
  fi

  # Check Contributor role on Subscription (from SP creation)
  SUB_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"
  if az role assignment list \
    --assignee "$APP_ID" \
    --scope "$SUB_SCOPE" \
    --role "Contributor" \
    --query "[].{Principal:principalName, Role:roleDefinitionName, Scope:scope}" \
    --output table 2>/dev/null | grep -q "Contributor"; then
    log_success "Contributor role assigned on Subscription"
  else
    log_warning "Contributor role missing on Subscription (may have been removed)"
    WARNINGS=$((WARNINGS + 1))
  fi

  echo ""
done

# Summary
echo "=== Verification Summary ==="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  log_success "All verifications passed!"
  echo ""
  echo "Verified:"
  echo "  - Service Principals: 4 (one per environment)"
  echo "  - Federated Identity Credentials: 12 (3 repos × 4 environments)"
  echo "  - RBAC role assignments: Contributor, User Access Administrator, Storage Blob Data Contributor"
  exit 0
elif [ $ERRORS -eq 0 ]; then
  log_warning "Verification completed with ${WARNINGS} warning(s)"
  exit 0
else
  log_error "Verification failed with ${ERRORS} error(s) and ${WARNINGS} warning(s)"
  exit 1
fi
