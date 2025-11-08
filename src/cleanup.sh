#!/bin/bash
# cleanup.sh - Main cleanup orchestrator for docker-cleaner

set -euo pipefail

# Detect script directory for sourcing dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
source "${SCRIPT_DIR}/logger.sh"
source "${SCRIPT_DIR}/config_validator.sh"

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

# Main execution
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
