#!/bin/bash
set -e

# Configuration
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-<your-subscription-id>}"
LOCATION="${LOCATION:-polandcentral}"
ORG="hycom"
PROJ="ecare"

echo "=== Creating Terraform State Storage Accounts ==="
echo "Subscription: $SUBSCRIPTION_ID"
echo "Location: $LOCATION"
echo ""

# Set active subscription
az account set --subscription "$SUBSCRIPTION_ID"

# Create Storage Accounts for all environments
for ENV in dev test stage prod; do
  RG_NAME="rg-ecare-${ENV}"
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
      Project="ecare" \
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

