#!/bin/bash
# cleanup.sh - Docker cleanup all-in-one script
# Combines entrypoint, logger, config validator, and cleanup logic

set -euo pipefail

# ============================================================================
# DEFAULT ENVIRONMENT VARIABLES
# ============================================================================

# Logging settings
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FORMAT="${LOG_FORMAT:-text}"
QUIET="${QUIET:-false}"

# Cleanup operations
CLEANUP_CONTAINERS="${CLEANUP_CONTAINERS:-true}"
CLEANUP_IMAGES="${CLEANUP_IMAGES:-true}"
CLEANUP_VOLUMES="${CLEANUP_VOLUMES:-false}"
CLEANUP_NETWORKS="${CLEANUP_NETWORKS:-true}"
CLEANUP_BUILD_CACHE="${CLEANUP_BUILD_CACHE:-true}"

# Prune settings
PRUNE_ALL="${PRUNE_ALL:-false}"
PRUNE_VOLUMES="${PRUNE_VOLUMES:-false}"
PRUNE_FORCE="${PRUNE_FORCE:-true}"

# Filters
PRUNE_FILTER_UNTIL="${PRUNE_FILTER_UNTIL:-}"
PRUNE_FILTER_LABEL="${PRUNE_FILTER_LABEL:-}"

# Execution mode
DRY_RUN="${DRY_RUN:-false}"

# ============================================================================
# LOGGER FUNCTIONS
# ============================================================================

# Get log level priority (compatible bash 3.2+)
get_log_level_priority() {
    case "$1" in
        DEBUG) echo 0 ;;
        INFO)  echo 1 ;;
        WARN)  echo 2 ;;
        ERROR) echo 3 ;;
        *)     echo 1 ;; # Default to INFO
    esac
}

# Get current log level priority
CURRENT_LEVEL_PRIORITY=$(get_log_level_priority "$LOG_LEVEL")

# Function: Get ISO 8601 timestamp
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Function: Log message with level filtering
log() {
    local level="$1"
    shift
    local message="$*"

    # Skip if quiet mode
    if [ "$QUIET" = "true" ]; then
        return 0
    fi

    # Check if this level should be logged
    local level_priority=$(get_log_level_priority "$level")
    if [ "$level_priority" -lt "$CURRENT_LEVEL_PRIORITY" ]; then
        return 0
    fi

    # Format output based on LOG_FORMAT
    if [ "$LOG_FORMAT" = "json" ]; then
        log_json "$level" "$message"
    else
        log_text "$level" "$message"
    fi
}

# Function: Log in text format
log_text() {
    local level="$1"
    local message="$2"
    local timestamp=$(get_timestamp)

    echo "[${timestamp}] [${level}] ${message}" >&2
}

# Function: Log in JSON format
log_json() {
    local level="$1"
    local message="$2"
    local timestamp=$(get_timestamp)

    # Escape quotes in message
    local escaped_message="${message//\"/\\\"}"

    echo "{\"timestamp\":\"${timestamp}\",\"level\":\"${level}\",\"message\":\"${escaped_message}\"}" >&2
}

# Function: Log operation result
log_operation() {
    local operation="$1"
    local status="$2"
    local count="$3"
    local space_freed="$4"

    if [ "$LOG_FORMAT" = "json" ]; then
        local timestamp=$(get_timestamp)
        echo "{\"timestamp\":\"${timestamp}\",\"level\":\"INFO\",\"operation\":\"${operation}\",\"status\":\"${status}\",\"count\":${count},\"space_freed\":\"${space_freed}\"}" >&2
    else
        log "INFO" "${operation}: ${status} (count: ${count}, space freed: ${space_freed})"
    fi
}

# Function: Log debug messages
debug() {
    log "DEBUG" "$@"
}

# Function: Log info messages
info() {
    log "INFO" "$@"
}

# Function: Log warning messages
warn() {
    log "WARN" "$@"
}

# Function: Log error messages
error() {
    log "ERROR" "$@"
}

# ============================================================================
# CONFIG VALIDATOR FUNCTIONS
# ============================================================================

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

# ============================================================================
# CLEANUP FUNCTIONS
# ============================================================================

# Initialize counters
TOTAL_SPACE_FREED=0
OPERATIONS_SUCCEEDED=0
OPERATIONS_FAILED=0
START_TIME=$(date +%s)

# Function: Convert space string to bytes
space_to_bytes() {
    local space_str="$1"

    # Extract number and unit
    if echo "$space_str" | grep -qiE '[0-9.]+[KMGT]?B'; then
        local value=$(echo "$space_str" | grep -oE '[0-9.]+')
        local unit=$(echo "$space_str" | grep -oiE '[KMGT]?B' | tr '[:lower:]' '[:upper:]')

        case "$unit" in
            B)   echo "$value" | awk '{printf "%.0f", $1}' ;;
            KB)  echo "$value" | awk '{printf "%.0f", $1 * 1024}' ;;
            MB)  echo "$value" | awk '{printf "%.0f", $1 * 1024 * 1024}' ;;
            GB)  echo "$value" | awk '{printf "%.0f", $1 * 1024 * 1024 * 1024}' ;;
            TB)  echo "$value" | awk '{printf "%.0f", $1 * 1024 * 1024 * 1024 * 1024}' ;;
            *)   echo "0" ;;
        esac
    else
        echo "0"
    fi
}

# Function: Format bytes to human readable
bytes_to_human() {
    local bytes="$1"

    if [ "$bytes" -ge 1099511627776 ]; then
        echo "$bytes" | awk '{printf "%.2f TB", $1/1099511627776}'
    elif [ "$bytes" -ge 1073741824 ]; then
        echo "$bytes" | awk '{printf "%.2f GB", $1/1073741824}'
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$bytes" | awk '{printf "%.2f MB", $1/1048576}'
    elif [ "$bytes" -ge 1024 ]; then
        echo "$bytes" | awk '{printf "%.2f KB", $1/1024}'
    else
        echo "${bytes} B"
    fi
}

# Function: Build filter arguments
build_filter_args() {
    local filter_args=""

    if [ -n "${PRUNE_FILTER_UNTIL:-}" ]; then
        filter_args="$filter_args --filter until=$PRUNE_FILTER_UNTIL"
    fi

    if [ -n "${PRUNE_FILTER_LABEL:-}" ]; then
        filter_args="$filter_args --filter label=$PRUNE_FILTER_LABEL"
    fi

    echo "$filter_args"
}

# Function: Prune containers
prune_containers() {
    info "Starting container prune..."

    # List stopped containers before pruning for audit trail
    local stopped_count=$(docker container ls -aq -f status=exited -f status=created | wc -l | tr -d ' ')
    debug "Found $stopped_count stopped/created containers"

    # Security check: Verify no running containers will be affected
    local running_count=$(docker container ls -q | wc -l | tr -d ' ')
    info "SECURITY: $running_count running containers will be protected"

    local filter_args=$(build_filter_args)
    local cmd="docker container prune -f $filter_args"

    if [ "$DRY_RUN" = "true" ]; then
        info "[DRY RUN] Would execute: $cmd"
        info "[DRY RUN] Would remove approximately $stopped_count stopped containers"
        OPERATIONS_SUCCEEDED=$((OPERATIONS_SUCCEEDED + 1))
        return 0
    fi

    local output
    if output=$(eval $cmd 2>&1); then
        local space_freed=$(echo "$output" | grep -i "Total reclaimed space" | grep -oE '[0-9.]+[KMGT]?B' || echo "0B")
        local bytes_freed=$(space_to_bytes "$space_freed")
        TOTAL_SPACE_FREED=$((TOTAL_SPACE_FREED + bytes_freed))
        OPERATIONS_SUCCEEDED=$((OPERATIONS_SUCCEEDED + 1))
        log_operation "CONTAINER_PRUNE" "SUCCESS" "$stopped_count" "$space_freed"
        info "AUDIT: Removed stopped containers, space reclaimed: $space_freed"
        return 0
    else
        error "Container prune failed: $output"
        OPERATIONS_FAILED=$((OPERATIONS_FAILED + 1))
        return 1
    fi
}

# Function: Prune images
prune_images() {
    info "Starting image prune..."

    # Count images before pruning for audit trail
    local dangling_count=$(docker images -f dangling=true -q | wc -l | tr -d ' ')
    local all_unused_count=$(docker images -f dangling=false -q | wc -l | tr -d ' ')
    debug "Found $dangling_count dangling images, $all_unused_count total unused images"

    local filter_args=$(build_filter_args)
    local all_flag=""

    if [ "$PRUNE_ALL" = "true" ]; then
        all_flag="--all"
        warn "SECURITY: PRUNE_ALL enabled - removing ALL unused images (not just dangling)"
        warn "SECURITY: This will remove images that are not currently used by any container"
    else
        info "SECURITY: Only dangling images will be removed (PRUNE_ALL=false)"
    fi

    local cmd="docker image prune -f $all_flag $filter_args"

    if [ "$DRY_RUN" = "true" ]; then
        info "[DRY RUN] Would execute: $cmd"
        if [ "$PRUNE_ALL" = "true" ]; then
            info "[DRY RUN] Would potentially remove $all_unused_count unused images"
        else
            info "[DRY RUN] Would remove approximately $dangling_count dangling images"
        fi
        OPERATIONS_SUCCEEDED=$((OPERATIONS_SUCCEEDED + 1))
        return 0
    fi

    local output
    if output=$(eval $cmd 2>&1); then
        local space_freed=$(echo "$output" | grep -i "Total reclaimed space" | grep -oE '[0-9.]+[KMGT]?B' || echo "0B")
        local bytes_freed=$(space_to_bytes "$space_freed")
        TOTAL_SPACE_FREED=$((TOTAL_SPACE_FREED + bytes_freed))
        OPERATIONS_SUCCEEDED=$((OPERATIONS_SUCCEEDED + 1))

        if [ "$PRUNE_ALL" = "true" ]; then
            log_operation "IMAGE_PRUNE_ALL" "SUCCESS" "N/A" "$space_freed"
            info "AUDIT: Removed all unused images, space reclaimed: $space_freed"
        else
            log_operation "IMAGE_PRUNE_DANGLING" "SUCCESS" "$dangling_count" "$space_freed"
            info "AUDIT: Removed dangling images, space reclaimed: $space_freed"
        fi
        return 0
    else
        error "Image prune failed: $output"
        OPERATIONS_FAILED=$((OPERATIONS_FAILED + 1))
        return 1
    fi
}

# Function: Prune volumes
prune_volumes() {
    if [ "$PRUNE_VOLUMES" != "true" ]; then
        info "Volume prune skipped (PRUNE_VOLUMES=false - safety default)"
        info "SECURITY: Volumes are protected by default to prevent data loss"
        return 0
    fi

    # Count volumes before pruning for audit trail
    local total_volumes=$(docker volume ls -q | wc -l | tr -d ' ')
    local unused_volumes=$(docker volume ls -f dangling=true -q | wc -l | tr -d ' ')
    debug "Found $unused_volumes unused volumes out of $total_volumes total"

    warn "SECURITY: Volume prune enabled - this will PERMANENTLY DELETE unused volumes"
    warn "SECURITY: Data in these volumes will be IRRECOVERABLY LOST"
    warn "SECURITY: Volumes in use by containers will be protected"
    info "Starting volume prune..."

    local filter_args=$(build_filter_args)

    # Detect Docker API version to determine if --all is supported
    local api_version=$(docker version -f '{{.Server.APIVersion}}' 2>/dev/null || echo "1.40")
    local api_major=$(echo "$api_version" | cut -d. -f1)
    local api_minor=$(echo "$api_version" | cut -d. -f2)

    # --all option requires API 1.42+
    local volume_prune_flags="-f"
    if [ "$api_major" -gt 1 ] || ([ "$api_major" -eq 1 ] && [ "$api_minor" -ge 42 ]); then
        volume_prune_flags="-af"
        debug "Using volume prune with --all flag (API version $api_version)"
    else
        debug "API version $api_version does not support volume prune --all, using -f only"
    fi

    local cmd="docker volume prune $volume_prune_flags $filter_args"

    if [ "$DRY_RUN" = "true" ]; then
        info "[DRY RUN] Would execute: $cmd"
        info "[DRY RUN] Would potentially remove $unused_volumes unused volumes"
        warn "[DRY RUN] This would PERMANENTLY DELETE data in these volumes"
        OPERATIONS_SUCCEEDED=$((OPERATIONS_SUCCEEDED + 1))
        return 0
    fi

    local output
    if output=$(eval $cmd 2>&1); then
        local space_freed=$(echo "$output" | grep -i "Total reclaimed space" | grep -oE '[0-9.]+[KMGT]?B' || echo "0B")
        local bytes_freed=$(space_to_bytes "$space_freed")
        TOTAL_SPACE_FREED=$((TOTAL_SPACE_FREED + bytes_freed))
        OPERATIONS_SUCCEEDED=$((OPERATIONS_SUCCEEDED + 1))
        log_operation "VOLUME_PRUNE" "SUCCESS" "$unused_volumes" "$space_freed"
        warn "AUDIT: DELETED $unused_volumes unused volumes, space reclaimed: $space_freed"
        return 0
    else
        error "Volume prune failed: $output"
        OPERATIONS_FAILED=$((OPERATIONS_FAILED + 1))
        return 1
    fi
}

# Function: Prune networks
prune_networks() {
    info "Starting network prune..."

    # Count networks before pruning for audit trail
    local total_networks=$(docker network ls -q | wc -l | tr -d ' ')
    local custom_networks=$(docker network ls --filter type=custom -q | wc -l | tr -d ' ')
    debug "Found $custom_networks custom networks out of $total_networks total"
    info "SECURITY: Default networks (bridge, host, none) are always protected"

    local filter_args=$(build_filter_args)
    local cmd="docker network prune -f $filter_args"

    if [ "$DRY_RUN" = "true" ]; then
        info "[DRY RUN] Would execute: $cmd"
        info "[DRY RUN] Would potentially remove unused custom networks"
        OPERATIONS_SUCCEEDED=$((OPERATIONS_SUCCEEDED + 1))
        return 0
    fi

    local output
    if output=$(eval $cmd 2>&1); then
        # Networks don't report space freed
        OPERATIONS_SUCCEEDED=$((OPERATIONS_SUCCEEDED + 1))
        log_operation "NETWORK_PRUNE" "SUCCESS" "N/A" "0B"
        info "AUDIT: Removed unused networks"
        return 0
    else
        error "Network prune failed: $output"
        OPERATIONS_FAILED=$((OPERATIONS_FAILED + 1))
        return 1
    fi
}

# Function: Prune build cache
prune_build_cache() {
    info "Starting build cache prune..."
    info "SECURITY: Build cache may contain intermediate build layers and secrets"

    local filter_args=$(build_filter_args)
    local cmd="docker builder prune -f $filter_args"

    if [ "$DRY_RUN" = "true" ]; then
        info "[DRY RUN] Would execute: $cmd"
        info "[DRY RUN] Would remove Docker build cache"
        OPERATIONS_SUCCEEDED=$((OPERATIONS_SUCCEEDED + 1))
        return 0
    fi

    local output
    if output=$(eval $cmd 2>&1); then
        local space_freed=$(echo "$output" | grep -i "Total" | grep -oE '[0-9.]+[KMGT]?B' | tail -1 || echo "0B")
        local bytes_freed=$(space_to_bytes "$space_freed")
        TOTAL_SPACE_FREED=$((TOTAL_SPACE_FREED + bytes_freed))
        OPERATIONS_SUCCEEDED=$((OPERATIONS_SUCCEEDED + 1))
        log_operation "BUILD_CACHE_PRUNE" "SUCCESS" "N/A" "$space_freed"
        info "AUDIT: Removed build cache, space reclaimed: $space_freed"
        return 0
    else
        error "Build cache prune failed: $output"
        OPERATIONS_FAILED=$((OPERATIONS_FAILED + 1))
        return 1
    fi
}

# Function: Print summary
print_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local human_space=$(bytes_to_human "$TOTAL_SPACE_FREED")

    info ""
    info "=== Cleanup Summary ==="
    info "Operations succeeded: $OPERATIONS_SUCCEEDED"
    info "Operations failed: $OPERATIONS_FAILED"
    info "Total space reclaimed: $human_space"
    info "Execution time: ${duration}s"
    info "======================="
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    info "Docker Cleanup Container starting..."

    # Validate configuration
    if ! validate_config; then
        error "Configuration validation failed"
        exit 2
    fi

    if [ "$DRY_RUN" = "true" ]; then
        warn "=== DRY RUN MODE - No changes will be made ==="
    fi

    # Execute cleanup operations in order
    if [ "$CLEANUP_CONTAINERS" = "true" ]; then
        prune_containers || true
    fi

    if [ "$CLEANUP_IMAGES" = "true" ]; then
        prune_images || true
    fi

    if [ "$CLEANUP_VOLUMES" = "true" ]; then
        prune_volumes || true
    fi

    if [ "$CLEANUP_NETWORKS" = "true" ]; then
        prune_networks || true
    fi

    if [ "$CLEANUP_BUILD_CACHE" = "true" ]; then
        prune_build_cache || true
    fi

    # Print summary
    print_summary

    # Determine exit code
    if [ "$OPERATIONS_SUCCEEDED" -eq 0 ]; then
        error "All operations failed"
        exit 2
    elif [ "$OPERATIONS_FAILED" -gt 0 ]; then
        warn "Some operations failed"
        exit 1
    else
        info "All operations completed successfully"
        exit 0
    fi
}

# Run main
main "$@"
