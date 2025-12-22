#!/bin/bash
set -e

# Validate required environment variables
validate_env_vars() {
  local missing_vars=()
  
  if [ -z "$TENANT_ID" ]; then
    missing_vars+=("TENANT_ID")
  fi
  
  if [ -z "$SUBSCRIPTION_ID" ]; then
    missing_vars+=("SUBSCRIPTION_ID")
  fi
  
  if [ -z "$LOCATION" ]; then
    missing_vars+=("LOCATION")
  fi
  
  if [ -z "$ORGANIZATION" ]; then
    missing_vars+=("ORGANIZATION")
  fi
  
  if [ -z "$PROJECT" ]; then
    missing_vars+=("PROJECT")
  fi
  
  if [ ${#missing_vars[@]} -ne 0 ]; then
    echo "Error: The following required environment variables are not set:" >&2
    for var in "${missing_vars[@]}"; do
      echo "  - $var" >&2
    done
    echo "" >&2
    echo "Please set them before running this script:" >&2
    echo "  export TENANT_ID=\"<your-tenant-id>\"" >&2
    echo "  export SUBSCRIPTION_ID=\"<your-subscription-id>\"" >&2
    echo "  export LOCATION=\"<your-location>\"" >&2
    echo "  export ORGANIZATION=\"<your-organization>\"" >&2
    echo "  export PROJECT=\"<your-project>\"" >&2
    exit 1
  fi
}

# Validate environment variables
validate_env_vars

# Get script directory and set BASE_DIR relative to infra-foundation root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_BASE="$(cd "$BASE_DIR/.." && pwd)"

echo "=== Storage Account Verification ==="
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

# Set active subscription
az account set --subscription "$SUBSCRIPTION_ID"

echo "2. Checking Storage Accounts..."
for ENV in dev test stage prod; do
  SA_NAME="tfstate${ORGANIZATION}${PROJECT}${ENV}"
  RG_NAME="rg-${PROJECT}-${ENV}"
  
  echo "=== Verifying ${SA_NAME} ==="
  
  # Check Storage Account exists
  if az storage account show \
    --name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --query "{Name:name, ResourceGroup:resourceGroup, Location:location, SKU:sku.name}" \
    --output table 2>/dev/null; then
    echo "✓ Storage Account exists"
  else
    echo "✗ Storage Account missing"
    continue
  fi
  
  # Check container exists
  if az storage container show \
    --name tfstate \
    --account-name "$SA_NAME" \
    --auth-mode login \
    --query "{Name:name, PublicAccess:properties.publicAccess}" \
    --output table 2>/dev/null; then
    echo "✓ Container 'tfstate' exists"
  else
    echo "✗ Container 'tfstate' missing"
  fi
  
  # Check versioning enabled
  VERSIONING=$(az storage account blob-service-properties show \
    --account-name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --query "isVersioningEnabled" \
    --output tsv)
  
  if [ "$VERSIONING" == "true" ]; then
    echo "✓ Blob versioning enabled"
  else
    echo "✗ Blob versioning not enabled"
  fi
  
  # Check soft delete enabled
  SOFT_DELETE=$(az storage account blob-service-properties show \
    --account-name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --query "deleteRetentionPolicy.enabled" \
    --output tsv)
  
  if [ "$SOFT_DELETE" == "true" ]; then
    echo "✓ Soft delete enabled"
  else
    echo "✗ Soft delete not enabled"
  fi
  
  echo ""
done
