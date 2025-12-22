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
REPO_BASE="$(cd "$BASE_DIR/.." && pwd)"

echo "=== Phase 0 Verification ==="
log_info "Script directory: $SCRIPT_DIR"
log_info "Repository base: $BASE_DIR"
log_info "Workspace base: $REPO_BASE"
echo ""

ERRORS=0

# Check Azure CLI authentication
echo "1. Checking Azure CLI authentication..."
if az account show --output none 2>/dev/null; then
  log_success "Azure CLI authenticated"
else
  log_error "Azure CLI not authenticated"
  ERRORS=$((ERRORS + 1))
fi

# Check Resource Groups
echo ""
echo "2. Checking Resource Groups..."
for ENV in dev test stage prod; do
  RG_NAME="rg-${PROJECT}-${ENV}"
  if az group show --name "$RG_NAME" --output none 2>/dev/null; then
    log_success "$RG_NAME exists"
  else
    log_error "$RG_NAME missing"
    ERRORS=$((ERRORS + 1))
  fi
done

# Check Terraform State Storage Accounts
echo ""
echo "3. Checking Terraform State Storage Accounts..."
for ENV in dev test stage prod; do
  SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"
  RG_NAME="rg-${PROJECT}-${ENV}"
  
  if az storage account show --name "$SA_NAME" --resource-group "$RG_NAME" --output none 2>/dev/null; then
    log_success "$SA_NAME exists"
    
    # Check container
    if az storage container show --name tfstate --account-name "$SA_NAME" --auth-mode login --output none 2>/dev/null; then
      log_success "Container 'tfstate' exists"
    else
      log_error "Container 'tfstate' missing"
      ERRORS=$((ERRORS + 1))
    fi
  else
    log_error "$SA_NAME missing"
    ERRORS=$((ERRORS + 1))
  fi
done

# Check Service Principals
echo ""
echo "4. Checking Service Principals..."
for ENV in dev test stage prod; do
  SP_NAME="sp-gha-${PROJECT}-${ENV}"
  if az ad sp list --filter "displayName eq '${SP_NAME}'" --query "[0].displayName" --output tsv 2>/dev/null | grep -q "$SP_NAME"; then
    log_success "$SP_NAME exists"
  else
    log_error "$SP_NAME missing"
    ERRORS=$((ERRORS + 1))
  fi
done

# Check backend.tf files
echo ""
echo "5. Checking backend.tf files..."
for REPO in infra-foundation infra-platform infra-workload-identity; do
  for ENV in dev test stage prod; do
    if [ "$REPO" == "infra-foundation" ]; then
      BACKEND_FILE="${BASE_DIR}/terraform/environments/${ENV}/backend.tf"
    else
      BACKEND_FILE="${REPO_BASE}/${REPO}/terraform/environments/${ENV}/backend.tf"
    fi
    if [ -f "$BACKEND_FILE" ]; then
      log_success "${REPO}/${ENV}/backend.tf exists"
    else
      log_error "${REPO}/${ENV}/backend.tf missing"
      ERRORS=$((ERRORS + 1))
    fi
  done
done

# Check GitHub repositories
echo ""
echo "6. Checking GitHub repositories..."
if [ -d "$BASE_DIR" ] && [ -d "$BASE_DIR/terraform" ]; then
  log_success "infra-foundation cloned locally"
else
  log_error "infra-foundation not found locally"
  ERRORS=$((ERRORS + 1))
fi

for REPO in infra-platform infra-workload-identity; do
  if [ -d "${REPO_BASE}/${REPO}" ]; then
    log_success "${REPO} cloned locally"
  else
    log_error "${REPO} not found locally"
    ERRORS=$((ERRORS + 1))
  fi
done

# Summary
echo ""
echo "=== Verification Summary ==="
if [ $ERRORS -eq 0 ]; then
  log_success "All checks passed! Ready for Phase 1."
  exit 0
else
  log_error "Found $ERRORS error(s). Please fix before proceeding to Phase 1."
  exit 1
fi
