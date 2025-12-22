#!/bin/bash
# Common functions and utilities for phase0 scripts

# ============================================================================
# Command line argument parsing
# ============================================================================
parse_dry_run() {
  DRY_RUN=false
  for arg in "$@"; do
    case $arg in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      *)
        echo "Unknown option: $arg" >&2
        echo "Usage: $0 [--dry-run]" >&2
        exit 1
        ;;
    esac
  done
}

# ============================================================================
# Dry-run helper functions
# ============================================================================
run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] $*" >&2
  else
    "$@"
  fi
}

run_cmd_capture() {
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] $*" >&2
    echo "[DRY-RUN] Output would be captured" >&2
  else
    "$@"
  fi
}

write_file() {
  local file="$1"
  local content="$2"
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] echo \"$content\" >> \"$file\"" >&2
  else
    echo "$content" >> "$file"
  fi
}

clear_file() {
  local file="$1"
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] > \"$file\"" >&2
  else
    > "$file"
  fi
}

# ============================================================================
# Environment variable validation
# ============================================================================
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

  if [ -z "$ORGANIZATION_FOR_SA" ]; then
    missing_vars+=("ORGANIZATION_FOR_SA")
  fi

  if [ -z "$PROJECT" ]; then
    missing_vars+=("PROJECT")
  fi
  
  if [ ${#missing_vars[@]} -ne 0 ]; then
    log_error "The following required environment variables are not set:"
    for var in "${missing_vars[@]}"; do
      echo "  - $var" >&2
    done
    echo "" >&2
    echo "Please set them before running this script:" >&2
    echo "  export TENANT_ID=\"<your-tenant-id>\"" >&2
    echo "  export SUBSCRIPTION_ID=\"<your-subscription-id>\"" >&2
    echo "  export LOCATION=\"<your-location>\"" >&2
    echo "  export ORGANIZATION=\"<your-organization>\"" >&2
    echo "  export ORGANIZATION_FOR_SA=\"<your-organization-for-sa>\"" >&2
    echo "  export PROJECT=\"<your-project>\"" >&2
    exit 1
  fi
}

validate_minimal_env_vars() {
  local missing_vars=()
  
  if [ -z "$SUBSCRIPTION_ID" ]; then
    missing_vars+=("SUBSCRIPTION_ID")
  fi
  
  if [ -z "$PROJECT" ]; then
    missing_vars+=("PROJECT")
  fi
  
  if [ ${#missing_vars[@]} -ne 0 ]; then
    log_error "The following required environment variables are not set:"
    for var in "${missing_vars[@]}"; do
      echo "  - $var" >&2
    done
    echo "" >&2
    echo "Please set them before running this script:" >&2
    echo "  export SUBSCRIPTION_ID=\"<your-subscription-id>\"" >&2
    echo "  export PROJECT=\"<your-project>\"" >&2
    exit 1
  fi
}

# ============================================================================
# Error handling and logging
# ============================================================================
log_error() {
  echo "Error: $*" >&2
}

log_warning() {
  echo "Warning: $*" >&2
}

log_info() {
  echo "$*"
}

log_success() {
  echo "✓ $*"
}

log_dry_run() {
  if [ "$DRY_RUN" = true ]; then
    echo "*** DRY-RUN MODE: No changes will be made ***"
  fi
}

log_dry_run_complete() {
  if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "*** DRY-RUN MODE: No changes were made ***"
  fi
}

# ============================================================================
# Script initialization
# ============================================================================
init_script() {
  # Parse dry-run argument
  parse_dry_run "$@"
  
  # Only set -e if not in dry-run mode
  if [ "$DRY_RUN" != true ]; then
    set -e
  fi
  
  # Validate environment variables
  validate_env_vars
  
  # Set active subscription
  run_cmd az account set --subscription "$SUBSCRIPTION_ID"
}

init_script_minimal() {
  # Parse dry-run argument
  parse_dry_run "$@"
  
  # Only set -e if not in dry-run mode
  if [ "$DRY_RUN" != true ]; then
    set -e
  fi
  
  # Validate minimal environment variables
  validate_minimal_env_vars
  
  # Set active subscription
  run_cmd az account set --subscription "$SUBSCRIPTION_ID"
}

# ============================================================================
# Directory helpers
# ============================================================================
get_script_dir() {
  # This should be called from the script itself, not from common.sh
  # Usage: SCRIPT_DIR=$(get_script_dir)
  local script_path="${BASH_SOURCE[1]}"
  if [ -n "$script_path" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"
  else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi
  echo "$SCRIPT_DIR"
}

get_base_dir() {
  local script_dir="$1"
  BASE_DIR="$(cd "$script_dir/../.." && pwd)"
  echo "$BASE_DIR"
}

# ============================================================================
# Environment file loading
# ============================================================================
load_env_file() {
  local env_file="$1"
  if [ -f "$env_file" ]; then
    # Use set -a to automatically export all variables
    set -a
    source "$env_file"
    set +a
  else
    return 1
  fi
}

