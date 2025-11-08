#!/bin/bash
# 02-02-validate-cleanup.sh - Validate that cleanup operations work correctly

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
MODE="full"  # full, before, after
TARGET_CONTEXT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --before)
            MODE="before"
            shift
            ;;
        --after)
            MODE="after"
            shift
            ;;
        --context)
            TARGET_CONTEXT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--before|--after] [--context <name>]"
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

# Assertion functions
assert_equals() {
    local description="$1"
    local expected="$2"
    local actual="$3"

    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $description (expected=$expected, actual=$actual)"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $description (expected=$expected, actual=$actual)"
        return 1
    fi
}

assert_zero() {
    local description="$1"
    local actual="$2"

    if [ "$actual" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $description (value=$actual)"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $description (expected=0, actual=$actual)"
        return 1
    fi
}

assert_not_zero() {
    local description="$1"
    local actual="$2"

    if [ "$actual" -gt 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $description (value=$actual)"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $description (expected>0, actual=$actual)"
        return 1
    fi
}

assert_less_than() {
    local description="$1"
    local before="$2"
    local after="$3"

    if [ "$after" -lt "$before" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $description (before=$before, after=$after)"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $description (before=$before, after=$after)"
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

count_all_containers() {
    docker_ctx ps -aq --filter label=test-cleanup=true 2>/dev/null | wc -l | tr -d ' '
}

count_labeled_images() {
    docker_ctx images -q --filter label=test-cleanup=true 2>/dev/null | wc -l | tr -d ' '
}

count_dangling_images() {
    docker_ctx images -f dangling=true -q 2>/dev/null | wc -l | tr -d ' '
}

count_volumes() {
    docker_ctx volume ls -q --filter label=test-cleanup=true 2>/dev/null | wc -l | tr -d ' '
}

count_networks() {
    docker_ctx network ls -q --filter label=test-cleanup=true 2>/dev/null | wc -l | tr -d ' '
}

count_protected_resources() {
    docker_ctx ps -aq --filter label=test-cleanup=true --filter label=keep=true 2>/dev/null | wc -l | tr -d ' '
}

# Print resource counts
print_resource_counts() {
    local prefix="$1"

    echo -e "${BLUE}=== ${prefix} Resource Counts ===${NC}"
    echo "Docker Context: $(docker_ctx context show)"
    echo ""
    echo "Containers (running):  $(count_running_containers)"
    echo "Containers (stopped):  $(count_stopped_containers)"
    echo "Containers (total):    $(count_all_containers)"
    echo "Images (labeled):      $(count_labeled_images)"
    echo "Images (dangling):     $(count_dangling_images)"
    echo "Volumes:               $(count_volumes)"
    echo "Networks:              $(count_networks)"
    echo "Protected resources:   $(count_protected_resources)"
    echo ""
}

# Before validation mode
validate_before() {
    echo -e "${BLUE}=== Docker Cleanup Validation - Before Cleanup ===${NC}"
    echo ""

    print_resource_counts "Before Cleanup"

    echo -e "${YELLOW}INFO:${NC} Validation complete. Resources are ready for cleanup testing."
    echo ""
    echo "Next steps:"
    echo "  1. Run cleanup operation"
    if [ -n "$TARGET_CONTEXT" ]; then
        echo "  2. Run: $0 --after --context $TARGET_CONTEXT"
    else
        echo "  2. Run: $0 --after"
    fi

    exit 0
}

# After validation mode
validate_after() {
    echo -e "${BLUE}=== Docker Cleanup Validation - After Cleanup ===${NC}"
    echo ""

    print_resource_counts "After Cleanup"

    # Basic validation
    local stopped=$(count_stopped_containers)
    local running=$(count_running_containers)

    echo -e "${BLUE}=== Validation Results ===${NC}"

    if [ "$stopped" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: All stopped containers removed"
    else
        echo -e "${RED}✗ FAIL${NC}: Stopped containers remaining: $stopped"
    fi

    if [ "$running" -gt 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: Running containers protected"
    else
        echo -e "${YELLOW}INFO${NC}: No running containers to protect"
    fi

    exit 0
}

# Full validation mode (setup, cleanup, validate)
validate_full() {
    echo -e "${BLUE}=== Docker Cleanup Container - Full Validation Tests ===${NC}"
    echo ""

    local PASS=0
    local FAIL=0

    # Test function
    run_test() {
        local test_result=$?
        if [ $test_result -eq 0 ]; then
            PASS=$((PASS + 1))
        else
            FAIL=$((FAIL + 1))
        fi
    }

    # Setup test resources
    echo -e "${BLUE}Setting up test resources...${NC}"
    if [ -n "$TARGET_CONTEXT" ]; then
        ./tests/01-setup-test-resources.sh --context "$TARGET_CONTEXT" >/dev/null 2>&1
    else
        ./tests/01-setup-test-resources.sh >/dev/null 2>&1
    fi
    echo -e "${GREEN}✓ Test resources created${NC}"
    echo ""

    # Count resources before cleanup
    BEFORE_STOPPED=$(count_stopped_containers)
    BEFORE_VOLUMES=$(count_volumes)
    BEFORE_NETWORKS=$(count_networks)
    BEFORE_RUNNING=$(count_running_containers)
    BEFORE_PROTECTED=$(count_protected_resources)

    print_resource_counts "Before Cleanup"

    # Test 1: Dry-run mode doesn't delete anything
    echo -e "${BLUE}Test 1: Dry-run mode...${NC}"
    docker_ctx run --rm -v /var/run/docker.sock:/var/run/docker.sock -e DRY_RUN=true docker-cleaner >/dev/null 2>&1 || true

    AFTER_DRY_STOPPED=$(count_stopped_containers)
    assert_equals "Dry-run preserves stopped containers" "$BEFORE_STOPPED" "$AFTER_DRY_STOPPED"
    run_test

    # Test 2: Default cleanup removes stopped containers
    echo ""
    echo -e "${BLUE}Test 2: Default cleanup...${NC}"
    docker_ctx run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner >/dev/null 2>&1 || true

    AFTER_STOPPED=$(count_stopped_containers)
    assert_zero "Default cleanup removes stopped containers" "$AFTER_STOPPED"
    run_test

    # Test 3: Running containers are protected
    AFTER_RUNNING=$(count_running_containers)
    assert_equals "Running containers protected" "$BEFORE_RUNNING" "$AFTER_RUNNING"
    run_test

    # Test 4: Volumes protected by default
    AFTER_VOLUMES=$(count_volumes)
    assert_equals "Volumes protected by default" "$BEFORE_VOLUMES" "$AFTER_VOLUMES"
    run_test

    # Test 5: Networks (unused) are cleaned
    AFTER_NETWORKS=$(count_networks)
    assert_less_than "Unused networks removed" "$BEFORE_NETWORKS" "$AFTER_NETWORKS"
    run_test

    # Test 6: Label-based protection
    echo ""
    echo -e "${BLUE}Test 6: Label-based protection...${NC}"
    if [ -n "$TARGET_CONTEXT" ]; then
        ./tests/01-setup-test-resources.sh --context "$TARGET_CONTEXT" >/dev/null 2>&1
    else
        ./tests/01-setup-test-resources.sh >/dev/null 2>&1
    fi

    BEFORE_PROTECTED=$(count_protected_resources)
    docker_ctx run --rm -v /var/run/docker.sock:/var/run/docker.sock \
        -e PRUNE_FILTER_LABEL="keep!=true" \
        docker-cleaner >/dev/null 2>&1 || true

    AFTER_PROTECTED=$(count_protected_resources)
    assert_equals "Label-protected resources preserved" "$BEFORE_PROTECTED" "$AFTER_PROTECTED"
    run_test

    # Cleanup
    echo ""
    echo -e "${BLUE}Cleaning up test resources...${NC}"
    if [ -n "$TARGET_CONTEXT" ]; then
        ./tests/03-cleanup-test-resources.sh --context "$TARGET_CONTEXT" >/dev/null 2>&1
    else
        ./tests/03-cleanup-test-resources.sh >/dev/null 2>&1
    fi

    # Summary
    echo ""
    echo -e "${BLUE}=== Validation Results ===${NC}"
    echo -e "${GREEN}PASS: $PASS${NC}"
    if [ "$FAIL" -gt 0 ]; then
        echo -e "${RED}FAIL: $FAIL${NC}"
    else
        echo -e "${GREEN}FAIL: $FAIL${NC}"
    fi
    echo ""

    if [ "$FAIL" -eq 0 ]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        exit 1
    fi
}

# Execute based on mode
case $MODE in
    before)
        validate_before
        ;;
    after)
        validate_after
        ;;
    full)
        validate_full
        ;;
esac
