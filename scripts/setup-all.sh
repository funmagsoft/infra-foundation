#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize script (parse args, validate env vars, set subscription)
# Note: setup-all supports --dry-run and passes it to all setup scripts
init_script "$@"

echo "=== Complete Infrastructure Setup ==="
log_dry_run
log_info "Script directory: $SCRIPT_DIR"
log_info "Subscription: $SUBSCRIPTION_ID"
echo ""

TOTAL_ERRORS=0
FAILED_SETUPS=()

# Define setup scripts in order (dependencies must be created first)
SETUP_SCRIPTS=(
  "setup-rg.sh"
  "setup-state-storage.sh"
  "setup-access.sh"
  "setup-access-user.sh"
  "setup-access-sp.sh"
)

# Run each setup script
for setup_script in "${SETUP_SCRIPTS[@]}"; do
  script_path="${SCRIPT_DIR}/${setup_script}"
  
  if [ ! -f "$script_path" ]; then
    log_error "Setup script not found: $script_path"
    FAILED_SETUPS+=("$setup_script (not found)")
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    continue
  fi
  
  echo ""
  echo "================================================================================"
  echo "Running: $setup_script"
  echo "================================================================================"
  echo ""
  
  # Run the setup script and pass through --dry-run if set
  if [ "$DRY_RUN" = true ]; then
    if bash "$script_path" --dry-run; then
      log_success "$setup_script completed successfully"
    else
      exit_code=$?
      log_error "$setup_script failed with exit code: $exit_code"
      FAILED_SETUPS+=("$setup_script (exit code: $exit_code)")
      TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
  else
    if bash "$script_path"; then
      log_success "$setup_script completed successfully"
    else
      exit_code=$?
      log_error "$setup_script failed with exit code: $exit_code"
      FAILED_SETUPS+=("$setup_script (exit code: $exit_code)")
      TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
  fi
  
  echo ""
done

# Final Summary
echo ""
echo "================================================================================"
echo "=== Complete Setup Summary ==="
echo "================================================================================"
echo ""

if [ $TOTAL_ERRORS -eq 0 ]; then
  log_success "All setup scripts completed successfully!"
  echo ""
  echo "Created components:"
  echo "  ✓ Resource Groups (all environments)"
  echo "  ✓ Storage Accounts and containers (with versioning and soft delete)"
  echo "  ✓ Service Principals (for GitHub Actions)"
  echo "  ✓ Federated Identity Credentials (FIC)"
  echo "  ✓ RBAC role assignments (Contributor, User Access Administrator, Storage Blob Data Contributor)"
  echo "  ✓ Current user access (Storage Blob Data Contributor)"
  echo "  ✓ Service Principal access (Storage Blob Data Contributor)"
  echo ""
  if [ "$DRY_RUN" != true ]; then
    echo "Next steps:"
    echo "  1. Verify setup with: ./verify-all.sh"
    echo "  2. Configure GitHub Secrets (see documentation)"
    echo "  3. Proceed with Phase 1 deployment"
  fi
  exit 0
else
  log_error "Setup completed with $TOTAL_ERRORS error(s)"
  echo ""
  echo "Failed setups:"
  for failed in "${FAILED_SETUPS[@]}"; do
    echo "  ✗ $failed" >&2
  done
  echo ""
  echo "Please review the output above and fix the issues before proceeding."
  exit 1
fi

