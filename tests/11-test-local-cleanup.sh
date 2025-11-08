#!/bin/bash
# 11-test-local-cleanup.sh - Test cleanup script execution in local terminal

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
DRY_RUN_MODE=false
PRUNE_ALL_MODE=false
PRUNE_VOLUMES_MODE=false
TARGET_CONTEXT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN_MODE=true
            shift
            ;;
        --prune-all)
            PRUNE_ALL_MODE=true
            shift
            ;;
        --prune-volumes)
            PRUNE_VOLUMES_MODE=true
            shift
            ;;
        --context)
            TARGET_CONTEXT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run] [--prune-all] [--prune-volumes] [--context <name>]"
            exit 1
            ;;
    esac
done

# Docker context wrapper - uses --context flag when TARGET_CONTEXT is set
docker_ctx() {
    if [ -n "$TARGET_CONTEXT" ]; then
        docker --context "$TARGET_CONTEXT" "$@"
    else
        docker "$@"
    fi
}

# Validate context if specified
if [ -n "$TARGET_CONTEXT" ]; then
    if ! docker context ls --format "{{.Name}}" | grep -q "^${TARGET_CONTEXT}$"; then
        echo -e "${RED}Error: Context '$TARGET_CONTEXT' does not exist${NC}"
        echo "Available contexts:"
        docker context ls
        exit 1
    fi
    echo "Using Docker context: $TARGET_CONTEXT"
    echo ""
fi

# Cleanup on exit
cleanup_on_exit() {
    local exit_code=$?

    echo ""
    echo -e "${BLUE}=== Cleanup Phase ===${NC}"

    # Clean test resources
    echo "Removing test resources..."
    if [ -n "$TARGET_CONTEXT" ]; then
        ./tests/03-cleanup-test-resources.sh --context "$TARGET_CONTEXT" >/dev/null 2>&1 || true
    else
        ./tests/03-cleanup-test-resources.sh >/dev/null 2>&1 || true
    fi
    echo -e "${GREEN}✓ Test resources cleaned${NC}"

    exit $exit_code
}

# Set trap for cleanup
trap cleanup_on_exit EXIT INT TERM

# Test counters
PASS=0
FAIL=0

# Assertion functions
assert_equals() {
    local description="$1"
    local expected="$2"
    local actual="$3"

    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $description"
        PASS=$((PASS + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $description (expected=$expected, actual=$actual)"
        FAIL=$((FAIL + 1))
        return 1
    fi
}

assert_zero() {
    local description="$1"
    local actual="$2"

    if [ "$actual" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $description"
        PASS=$((PASS + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $description (expected=0, actual=$actual)"
        FAIL=$((FAIL + 1))
        return 1
    fi
}

assert_not_zero() {
    local description="$1"
    local actual="$2"

    if [ "$actual" -gt 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $description"
        PASS=$((PASS + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $description (expected>0, actual=$actual)"
        FAIL=$((FAIL + 1))
        return 1
    fi
}

assert_less_than() {
    local description="$1"
    local before="$2"
    local after="$3"

    if [ "$after" -lt "$before" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $description (before=$before, after=$after)"
        PASS=$((PASS + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $description (before=$before, after=$after)"
        FAIL=$((FAIL + 1))
        return 1
    fi
}

# Resource counting functions
count_running_containers() {
    docker_ctx ps -q --filter label=test-cleanup=true 2>/dev/null | wc -l | tr -d ' '
}

count_stopped_containers() {
    docker_ctx ps -aq -f status=exited -f status=created --filter label=test-cleanup=true 2>/dev/null | wc -l | tr -d ' '
}

count_volumes() {
    docker_ctx volume ls -q --filter label=test-cleanup=true 2>/dev/null | wc -l | tr -d ' '
}

count_unused_volumes() {
    # Count volumes that are not in use by any container
    local all_volumes=$(docker_ctx volume ls -q --filter label=test-cleanup=true 2>/dev/null || true)
    local unused=0

    for vol in $all_volumes; do
        local in_use=$(docker_ctx ps -a --filter volume="$vol" --format "{{.ID}}" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$in_use" -eq 0 ]; then
            unused=$((unused + 1))
        fi
    done

    echo "$unused"
}

count_networks() {
    docker_ctx network ls -q --filter label=test-cleanup=true 2>/dev/null | wc -l | tr -d ' '
}

count_unused_images() {
    docker_ctx images --filter label=test-cleanup=true --filter dangling=false -q 2>/dev/null | wc -l | tr -d ' '
}

count_dangling_images() {
    docker_ctx images -f dangling=true -q 2>/dev/null | wc -l | tr -d ' '
}

# Main test execution
main() {
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${BLUE}   Docker Cleanup - Local Script Testing${NC}"
    echo -e "${BLUE}=====================================================${NC}"
    echo ""

    local current_context=$(docker_ctx context show)
    echo "Testing on context: $current_context"
    echo ""

    # Display test configuration
    echo -e "${BLUE}=== Test Configuration ===${NC}"
    echo "Dry-run mode: $DRY_RUN_MODE"
    echo "Prune all: $PRUNE_ALL_MODE"
    echo "Prune volumes: $PRUNE_VOLUMES_MODE"
    echo ""

    # Phase 1: Setup
    echo -e "${BLUE}=== Phase 1: Setup ===${NC}"
    echo "Creating test resources..."
    if [ -n "$TARGET_CONTEXT" ]; then
        ./tests/01-setup-test-resources.sh --context "$TARGET_CONTEXT" >/dev/null 2>&1
    else
        ./tests/01-setup-test-resources.sh >/dev/null 2>&1
    fi
    echo -e "${GREEN}✓ Test resources created${NC}"
    echo ""

    # Count before cleanup
    local BEFORE_RUNNING=$(count_running_containers)
    local BEFORE_STOPPED=$(count_stopped_containers)
    local BEFORE_VOLUMES=$(count_volumes)
    local BEFORE_UNUSED_VOLUMES=$(count_unused_volumes)
    local BEFORE_NETWORKS=$(count_networks)
    local BEFORE_UNUSED_IMAGES=$(count_unused_images)
    local BEFORE_DANGLING=$(count_dangling_images)

    echo -e "${BLUE}=== Resources Before Cleanup ===${NC}"
    echo "Running containers: $BEFORE_RUNNING"
    echo "Stopped containers: $BEFORE_STOPPED"
    echo "Volumes (total): $BEFORE_VOLUMES"
    echo "Volumes (unused): $BEFORE_UNUSED_VOLUMES"
    echo "Networks: $BEFORE_NETWORKS"
    echo "Unused images: $BEFORE_UNUSED_IMAGES"
    echo "Dangling images: $BEFORE_DANGLING"
    echo ""

    # Phase 2: Execute cleanup
    echo -e "${BLUE}=== Phase 2: Execute Cleanup ===${NC}"
    echo "Running cleanup script..."

    # Set environment variables
    export DRY_RUN="$DRY_RUN_MODE"
    export PRUNE_ALL="$PRUNE_ALL_MODE"
    export PRUNE_VOLUMES="$PRUNE_VOLUMES_MODE"
    export PRUNE_FORCE=true
    export CLEANUP_CONTAINERS=true
    export CLEANUP_IMAGES=true
    export CLEANUP_VOLUMES=true
    export CLEANUP_NETWORKS=true
    export CLEANUP_BUILD_CACHE=true
    export QUIET=false
    export LOG_LEVEL="INFO"
    export LOG_FORMAT="text"

    # Execute cleanup script
    local cleanup_exit_code=0
    ./src/cleanup.sh 2>&1 | tee /tmp/cleanup-output.log || cleanup_exit_code=$?

    echo ""
    echo "Cleanup exit code: $cleanup_exit_code"
    echo ""

    # Phase 3: Validation
    echo -e "${BLUE}=== Phase 3: Validation ===${NC}"

    # Count after cleanup
    local AFTER_RUNNING=$(count_running_containers)
    local AFTER_STOPPED=$(count_stopped_containers)
    local AFTER_VOLUMES=$(count_volumes)
    local AFTER_UNUSED_VOLUMES=$(count_unused_volumes)
    local AFTER_NETWORKS=$(count_networks)
    local AFTER_UNUSED_IMAGES=$(count_unused_images)
    local AFTER_DANGLING=$(count_dangling_images)

    echo -e "${BLUE}Resources After Cleanup:${NC}"
    echo "Running containers: $AFTER_RUNNING"
    echo "Stopped containers: $AFTER_STOPPED"
    echo "Volumes (total): $AFTER_VOLUMES"
    echo "Volumes (unused): $AFTER_UNUSED_VOLUMES"
    echo "Networks: $AFTER_NETWORKS"
    echo "Unused images: $AFTER_UNUSED_IMAGES"
    echo "Dangling images: $AFTER_DANGLING"
    echo ""

    # Run assertions based on test mode
    echo -e "${BLUE}=== Test Results ===${NC}"

    if [ "$DRY_RUN_MODE" = true ]; then
        # Dry-run mode: nothing should be deleted
        echo -e "${YELLOW}Testing dry-run mode (no resources should be deleted)${NC}"
        assert_equals "Dry-run: Running containers unchanged" "$BEFORE_RUNNING" "$AFTER_RUNNING"
        assert_equals "Dry-run: Stopped containers unchanged" "$BEFORE_STOPPED" "$AFTER_STOPPED"
        assert_equals "Dry-run: Volumes unchanged" "$BEFORE_VOLUMES" "$AFTER_VOLUMES"
        assert_equals "Dry-run: Networks unchanged" "$BEFORE_NETWORKS" "$AFTER_NETWORKS"
        # Dry-run returns exit code 0 (success) even though no operations were actually performed
        assert_equals "Dry-run: Exit code is 0" "0" "$cleanup_exit_code"

    elif [ "$PRUNE_ALL_MODE" = true ] && [ "$PRUNE_VOLUMES_MODE" = true ]; then
        # Aggressive mode: remove all unused resources
        echo -e "${YELLOW}Testing aggressive cleanup mode${NC}"
        assert_equals "Running containers protected" "$BEFORE_RUNNING" "$AFTER_RUNNING"
        assert_zero "All stopped containers removed" "$AFTER_STOPPED"
        assert_zero "All unused volumes removed" "$AFTER_UNUSED_VOLUMES"
        assert_less_than "Unused networks removed" "$BEFORE_NETWORKS" "$AFTER_NETWORKS"
        if [ "$BEFORE_UNUSED_IMAGES" -gt 0 ]; then
            assert_less_than "Unused images removed" "$BEFORE_UNUSED_IMAGES" "$AFTER_UNUSED_IMAGES"
        fi
        assert_zero "Dangling images removed" "$AFTER_DANGLING"

    elif [ "$PRUNE_ALL_MODE" = true ]; then
        # Prune all images but keep volumes
        echo -e "${YELLOW}Testing prune-all mode (volumes protected)${NC}"
        assert_equals "Running containers protected" "$BEFORE_RUNNING" "$AFTER_RUNNING"
        assert_zero "All stopped containers removed" "$AFTER_STOPPED"
        assert_equals "Volumes protected" "$BEFORE_VOLUMES" "$AFTER_VOLUMES"
        assert_less_than "Unused networks removed" "$BEFORE_NETWORKS" "$AFTER_NETWORKS"
        if [ "$BEFORE_UNUSED_IMAGES" -gt 0 ]; then
            assert_less_than "Unused images removed" "$BEFORE_UNUSED_IMAGES" "$AFTER_UNUSED_IMAGES"
        fi
        assert_zero "Dangling images removed" "$AFTER_DANGLING"

    else
        # Default mode: conservative cleanup
        echo -e "${YELLOW}Testing default cleanup mode (conservative)${NC}"
        assert_equals "Running containers protected" "$BEFORE_RUNNING" "$AFTER_RUNNING"
        assert_zero "All stopped containers removed" "$AFTER_STOPPED"
        assert_equals "Volumes protected by default" "$BEFORE_VOLUMES" "$AFTER_VOLUMES"
        assert_less_than "Unused networks removed" "$BEFORE_NETWORKS" "$AFTER_NETWORKS"
        assert_zero "Dangling images removed" "$AFTER_DANGLING"
    fi

    # Test resource protection
    echo ""
    echo -e "${BLUE}=== Protection Tests ===${NC}"

    # Check that running containers are still there
    assert_not_zero "Running containers exist" "$AFTER_RUNNING"

    # Summary
    echo ""
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${BLUE}   Test Summary${NC}"
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${GREEN}PASS: $PASS${NC}"
    if [ "$FAIL" -gt 0 ]; then
        echo -e "${RED}FAIL: $FAIL${NC}"
    else
        echo -e "${GREEN}FAIL: $FAIL${NC}"
    fi
    echo ""

    if [ "$FAIL" -eq 0 ]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

# Run main
main
