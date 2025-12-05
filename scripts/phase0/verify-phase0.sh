#!/bin/bash
set -e

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-<your-subscription-id>}"
# Get script directory and set BASE_DIR relative to infra-foundation root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_BASE="$(cd "$BASE_DIR/.." && pwd)"

echo "=== Phase 0 Verification ==="
echo "Script directory: $SCRIPT_DIR"
echo "Repository base: $BASE_DIR"
echo "Workspace base: $REPO_BASE"
echo ""

ERRORS=0

# Check Azure CLI authentication
echo "1. Checking Azure CLI authentication..."
if az account show --output none 2>/dev/null; then
  echo "   ✓ Azure CLI authenticated"
else
  echo "   ✗ Azure CLI not authenticated"
  ((ERRORS++))
fi

# Check Resource Groups
echo ""
echo "2. Checking Resource Groups..."
for ENV in dev test stage prod; do
  RG_NAME="rg-ecare-${ENV}"
  if az group show --name "$RG_NAME" --output none 2>/dev/null; then
    echo "   ✓ $RG_NAME exists"
  else
    echo "   ✗ $RG_NAME missing"
    ((ERRORS++))
  fi
done

# Check Terraform State Storage Accounts
echo ""
echo "3. Checking Terraform State Storage Accounts..."
for ENV in dev test stage prod; do
  SA_NAME="tfstatefmsecare${ENV}"
  RG_NAME="rg-ecare-${ENV}"
  
  if az storage account show --name "$SA_NAME" --resource-group "$RG_NAME" --output none 2>/dev/null; then
    echo "   ✓ $SA_NAME exists"
    
    # Check container
    if az storage container show --name tfstate --account-name "$SA_NAME" --auth-mode login --output none 2>/dev/null; then
      echo "     ✓ Container 'tfstate' exists"
    else
      echo "     ✗ Container 'tfstate' missing"
      ((ERRORS++))
    fi
  else
    echo "   ✗ $SA_NAME missing"
    ((ERRORS++))
  fi
done

# Check Service Principals
echo ""
echo "4. Checking Service Principals..."
for ENV in dev test stage prod; do
  SP_NAME="sp-gha-ecare-${ENV}"
  if az ad sp list --filter "displayName eq '${SP_NAME}'" --query "[0].displayName" --output tsv 2>/dev/null | grep -q "$SP_NAME"; then
    echo "   ✓ $SP_NAME exists"
  else
    echo "   ✗ $SP_NAME missing"
    ((ERRORS++))
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
      echo "   ✓ ${REPO}/${ENV}/backend.tf exists"
    else
      echo "   ✗ ${REPO}/${ENV}/backend.tf missing"
      ((ERRORS++))
    fi
  done
done

# Check GitHub repositories
echo ""
echo "6. Checking GitHub repositories..."
if [ -d "$BASE_DIR" ] && [ -d "$BASE_DIR/terraform" ]; then
  echo "   ✓ infra-foundation cloned locally"
else
  echo "   ✗ infra-foundation not found locally"
  ((ERRORS++))
fi

for REPO in infra-platform infra-workload-identity; do
  if [ -d "${REPO_BASE}/${REPO}" ]; then
    echo "   ✓ ${REPO} cloned locally"
  else
    echo "   ✗ ${REPO} not found locally"
    ((ERRORS++))
  fi
done

# Summary
echo ""
echo "=== Verification Summary ==="
if [ $ERRORS -eq 0 ]; then
  echo "✓ All checks passed! Ready for Phase 1."
  exit 0
else
  echo "✗ Found $ERRORS error(s). Please fix before proceeding to Phase 1."
  exit 1
fi
