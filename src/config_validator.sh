#!/bin/bash
# config_validator.sh - Configuration validation for docker-cleaner

# Detect script directory for sourcing dependencies
VALIDATOR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logger
source "${VALIDATOR_SCRIPT_DIR}/logger.sh"

# Function: Validate boolean value
validate_boolean() {
    local var_name="$1"
    local var_value="$2"

    case "$var_value" in
        true|false|TRUE|FALSE|True|False|1|0)
            return 0
            ;;
        *)
            error "Invalid boolean value for $var_name: '$var_value' (expected: true/false)"
            return 1
            ;;
    esac
}

# Function: Validate log level
validate_log_level() {
    local level="$1"

    case "$level" in
        DEBUG|INFO|WARN|ERROR)
            return 0
            ;;
        *)
            error "Invalid LOG_LEVEL: '$level' (expected: DEBUG, INFO, WARN, ERROR)"
            return 1
            ;;
    esac
}

# Function: Validate log format
validate_log_format() {
    local format="$1"

    case "$format" in
        text|json)
            return 0
            ;;
        *)
            error "Invalid LOG_FORMAT: '$format' (expected: text, json)"
            return 1
            ;;
    esac
}

# Function: Validate time duration format
validate_duration() {
    local var_name="$1"
    local duration="$2"

    # Empty is valid (means no filter)
    if [ -z "$duration" ]; then
        return 0
    fi

    # Check if it matches Docker duration format (e.g., 24h, 168h, 7d)
    if echo "$duration" | grep -qE '^[0-9]+(s|m|h)$'; then
        return 0
    fi

    error "Invalid duration format for $var_name: '$duration' (expected: Ns, Nm, or Nh, e.g., 24h, 168h)"
    return 1
}

# Function: Print configuration summary
print_config_summary() {
    info "=== Configuration Summary ==="
    info "Cleanup Operations:"
    info "  - Containers: $CLEANUP_CONTAINERS"
    info "  - Images: $CLEANUP_IMAGES (all: $PRUNE_ALL)"
    info "  - Volumes: $CLEANUP_VOLUMES"
    info "  - Networks: $CLEANUP_NETWORKS"
    info "  - Build Cache: $CLEANUP_BUILD_CACHE"
    info ""
    info "Filters:"
    info "  - Until: ${PRUNE_FILTER_UNTIL:-none}"
    info "  - Label: ${PRUNE_FILTER_LABEL:-none}"
    info ""
    info "Logging:"
    info "  - Level: $LOG_LEVEL"
    info "  - Format: $LOG_FORMAT"
    info "  - Quiet: $QUIET"
    info ""
    info "Execution:"
    info "  - Dry Run: $DRY_RUN"
    info "  - Force: $PRUNE_FORCE"
    info "=========================="
}

# Function: Main validation
validate_config() {
    local validation_failed=false

    debug "Starting configuration validation"

    # Validate boolean variables
    validate_boolean "PRUNE_ALL" "$PRUNE_ALL" || validation_failed=true
    validate_boolean "PRUNE_VOLUMES" "$PRUNE_VOLUMES" || validation_failed=true
    validate_boolean "PRUNE_FORCE" "$PRUNE_FORCE" || validation_failed=true
    validate_boolean "CLEANUP_CONTAINERS" "$CLEANUP_CONTAINERS" || validation_failed=true
    validate_boolean "CLEANUP_IMAGES" "$CLEANUP_IMAGES" || validation_failed=true
    validate_boolean "CLEANUP_VOLUMES" "$CLEANUP_VOLUMES" || validation_failed=true
    validate_boolean "CLEANUP_NETWORKS" "$CLEANUP_NETWORKS" || validation_failed=true
    validate_boolean "CLEANUP_BUILD_CACHE" "$CLEANUP_BUILD_CACHE" || validation_failed=true
    validate_boolean "QUIET" "$QUIET" || validation_failed=true
    validate_boolean "DRY_RUN" "$DRY_RUN" || validation_failed=true

    # Validate log settings
    validate_log_level "$LOG_LEVEL" || validation_failed=true
    validate_log_format "$LOG_FORMAT" || validation_failed=true

    # Validate duration filters
    if [ -n "${PRUNE_FILTER_UNTIL:-}" ]; then
        validate_duration "PRUNE_FILTER_UNTIL" "$PRUNE_FILTER_UNTIL" || validation_failed=true
    fi

    # Check for conflicting settings
    if [ "$PRUNE_VOLUMES" = "true" ] && [ "$CLEANUP_VOLUMES" = "false" ]; then
        warn "PRUNE_VOLUMES is true but CLEANUP_VOLUMES is false - volumes will not be cleaned"
    fi

    # Check if at least one cleanup operation is enabled
    if [ "$CLEANUP_CONTAINERS" = "false" ] && \
       [ "$CLEANUP_IMAGES" = "false" ] && \
       [ "$CLEANUP_VOLUMES" = "false" ] && \
       [ "$CLEANUP_NETWORKS" = "false" ] && \
       [ "$CLEANUP_BUILD_CACHE" = "false" ]; then
        error "All cleanup operations are disabled - nothing to do"
        validation_failed=true
    fi

    if [ "$validation_failed" = "true" ]; then
        error "Configuration validation failed"
        return 1
    fi

    debug "Configuration validation passed"
    print_config_summary
    return 0
}

# Export functions
export -f validate_boolean validate_log_level validate_log_format validate_duration print_config_summary validate_config
