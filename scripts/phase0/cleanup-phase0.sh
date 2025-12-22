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
  SP_NAME="sp-gha-${PROJECT}-${ENV}"
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
  RG_NAME="rg-${PROJECT}-${ENV}"
  
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
