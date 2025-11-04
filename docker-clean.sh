#!/usr/bin/env bash
#
# docker-clean.sh - Deploy and execute docker-cleaner on specified Docker context
#
# Usage:
#   ./docker-clean.sh [context] [OPTIONS]
#
# Arguments:
#   context     Docker context name (optional, defaults to current context)
#
# Options:
#   --dry-run              Preview without deleting
#   --prune-all            Remove all unused images (not just dangling)
#   --prune-volumes        Include volumes in cleanup (DANGER)
#   --cleanup-volumes      Prune unused volumes (DANGER)
#   --filter-until=HOURS   Remove resources older than X hours
#   --filter-label=LABEL   Filter by label (e.g., keep!=true)
#   --log-level=LEVEL      Log level: DEBUG, INFO, WARN, ERROR (default: INFO)
#   --log-format=FORMAT    Output format: text or json (default: text)
#   --quiet                Minimal output
#   --help                 Show this help message
#
# Examples:
#   ./docker-clean.sh                           # Clean current context
#   ./docker-clean.sh nas                       # Clean NAS context
#   ./docker-clean.sh ml350pG8 --dry-run        # Preview on ml350pG8
#   ./docker-clean.sh nas --prune-all --prune-volumes  # Full cleanup on NAS
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
IMAGE_NAME="docker-cleaner"
CONTEXT=""
ORIGINAL_CONTEXT=""
DRY_RUN="false"
PRUNE_ALL="false"
PRUNE_VOLUMES="false"
CLEANUP_VOLUMES="false"
PRUNE_FORCE="true"
CLEANUP_CONTAINERS="true"
CLEANUP_IMAGES="true"
CLEANUP_NETWORKS="true"
CLEANUP_BUILD_CACHE="true"
LOG_LEVEL="INFO"
LOG_FORMAT="text"
QUIET="false"
FILTER_UNTIL=""
FILTER_LABEL=""

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Function to show usage
show_usage() {
    grep '^#' "$0" | grep -v '#!/usr/bin/env' | sed 's/^# \?//'
    exit 0
}

# Function to restore original context
restore_context() {
    if [[ -n "$ORIGINAL_CONTEXT" ]] && [[ "$ORIGINAL_CONTEXT" != "$CONTEXT" ]]; then
        print_info "Restoring original context: $ORIGINAL_CONTEXT"
        docker context use "$ORIGINAL_CONTEXT" >/dev/null
    fi
}

# Function to get current Docker context
get_current_context() {
    docker context show 2>/dev/null || echo "default"
}

# Function to verify context exists
verify_context() {
    local ctx="$1"
    if ! docker context inspect "$ctx" >/dev/null 2>&1; then
        print_error "Docker context '$ctx' does not exist"
        print_info "Available contexts:"
        docker context ls
        exit 1
    fi
}

# Function to build docker-cleaner image
build_image() {
    local ctx="$1"
    print_info "Building docker-cleaner image for context: $ctx"

    # Switch to target context for building
    docker context use "$ctx" >/dev/null

    if docker build -t "$IMAGE_NAME" . >/dev/null 2>&1; then
        print_success "Image built successfully"
    else
        print_error "Failed to build image"
        restore_context
        exit 1
    fi
}

# Function to check if image exists
image_exists() {
    local ctx="$1"
    docker context use "$ctx" >/dev/null
    docker image inspect "$IMAGE_NAME" >/dev/null 2>&1
}

# Function to run cleanup
run_cleanup() {
    local ctx="$1"

    print_info "Running cleanup on context: $ctx"

    # Build environment variables
    local env_vars=(
        "-e" "PRUNE_ALL=$PRUNE_ALL"
        "-e" "PRUNE_VOLUMES=$PRUNE_VOLUMES"
        "-e" "PRUNE_FORCE=$PRUNE_FORCE"
        "-e" "CLEANUP_CONTAINERS=$CLEANUP_CONTAINERS"
        "-e" "CLEANUP_IMAGES=$CLEANUP_IMAGES"
        "-e" "CLEANUP_VOLUMES=$CLEANUP_VOLUMES"
        "-e" "CLEANUP_NETWORKS=$CLEANUP_NETWORKS"
        "-e" "CLEANUP_BUILD_CACHE=$CLEANUP_BUILD_CACHE"
        "-e" "LOG_LEVEL=$LOG_LEVEL"
        "-e" "LOG_FORMAT=$LOG_FORMAT"
        "-e" "QUIET=$QUIET"
        "-e" "DRY_RUN=$DRY_RUN"
    )

    # Add optional filters
    if [[ -n "$FILTER_UNTIL" ]]; then
        env_vars+=("-e" "PRUNE_FILTER_UNTIL=$FILTER_UNTIL")
    fi

    if [[ -n "$FILTER_LABEL" ]]; then
        env_vars+=("-e" "PRUNE_FILTER_LABEL=$FILTER_LABEL")
    fi

    # Display configuration
    echo ""
    print_info "Configuration:"
    echo "  Context: $ctx"
    echo "  Dry Run: $DRY_RUN"
    echo "  Prune All Images: $PRUNE_ALL"
    echo "  Prune Volumes: $PRUNE_VOLUMES"
    echo "  Cleanup Volumes: $CLEANUP_VOLUMES"
    echo "  Log Level: $LOG_LEVEL"
    echo "  Log Format: $LOG_FORMAT"
    if [[ -n "$FILTER_UNTIL" ]]; then
        echo "  Filter Until: $FILTER_UNTIL"
    fi
    if [[ -n "$FILTER_LABEL" ]]; then
        echo "  Filter Label: $FILTER_LABEL"
    fi
    echo ""

    # Run the container
    docker context use "$ctx" >/dev/null

    if docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        "${env_vars[@]}" \
        "$IMAGE_NAME"; then
        print_success "Cleanup completed successfully on context: $ctx"
    else
        local exit_code=$?
        print_error "Cleanup failed on context: $ctx (exit code: $exit_code)"
        restore_context
        exit $exit_code
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_usage
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --prune-all)
            PRUNE_ALL="true"
            shift
            ;;
        --prune-volumes)
            PRUNE_VOLUMES="true"
            shift
            ;;
        --cleanup-volumes)
            CLEANUP_VOLUMES="true"
            shift
            ;;
        --filter-until=*)
            FILTER_UNTIL="${1#*=}"
            shift
            ;;
        --filter-label=*)
            FILTER_LABEL="${1#*=}"
            shift
            ;;
        --log-level=*)
            LOG_LEVEL="${1#*=}"
            shift
            ;;
        --log-format=*)
            LOG_FORMAT="${1#*=}"
            shift
            ;;
        --quiet)
            QUIET="true"
            shift
            ;;
        -*)
            print_error "Unknown option: $1"
            show_usage
            ;;
        *)
            if [[ -z "$CONTEXT" ]]; then
                CONTEXT="$1"
            else
                print_error "Too many arguments"
                show_usage
            fi
            shift
            ;;
    esac
done

# Main execution
main() {
    print_info "Docker Cleaner Deployment Script"
    echo ""

    # Get and save original context
    ORIGINAL_CONTEXT=$(get_current_context)
    print_info "Current context: $ORIGINAL_CONTEXT"

    # Use current context if none specified
    if [[ -z "$CONTEXT" ]]; then
        CONTEXT="$ORIGINAL_CONTEXT"
        print_info "No context specified, using current: $CONTEXT"
    fi

    # Verify target context exists
    verify_context "$CONTEXT"

    # Check if image exists on target context
    if ! image_exists "$CONTEXT"; then
        print_warning "Image '$IMAGE_NAME' not found on context: $CONTEXT"
        build_image "$CONTEXT"
    else
        print_info "Image '$IMAGE_NAME' already exists on context: $CONTEXT"
    fi

    # Run cleanup
    run_cleanup "$CONTEXT"

    # Restore original context
    restore_context

    echo ""
    print_success "All operations completed successfully"
}

# Set up trap to restore context on exit
trap restore_context EXIT INT TERM

# Run main function
main
