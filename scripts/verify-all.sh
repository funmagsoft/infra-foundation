#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Initialize script (parse args, validate env vars, set subscription)
# Note: verify scripts don't need --dry-run, but we use init_script for consistency
DRY_RUN=false
init_script

echo "=== Complete Infrastructure Verification ==="
log_info "Script directory: $SCRIPT_DIR"
log_info "Subscription: $SUBSCRIPTION_ID"
echo ""

TOTAL_ERRORS=0
TOTAL_WARNINGS=0
FAILED_VERIFICATIONS=()

# Define verification scripts in order
VERIFY_SCRIPTS=(
  "verify-rg.sh"
  "verify-state-storage.sh"
  "verify-access.sh"
  "verify-access-user.sh"
  "verify-access-sp.sh"
)

# Run each verification script
for verify_script in "${VERIFY_SCRIPTS[@]}"; do
  script_path="${SCRIPT_DIR}/${verify_script}"
  
  if [ ! -f "$script_path" ]; then
    log_error "Verification script not found: $script_path"
    FAILED_VERIFICATIONS+=("$verify_script (not found)")
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    continue
  fi
  
  echo ""
  echo "================================================================================"
  echo "Running: $verify_script"
  echo "================================================================================"
  echo ""
  
  # Run the verification script and capture exit code
  if bash "$script_path"; then
    log_success "$verify_script completed successfully"
  else
    exit_code=$?
    log_error "$verify_script failed with exit code: $exit_code"
    FAILED_VERIFICATIONS+=("$verify_script (exit code: $exit_code)")
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
  fi
  
  echo ""
done

# Final Summary
echo ""
echo "================================================================================"
echo "=== Complete Verification Summary ==="
echo "================================================================================"
echo ""

if [ $TOTAL_ERRORS -eq 0 ]; then
  log_success "All verifications passed!"
  echo ""
  echo "Verified components:"
  echo "  ✓ Resource Groups (all environments)"
  echo "  ✓ Phase 0 resources (Storage Accounts, Service Principals, backend.tf, repositories)"
  echo "  ✓ Storage Account configuration (versioning, soft delete, containers)"
  echo "  ✓ GitHub Actions access (Service Principals, FIC, RBAC roles)"
  echo "  ✓ Current user access (Storage Blob Data Contributor)"
  echo "  ✓ Service Principal access (Storage Blob Data Contributor)"
  echo ""
  exit 0
else
  log_error "Verification completed with $TOTAL_ERRORS error(s)"
  echo ""
  echo "Failed verifications:"
  for failed in "${FAILED_VERIFICATIONS[@]}"; do
    echo "  ✗ $failed" >&2
  done
  echo ""
  echo "Please review the output above and fix the issues before proceeding."
  exit 1
fi

