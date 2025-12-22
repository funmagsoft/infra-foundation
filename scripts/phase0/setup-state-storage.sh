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

# Configuration
ORG="$ORGANIZATION"
PROJ="$PROJECT"

echo "=== Creating Terraform State Storage Accounts ==="
echo "Subscription: $SUBSCRIPTION_ID"
echo "Location: $LOCATION"
echo ""

# Set active subscription
az account set --subscription "$SUBSCRIPTION_ID"

# Create Storage Accounts for all environments
for ENV in dev test stage prod; do
  RG_NAME="rg-${PROJ}-${ENV}"
  SA_NAME="tfstate${ORG}${PROJ}${ENV}"

  echo "--- Creating Storage Account for ${ENV} environment ---"
  echo "Resource Group: $RG_NAME"
  echo "Storage Account: $SA_NAME"

  # Verify Resource Group exists
  if ! az group show --name "$RG_NAME" --output none 2>/dev/null; then
    echo "Error: Resource Group $RG_NAME does not exist. Create it first (Step 3)."
    exit 1
  fi

  # Create Storage Account
  echo "Creating Storage Account..."
  az storage account create \
    --name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --https-only true \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --allow-shared-key-access false \
    --tags \
      Environment="${ENV}" \
      Project="${PROJ}" \
      ManagedBy="terraform" \
      Purpose="terraform-state" \
      CreatedDate="$(date +%Y-%m-%d)" \
    --output none

  echo "✓ Storage Account created"

  # Create container
  echo "Creating container 'tfstate'..."
  az storage container create \
    --name tfstate \
    --account-name "$SA_NAME" \
    --auth-mode login \
    --output none

  echo "✓ Container created"

  # Enable blob versioning and soft delete
  echo "Enabling blob versioning and soft delete..."
  az storage account blob-service-properties update \
    --account-name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --enable-versioning true \
    --enable-delete-retention true \
    --delete-retention-days 30 \
    --output none

  echo "✓ Blob versioning and soft delete enabled"

  echo "✓ Storage Account ${SA_NAME} configured successfully"
  echo ""
done

echo "=== All Storage Accounts Created ==="

