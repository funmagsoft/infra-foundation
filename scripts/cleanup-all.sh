#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize script (parse args, validate env vars, set subscription)
# Note: cleanup script supports --dry-run for safety
init_script "$@"

echo "=== Complete Infrastructure Cleanup ==="
log_dry_run
log_warning "This will delete ALL resources created by setup-* scripts!"
log_warning "This includes:"
log_warning "  - Resource Groups and all resources within them"
log_warning "  - Storage Accounts and containers"
log_warning "  - Service Principals"
log_warning "  - Federated Identity Credentials (FIC)"
log_warning "  - RBAC role assignments"
echo ""

if [ "$DRY_RUN" != true ]; then
  read -p "Are you sure you want to continue? (yes/no): " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    log_info "Aborted."
    exit 1
  fi
fi

ERRORS=0
DELETED=0

# Load Service Principal IDs if file exists
SP_IDS_FILE="${SCRIPT_DIR}/service-principals.env"
if [ -f "$SP_IDS_FILE" ]; then
  log_info "Loading Service Principal IDs from: $SP_IDS_FILE"
  load_env_file "$SP_IDS_FILE"
fi

# ============================================================================
# Step 1: Delete RBAC Role Assignments
# ============================================================================
echo ""
echo "=== Step 1: Deleting RBAC Role Assignments ==="
echo ""

# Delete role assignments for Service Principals
for ENV in dev test stage prod; do
  ENV_UPPER=$(echo "$ENV" | tr '[:lower:]' '[:upper:]')
  APP_ID_VAR="${ENV_UPPER}_SP_APP_ID"
  eval "APP_ID=\$$APP_ID_VAR"
  
  RG_NAME="rg-${PROJECT}-${ENV}"
  SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"
  SP_NAME="sp-gha-${PROJECT}-infra-${ENV}"
  
  # Try to get APP_ID from Azure if not in env file
  if [ -z "$APP_ID" ] || [ "$APP_ID" == "null" ] || [ "$APP_ID" == "" ]; then
    APP_ID=$(az ad sp list --filter "displayName eq '${SP_NAME}'" --query "[0].appId" -o tsv 2>/dev/null || echo "")
  fi
  
  if [ -n "$APP_ID" ] && [ "$APP_ID" != "null" ] && [ "$APP_ID" != "" ]; then
    log_info "--- Deleting role assignments for ${SP_NAME} (App ID: ${APP_ID}) ---"
    
    # Delete role assignments on Storage Account
    SA_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/${SA_NAME}"
    ROLE_ASSIGNMENTS=$(az role assignment list --assignee "$APP_ID" --scope "$SA_SCOPE" --query "[].roleDefinitionName" --output tsv 2>/dev/null)
    if [ -n "$ROLE_ASSIGNMENTS" ]; then
      echo "$ROLE_ASSIGNMENTS" | while read -r role_name; do
        if [ -n "$role_name" ]; then
          if run_cmd az role assignment delete --assignee "$APP_ID" --scope "$SA_SCOPE" --role "$role_name" --output none 2>/dev/null; then
            log_success "Deleted role assignment: $role_name on Storage Account"
          fi
        fi
      done
    else
      log_info "No role assignments found on Storage Account for ${SP_NAME}"
    fi
    
    # Delete role assignments on Resource Group
    RG_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}"
    ROLE_ASSIGNMENTS=$(az role assignment list --assignee "$APP_ID" --scope "$RG_SCOPE" --query "[].roleDefinitionName" --output tsv 2>/dev/null)
    if [ -n "$ROLE_ASSIGNMENTS" ]; then
      echo "$ROLE_ASSIGNMENTS" | while read -r role_name; do
        if [ -n "$role_name" ]; then
          if run_cmd az role assignment delete --assignee "$APP_ID" --scope "$RG_SCOPE" --role "$role_name" --output none 2>/dev/null; then
            log_success "Deleted role assignment: $role_name on Resource Group"
          fi
        fi
      done
    else
      log_info "No role assignments found on Resource Group for ${SP_NAME}"
    fi
    
    # Delete role assignments on Subscription
    SUB_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"
    ROLE_ASSIGNMENTS=$(az role assignment list --assignee "$APP_ID" --scope "$SUB_SCOPE" --query "[].roleDefinitionName" --output tsv 2>/dev/null)
    if [ -n "$ROLE_ASSIGNMENTS" ]; then
      echo "$ROLE_ASSIGNMENTS" | while read -r role_name; do
        if [ -n "$role_name" ]; then
          if run_cmd az role assignment delete --assignee "$APP_ID" --scope "$SUB_SCOPE" --role "$role_name" --output none 2>/dev/null; then
            log_success "Deleted role assignment: $role_name on Subscription"
          fi
        fi
      done
    else
      log_info "No role assignments found on Subscription for ${SP_NAME}"
    fi
  else
    log_warning "${SP_NAME} App ID not found, skipping role assignment deletion"
  fi
done

# Delete role assignments for current user (Storage Blob Data Contributor)
log_info "--- Deleting role assignments for current user ---"
CURRENT_USER_OBJECT_ID=$(az ad signed-in-user show --query id --output tsv 2>/dev/null || echo "")
if [ -z "$CURRENT_USER_OBJECT_ID" ] || [ "$CURRENT_USER_OBJECT_ID" == "null" ]; then
  CURRENT_USER_EMAIL=$(az account show --query user.name --output tsv)
  CURRENT_USER_OBJECT_ID=$(az ad user show --id "$CURRENT_USER_EMAIL" --query id --output tsv 2>/dev/null || echo "")
fi

if [ -n "$CURRENT_USER_OBJECT_ID" ] && [ "$CURRENT_USER_OBJECT_ID" != "null" ]; then
  for ENV in dev test stage prod; do
    RG_NAME="rg-${PROJECT}-${ENV}"
    SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"
    SA_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/${SA_NAME}"
    
    if run_cmd az role assignment delete --assignee "$CURRENT_USER_OBJECT_ID" --scope "$SA_SCOPE" --role "Storage Blob Data Contributor" --output none 2>/dev/null; then
      log_success "Deleted Storage Blob Data Contributor role for current user on ${SA_NAME}"
    fi
  done
fi

# ============================================================================
# Step 2: Delete Federated Identity Credentials (FIC)
# ============================================================================
echo ""
echo "=== Step 2: Deleting Federated Identity Credentials ==="
echo ""

for ENV in dev test stage prod; do
  ENV_UPPER=$(echo "$ENV" | tr '[:lower:]' '[:upper:]')
  APP_ID_VAR="${ENV_UPPER}_SP_APP_ID"
  eval "APP_ID=\$$APP_ID_VAR"
  
  SP_NAME="sp-gha-${PROJECT}-infra-${ENV}"
  
  # Try to get APP_ID from Azure if not in env file
  if [ -z "$APP_ID" ] || [ "$APP_ID" == "null" ] || [ "$APP_ID" == "" ]; then
    APP_ID=$(az ad sp list --filter "displayName eq '${SP_NAME}'" --query "[0].appId" -o tsv 2>/dev/null || echo "")
  fi
  
  if [ -n "$APP_ID" ] && [ "$APP_ID" != "null" ] && [ "$APP_ID" != "" ]; then
    log_info "--- Deleting FIC for ${SP_NAME} (App ID: ${APP_ID}) ---"
    
    # List and delete all FIC for this Service Principal
    if [ "$DRY_RUN" = true ]; then
      # In dry-run mode, check if FIC exist
      FIC_IDS=$(az ad app federated-credential list --id "$APP_ID" --query "[].id" --output tsv 2>/dev/null)
      if [ -n "$FIC_IDS" ]; then
        echo "$FIC_IDS" | while read -r fic_id; do
          if [ -n "$fic_id" ]; then
            FIC_NAME=$(az ad app federated-credential show --id "$APP_ID" --federated-credential-id "$fic_id" --query "name" --output tsv 2>/dev/null || echo "unknown")
            log_info "[DRY-RUN] Would delete FIC: $FIC_NAME"
          fi
        done
      else
        log_info "No FIC found for ${SP_NAME}"
      fi
    else
      FIC_IDS=$(az ad app federated-credential list --id "$APP_ID" --query "[].id" --output tsv 2>/dev/null)
      if [ -n "$FIC_IDS" ]; then
        echo "$FIC_IDS" | while read -r fic_id; do
          if [ -n "$fic_id" ]; then
            FIC_NAME=$(az ad app federated-credential show --id "$APP_ID" --federated-credential-id "$fic_id" --query "name" --output tsv 2>/dev/null || echo "unknown")
            if run_cmd az ad app federated-credential delete --id "$APP_ID" --federated-credential-id "$fic_id" --output none 2>/dev/null; then
              log_success "Deleted FIC: $FIC_NAME"
            fi
          fi
        done
      else
        log_info "No FIC found for ${SP_NAME}"
      fi
    fi
  else
    log_warning "${SP_NAME} App ID not found, skipping FIC deletion"
  fi
done

# ============================================================================
# Step 3: Delete Service Principals
# ============================================================================
echo ""
echo "=== Step 3: Deleting Service Principals ==="
echo ""

for ENV in dev test stage prod; do
  SP_NAME="sp-gha-${PROJECT}-infra-${ENV}"
  ENV_UPPER=$(echo "$ENV" | tr '[:lower:]' '[:upper:]')
  APP_ID_VAR="${ENV_UPPER}_SP_APP_ID"
  eval "APP_ID=\$$APP_ID_VAR"
  
  # Try to get APP_ID from Azure if not in env file
  if [ -z "$APP_ID" ] || [ "$APP_ID" == "null" ] || [ "$APP_ID" == "" ]; then
    APP_ID=$(az ad sp list --filter "displayName eq '${SP_NAME}'" --query "[0].appId" -o tsv 2>/dev/null || echo "")
  fi
  
  if [ -n "$APP_ID" ] && [ "$APP_ID" != "null" ] && [ "$APP_ID" != "" ]; then
    log_info "Deleting ${SP_NAME} (${APP_ID})..."
    if run_cmd az ad sp delete --id "$APP_ID" --output none 2>/dev/null; then
      log_success "Deleted ${SP_NAME}"
      DELETED=$((DELETED + 1))
    else
      log_error "Failed to delete ${SP_NAME}"
      ERRORS=$((ERRORS + 1))
    fi
  else
    log_warning "${SP_NAME} not found, skipping..."
  fi
done

# ============================================================================
# Step 4: Delete Storage Accounts and Containers
# ============================================================================
echo ""
echo "=== Step 4: Deleting Storage Accounts ==="
echo ""

for ENV in dev test stage prod; do
  RG_NAME="rg-${PROJECT}-${ENV}"
  SA_NAME="tfstate${ORGANIZATION_FOR_SA}${PROJECT}${ENV}"
  
  log_info "--- Deleting Storage Account: ${SA_NAME} ---"
  
  # Check if Storage Account exists
  if [ "$DRY_RUN" != true ]; then
    if az storage account show --name "$SA_NAME" --resource-group "$RG_NAME" --output none 2>/dev/null; then
      # Delete all containers first
      log_info "Deleting containers in ${SA_NAME}..."
      CONTAINERS=$(az storage container list --account-name "$SA_NAME" --auth-mode login --query "[].name" --output tsv 2>/dev/null)
      if [ -n "$CONTAINERS" ]; then
        echo "$CONTAINERS" | while read -r container_name; do
          if run_cmd az storage container delete --name "$container_name" --account-name "$SA_NAME" --auth-mode login --output none 2>/dev/null; then
            log_success "Deleted container: $container_name"
          fi
        done
      fi
      
      # Delete Storage Account
      if run_cmd az storage account delete --name "$SA_NAME" --resource-group "$RG_NAME" --yes --output none 2>/dev/null; then
        log_success "Deleted Storage Account: ${SA_NAME}"
        DELETED=$((DELETED + 1))
      else
        log_error "Failed to delete Storage Account: ${SA_NAME}"
        ERRORS=$((ERRORS + 1))
      fi
    else
      log_warning "Storage Account ${SA_NAME} not found, skipping..."
    fi
  else
    log_info "[DRY-RUN] Would delete Storage Account: ${SA_NAME} and all containers"
  fi
  
  echo ""
done

# ============================================================================
# Step 5: Delete Resource Groups (this will delete any remaining resources)
# ============================================================================
echo ""
echo "=== Step 5: Deleting Resource Groups ==="
echo ""

for ENV in dev test stage prod; do
  RG_NAME="rg-${PROJECT}-${ENV}"
  
  log_info "--- Deleting Resource Group: ${RG_NAME} ---"
  
  if [ "$DRY_RUN" != true ]; then
    if az group show --name "$RG_NAME" --output none 2>/dev/null; then
      log_info "Deleting Resource Group ${RG_NAME} (this will delete all remaining resources)..."
      if run_cmd az group delete --name "$RG_NAME" --yes --no-wait --output none 2>/dev/null; then
        log_success "Deletion initiated for ${RG_NAME}"
        DELETED=$((DELETED + 1))
      else
        log_error "Failed to delete Resource Group: ${RG_NAME}"
        ERRORS=$((ERRORS + 1))
      fi
    else
      log_warning "Resource Group ${RG_NAME} not found, skipping..."
    fi
  else
    log_info "[DRY-RUN] Would delete Resource Group: ${RG_NAME} (and all resources within it)"
  fi
  
  echo ""
done

# ============================================================================
# Step 6: Clean up service-principals.env file
# ============================================================================
echo ""
echo "=== Step 6: Cleaning up service-principals.env file ==="
echo ""

if [ "$DRY_RUN" != true ]; then
  if [ -f "$SP_IDS_FILE" ]; then
    if run_cmd rm -f "$SP_IDS_FILE"; then
      log_success "Deleted service-principals.env file"
    else
      log_warning "Failed to delete service-principals.env file"
    fi
  else
    log_info "service-principals.env file not found, skipping..."
  fi
else
  log_info "[DRY-RUN] Would delete service-principals.env file"
fi

# Summary
echo ""
echo "=== Cleanup Summary ==="
if [ "$DRY_RUN" = true ]; then
  log_info "*** DRY-RUN MODE: No changes were made ***"
  log_info "Would delete:"
  log_info "  - RBAC role assignments"
  log_info "  - Federated Identity Credentials"
  log_info "  - Service Principals (4)"
  log_info "  - Storage Accounts and containers (4)"
  log_info "  - Resource Groups (4)"
  log_info "  - service-principals.env file"
else
  if [ $ERRORS -eq 0 ]; then
    log_success "Cleanup completed successfully!"
    log_info "Deleted/initiated deletion for ${DELETED} resource(s)"
    echo ""
    log_info "Note: Resource Groups are being deleted asynchronously (may take 5-15 minutes)"
    log_info "You can verify deletion with: az group list --query \"[?starts_with(name, 'rg-${PROJECT}-')]\""
  else
    log_error "Cleanup completed with ${ERRORS} error(s)"
    log_warning "Some resources may not have been deleted. Please review the output above."
    exit 1
  fi
fi

