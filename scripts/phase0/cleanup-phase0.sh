#!/bin/bash
set -e

# Configuration
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-<your-subscription-id>}"

echo "=== Phase 0 Complete Cleanup ==="
echo "WARNING: This will delete ALL resources created in Phase 0!"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

az account set --subscription "$SUBSCRIPTION_ID"

# Step 1: Delete Service Principals
echo ""
echo "=== Step 1: Deleting Service Principals ==="
for ENV in dev test stage prod; do
  SP_NAME="sp-gha-ecare-${ENV}"
  APP_ID=$(az ad sp list --filter "displayName eq '${SP_NAME}'" --query "[0].appId" -o tsv 2>/dev/null || echo "")
  
  if [ -n "$APP_ID" ] && [ "$APP_ID" != "null" ] && [ "$APP_ID" != "" ]; then
    echo "Deleting ${SP_NAME} (${APP_ID})..."
    az ad sp delete --id "$APP_ID" 2>/dev/null || true
    echo "✓ Deleted ${SP_NAME}"
  else
    echo "✗ ${SP_NAME} not found"
  fi
done

# Step 2: Delete Resource Groups
echo ""
echo "=== Step 2: Deleting Resource Groups ==="
for ENV in dev test stage prod; do
  RG_NAME="rg-ecare-${ENV}"
  
  if az group show --name "$RG_NAME" --output none 2>/dev/null; then
    echo "Deleting ${RG_NAME}..."
    az group delete --name "$RG_NAME" --yes --no-wait
    echo "✓ Deletion initiated for ${RG_NAME}"
  else
    echo "✗ ${RG_NAME} not found"
  fi
done

echo ""
echo "=== Cleanup Complete ==="
echo "Resource Groups are being deleted asynchronously (may take 5-15 minutes)"
