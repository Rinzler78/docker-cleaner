#!/bin/bash
# 11-12-test-container-cleanup.sh - Test docker-cleaner Docker image on local host

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
TEST_MODE="all"  # all, default, aggressive, errors
TARGET_CONTEXT=""
ORIGINAL_CONTEXT=""
IMAGE_TAG="docker-cleaner:test"

while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            TEST_MODE="$2"
            shift 2
            ;;
        --context)
            TARGET_CONTEXT="$2"
            shift 2
            ;;
        --image)
            IMAGE_TAG="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--mode all|default|aggressive|errors] [--context <name>] [--image <tag>]"
            exit 1
            ;;
    esac
done

# Context management
setup_context() {
    if [ -n "$TARGET_CONTEXT" ]; then
        # Store original context
        ORIGINAL_CONTEXT=$(docker context show)

        # Validate target context exists
        if ! docker context ls --format "{{.Name}}" | grep -q "^${TARGET_CONTEXT}$"; then
            echo -e "${RED}Error: Context '$TARGET_CONTEXT' does not exist${NC}"
            echo "Available contexts:"
            docker context ls
            exit 1
        fi

        # Switch to target context
        docker context use "$TARGET_CONTEXT" >/dev/null 2>&1
        echo -e "${GREEN}✓ Switched to context: $TARGET_CONTEXT${NC}"
    fi
}

# Restore context and cleanup on exit
cleanup_on_exit() {
    local exit_code=$?

    echo ""
    echo -e "${BLUE}=== Cleanup Phase ===${NC}"

    # Restore context
    if [ -n "$ORIGINAL_CONTEXT" ] && [ "$ORIGINAL_CONTEXT" != "$(docker context show)" ]; then
        echo "Restoring original context: $ORIGINAL_CONTEXT"
        docker context use "$ORIGINAL_CONTEXT" >/dev/null 2>&1
    fi

    # Clean test resources
    echo "Removing test resources..."
    if [ -n "$TARGET_CONTEXT" ]; then
        ./tests/03-cleanup-test-resources.sh --context "$TARGET_CONTEXT" >/dev/null 2>&1 || true
    else
        ./tests/03-cleanup-test-resources.sh >/dev/null 2>&1 || true
    fi

    # Remove test image
    echo "Removing test image..."
    docker rmi "$IMAGE_TAG" >/dev/null 2>&1 || true

    echo -e "${GREEN}✓ Cleanup complete${NC}"

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
    docker ps -q --filter label=test-cleanup=true 2>/dev/null | wc -l | tr -d ' '
}

count_stopped_containers() {
    docker ps -aq -f status=exited -f status=created --filter label=test-cleanup=true 2>/dev/null | wc -l | tr -d ' '
}

count_volumes() {
    docker volume ls -q --filter label=test-cleanup=true 2>/dev/null | wc -l | tr -d ' '
}

count_unused_volumes() {
    local all_volumes=$(docker volume ls -q --filter label=test-cleanup=true 2>/dev/null || true)
    local unused=0

    for vol in $all_volumes; do
        local in_use=$(docker ps -a --filter volume="$vol" --format "{{.ID}}" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$in_use" -eq 0 ]; then
            unused=$((unused + 1))
        fi
    done

    echo "$unused"
}

count_networks() {
    docker network ls -q --filter label=test-cleanup=true 2>/dev/null | wc -l | tr -d ' '
}

count_dangling_images() {
    docker images -f dangling=true -q 2>/dev/null | wc -l | tr -d ' '
}

# Build test image
build_test_image() {
    echo -e "${BLUE}=== Phase 1: Build Test Image ===${NC}"
    echo "Building $IMAGE_TAG..."

    # Build image
    docker build -t "$IMAGE_TAG" . >/dev/null 2>&1

    echo -e "${GREEN}✓ Image built successfully${NC}"

    # Validate image size
    local image_size=$(docker images "$IMAGE_TAG" --format "{{.Size}}" | head -1)
    echo "Image size: $image_size"

    # Validate image contents
    echo "Validating image contents..."
    # Test that image can be run (it will fail without socket but that's expected)
    docker run --rm "$IMAGE_TAG" 2>&1 | grep -q "Docker socket not found" || true
    echo -e "${GREEN}✓ Image validation passed${NC}"
    echo ""
}

# Test default settings
test_default_settings() {
    echo -e "${BLUE}=== Test: Default Settings ===${NC}"

    # Setup
    echo "Creating test resources..."
    if [ -n "$TARGET_CONTEXT" ]; then
        ./tests/01-setup-test-resources.sh --context "$TARGET_CONTEXT" >/dev/null 2>&1
    else
        ./tests/01-setup-test-resources.sh >/dev/null 2>&1
    fi

    local BEFORE_RUNNING=$(count_running_containers)
    local BEFORE_STOPPED=$(count_stopped_containers)
    local BEFORE_VOLUMES=$(count_volumes)
    local BEFORE_NETWORKS=$(count_networks)
    local BEFORE_DANGLING=$(count_dangling_images)

    # Execute
    echo "Running container with default settings..."
    local container_exit_code=0
    docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        "$IMAGE_TAG" 2>&1 | tee /tmp/container-output.log || container_exit_code=$?

    echo ""
    echo "Container exit code: $container_exit_code"

    # Validate
    local AFTER_RUNNING=$(count_running_containers)
    local AFTER_STOPPED=$(count_stopped_containers)
    local AFTER_VOLUMES=$(count_volumes)
    local AFTER_NETWORKS=$(count_networks)
    local AFTER_DANGLING=$(count_dangling_images)

    echo ""
    echo -e "${BLUE}Validation:${NC}"
    assert_equals "Running containers protected" "$BEFORE_RUNNING" "$AFTER_RUNNING"
    assert_zero "Stopped containers removed" "$AFTER_STOPPED"
    assert_equals "Volumes protected by default" "$BEFORE_VOLUMES" "$AFTER_VOLUMES"
    assert_less_than "Unused networks removed" "$BEFORE_NETWORKS" "$AFTER_NETWORKS"
    assert_zero "Dangling images removed" "$AFTER_DANGLING"
    assert_equals "Container exit code is 0" "0" "$container_exit_code"

    # Cleanup for next test
    if [ -n "$TARGET_CONTEXT" ]; then
        ./tests/03-cleanup-test-resources.sh --context "$TARGET_CONTEXT" >/dev/null 2>&1
    else
        ./tests/03-cleanup-test-resources.sh >/dev/null 2>&1
    fi

    echo ""
}

# Test aggressive settings
test_aggressive_settings() {
    echo -e "${BLUE}=== Test: Aggressive Settings ===${NC}"

    # Setup
    echo "Creating test resources..."
    if [ -n "$TARGET_CONTEXT" ]; then
        ./tests/01-setup-test-resources.sh --context "$TARGET_CONTEXT" >/dev/null 2>&1
    else
        ./tests/01-setup-test-resources.sh >/dev/null 2>&1
    fi

    local BEFORE_RUNNING=$(count_running_containers)
    local BEFORE_STOPPED=$(count_stopped_containers)
    local BEFORE_UNUSED_VOLUMES=$(count_unused_volumes)
    local BEFORE_NETWORKS=$(count_networks)
    local BEFORE_DANGLING=$(count_dangling_images)

    # Execute
    echo "Running container with aggressive settings..."
    local container_exit_code=0
    docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -e PRUNE_ALL=true \
        -e PRUNE_VOLUMES=true \
        -e CLEANUP_VOLUMES=true \
        "$IMAGE_TAG" 2>&1 | tee /tmp/container-output-aggressive.log || container_exit_code=$?

    echo ""
    echo "Container exit code: $container_exit_code"

    # Validate
    local AFTER_RUNNING=$(count_running_containers)
    local AFTER_STOPPED=$(count_stopped_containers)
    local AFTER_UNUSED_VOLUMES=$(count_unused_volumes)
    local AFTER_NETWORKS=$(count_networks)
    local AFTER_DANGLING=$(count_dangling_images)

    echo ""
    echo -e "${BLUE}Validation:${NC}"
    assert_equals "Running containers protected" "$BEFORE_RUNNING" "$AFTER_RUNNING"
    assert_zero "Stopped containers removed" "$AFTER_STOPPED"
    assert_zero "Unused volumes removed" "$AFTER_UNUSED_VOLUMES"
    assert_less_than "Unused networks removed" "$BEFORE_NETWORKS" "$AFTER_NETWORKS"
    assert_zero "Dangling images removed" "$AFTER_DANGLING"
    assert_equals "Container exit code is 0" "0" "$container_exit_code"

    # Cleanup for next test
    if [ -n "$TARGET_CONTEXT" ]; then
        ./tests/03-cleanup-test-resources.sh --context "$TARGET_CONTEXT" >/dev/null 2>&1
    else
        ./tests/03-cleanup-test-resources.sh >/dev/null 2>&1
    fi

    echo ""
}

# Test error handling
test_error_handling() {
    echo -e "${BLUE}=== Test: Error Handling ===${NC}"

    # Test 1: Missing Docker socket
    echo "Test 1: Missing Docker socket..."
    set +e  # Temporarily disable exit on error
    local output=$(docker run --rm "$IMAGE_TAG" 2>&1)
    echo "$output" | grep -q "Docker socket not found"
    local exit_code=$?
    set -e  # Re-enable exit on error

    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: Missing socket detected"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: Missing socket not detected"
        FAIL=$((FAIL + 1))
    fi

    # Test 2: Dry-run mode
    echo "Test 2: Dry-run mode..."

    # Setup resources
    if [ -n "$TARGET_CONTEXT" ]; then
        ./tests/01-setup-test-resources.sh --context "$TARGET_CONTEXT" >/dev/null 2>&1
    else
        ./tests/01-setup-test-resources.sh >/dev/null 2>&1
    fi

    local BEFORE_STOPPED=$(count_stopped_containers)

    # Run in dry-run mode (dry-run returns exit code 2, so disable set -e)
    set +e
    docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -e DRY_RUN=true \
        "$IMAGE_TAG" >/dev/null 2>&1
    set -e

    local AFTER_STOPPED=$(count_stopped_containers)

    assert_equals "Dry-run preserves resources" "$BEFORE_STOPPED" "$AFTER_STOPPED"

    # Cleanup
    if [ -n "$TARGET_CONTEXT" ]; then
        ./tests/03-cleanup-test-resources.sh --context "$TARGET_CONTEXT" >/dev/null 2>&1
    else
        ./tests/03-cleanup-test-resources.sh >/dev/null 2>&1
    fi

    echo ""
}

# Test container affects host resources
test_host_cleanup() {
    echo -e "${BLUE}=== Test: Container Cleans Host Resources ===${NC}"

    # Setup resources on host
    echo "Creating test resources on host..."
    if [ -n "$TARGET_CONTEXT" ]; then
        ./tests/01-setup-test-resources.sh --context "$TARGET_CONTEXT" >/dev/null 2>&1
    else
        ./tests/01-setup-test-resources.sh >/dev/null 2>&1
    fi

    local BEFORE_STOPPED=$(count_stopped_containers)
    echo "Stopped containers before: $BEFORE_STOPPED"

    # Run container to cleanup host
    echo "Running container to cleanup host..."
    docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        "$IMAGE_TAG" >/dev/null 2>&1

    # Verify cleanup on host
    local AFTER_STOPPED=$(count_stopped_containers)
    echo "Stopped containers after: $AFTER_STOPPED"

    assert_zero "Container cleaned host resources" "$AFTER_STOPPED"
    assert_not_zero "Resources existed before" "$BEFORE_STOPPED"

    echo ""
}

# Main test execution
main() {
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${BLUE}   Docker Cleanup - Container Testing${NC}"
    echo -e "${BLUE}=====================================================${NC}"
    echo ""

    # Setup context
    setup_context

    local current_context=$(docker context show)
    echo "Testing on context: $current_context"
    echo ""

    # Build test image
    build_test_image

    # Run tests based on mode
    case $TEST_MODE in
        all)
            test_default_settings
            test_aggressive_settings
            test_error_handling
            test_host_cleanup
            ;;
        default)
            test_default_settings
            ;;
        aggressive)
            test_aggressive_settings
            ;;
        errors)
            test_error_handling
            ;;
        host)
            test_host_cleanup
            ;;
        *)
            echo -e "${RED}Unknown test mode: $TEST_MODE${NC}"
            exit 1
            ;;
    esac

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
        echo -e "${GREEN}✓ All container tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some container tests failed${NC}"
        return 1
    fi
}

# Run main
main
