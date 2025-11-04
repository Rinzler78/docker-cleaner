#!/bin/bash
# test-remote-contexts.sh - Test docker-cleaner on remote Docker hosts via contexts

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
SPECIFIC_CONTEXT=""
CONTEXTS_LIST=""
IMAGE_TAG="docker-cleaner:test"
ORIGINAL_CONTEXT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --context)
            SPECIFIC_CONTEXT="$2"
            shift 2
            ;;
        --contexts)
            CONTEXTS_LIST="$2"
            shift 2
            ;;
        --image)
            IMAGE_TAG="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--context <name>] [--contexts <name1,name2>] [--image <tag>]"
            exit 1
            ;;
    esac
done

# Store original context
ORIGINAL_CONTEXT=$(docker context show)

# Restore context on exit
cleanup_on_exit() {
    local exit_code=$?

    echo ""
    echo -e "${BLUE}=== Restoring Original Context ===${NC}"

    if [ -n "$ORIGINAL_CONTEXT" ]; then
        docker context use "$ORIGINAL_CONTEXT" >/dev/null 2>&1
        echo -e "${GREEN}✓ Restored to context: $ORIGINAL_CONTEXT${NC}"
    fi

    exit $exit_code
}

# Set trap for cleanup
trap cleanup_on_exit EXIT INT TERM

# Test results tracking
declare -A CONTEXT_RESULTS
FAILED_CONTEXTS=()

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

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

count_networks() {
    docker network ls -q --filter label=test-cleanup=true 2>/dev/null | wc -l | tr -d ' '
}

# Check if context is reachable
check_context_connectivity() {
    local context_name="$1"

    # Try to list containers
    if docker ps >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check if image exists on context
check_image_exists() {
    local context_name="$1"
    local image="$2"

    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image}$"; then
        return 0
    else
        return 1
    fi
}

# Test single context
test_context() {
    local context_name="$1"

    echo ""
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${BLUE}   Testing Context: $context_name${NC}"
    echo -e "${BLUE}=====================================================${NC}"
    echo ""

    # Switch to context
    echo "Switching to context: $context_name"
    if ! docker context use "$context_name" >/dev/null 2>&1; then
        echo -e "${RED}✗ Failed to switch to context: $context_name${NC}"
        CONTEXT_RESULTS["$context_name"]="FAILED - Cannot switch context"
        FAILED_CONTEXTS+=("$context_name")
        return 1
    fi

    echo -e "${GREEN}✓ Switched to context: $context_name${NC}"
    echo ""

    # Check connectivity
    echo "Checking context connectivity..."
    if ! check_context_connectivity "$context_name"; then
        echo -e "${RED}✗ Context unreachable: $context_name${NC}"
        CONTEXT_RESULTS["$context_name"]="FAILED - Context unreachable"
        FAILED_CONTEXTS+=("$context_name")
        return 1
    fi

    echo -e "${GREEN}✓ Context is reachable${NC}"
    echo ""

    # Check if image exists
    echo "Checking if image exists..."
    if ! check_image_exists "$context_name" "$IMAGE_TAG"; then
        echo -e "${YELLOW}⚠ Image not found on remote context: $IMAGE_TAG${NC}"
        echo "Please build or push the image to this context first:"
        echo "  docker context use $context_name"
        echo "  docker build -t $IMAGE_TAG ."
        echo ""
        CONTEXT_RESULTS["$context_name"]="SKIPPED - Image not available"
        return 0
    fi

    echo -e "${GREEN}✓ Image found: $IMAGE_TAG${NC}"
    echo ""

    # Phase 1: Setup resources
    echo -e "${BLUE}=== Phase 1: Setup Resources ===${NC}"
    echo "Creating test resources on $context_name..."

    if ! ./tests/setup-test-resources.sh --context "$context_name" >/dev/null 2>&1; then
        echo -e "${RED}✗ Failed to create test resources on $context_name${NC}"
        CONTEXT_RESULTS["$context_name"]="FAILED - Setup failed"
        FAILED_CONTEXTS+=("$context_name")
        return 1
    fi

    echo -e "${GREEN}✓ Test resources created${NC}"
    echo ""

    # Count before
    local BEFORE_RUNNING=$(count_running_containers)
    local BEFORE_STOPPED=$(count_stopped_containers)
    local BEFORE_VOLUMES=$(count_volumes)
    local BEFORE_NETWORKS=$(count_networks)

    echo "Resources before cleanup:"
    echo "  Running containers: $BEFORE_RUNNING"
    echo "  Stopped containers: $BEFORE_STOPPED"
    echo "  Volumes: $BEFORE_VOLUMES"
    echo "  Networks: $BEFORE_NETWORKS"
    echo ""

    # Phase 2: Execute cleanup
    echo -e "${BLUE}=== Phase 2: Execute Cleanup ===${NC}"
    echo "Running docker-cleaner on $context_name..."

    local container_exit_code=0
    docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        "$IMAGE_TAG" 2>&1 | tee "/tmp/remote-cleanup-$context_name.log" || container_exit_code=$?

    echo ""
    echo "Container exit code: $container_exit_code"
    echo ""

    # Phase 3: Validation
    echo -e "${BLUE}=== Phase 3: Validation ===${NC}"

    local AFTER_RUNNING=$(count_running_containers)
    local AFTER_STOPPED=$(count_stopped_containers)
    local AFTER_VOLUMES=$(count_volumes)
    local AFTER_NETWORKS=$(count_networks)

    echo "Resources after cleanup:"
    echo "  Running containers: $AFTER_RUNNING"
    echo "  Stopped containers: $AFTER_STOPPED"
    echo "  Volumes: $AFTER_VOLUMES"
    echo "  Networks: $AFTER_NETWORKS"
    echo ""

    # Validate results
    local context_passed=true
    local test_results=""

    TOTAL_TESTS=$((TOTAL_TESTS + 5))

    # Test 1: Running containers protected
    if [ "$BEFORE_RUNNING" -eq "$AFTER_RUNNING" ]; then
        echo -e "${GREEN}✓ PASS${NC}: Running containers protected"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        test_results+="✓ Running containers protected\n"
    else
        echo -e "${RED}✗ FAIL${NC}: Running containers not protected (before=$BEFORE_RUNNING, after=$AFTER_RUNNING)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        context_passed=false
        test_results+="✗ Running containers not protected\n"
    fi

    # Test 2: Stopped containers removed
    if [ "$AFTER_STOPPED" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: Stopped containers removed"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        test_results+="✓ Stopped containers removed\n"
    else
        echo -e "${RED}✗ FAIL${NC}: Stopped containers not removed (remaining=$AFTER_STOPPED)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        context_passed=false
        test_results+="✗ Stopped containers not removed\n"
    fi

    # Test 3: Volumes protected
    if [ "$BEFORE_VOLUMES" -eq "$AFTER_VOLUMES" ]; then
        echo -e "${GREEN}✓ PASS${NC}: Volumes protected by default"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        test_results+="✓ Volumes protected\n"
    else
        echo -e "${RED}✗ FAIL${NC}: Volumes not protected (before=$BEFORE_VOLUMES, after=$AFTER_VOLUMES)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        context_passed=false
        test_results+="✗ Volumes not protected\n"
    fi

    # Test 4: Networks cleaned
    if [ "$AFTER_NETWORKS" -lt "$BEFORE_NETWORKS" ]; then
        echo -e "${GREEN}✓ PASS${NC}: Unused networks removed"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        test_results+="✓ Unused networks removed\n"
    else
        echo -e "${RED}✗ FAIL${NC}: Unused networks not removed (before=$BEFORE_NETWORKS, after=$AFTER_NETWORKS)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        context_passed=false
        test_results+="✗ Unused networks not removed\n"
    fi

    # Test 5: Exit code
    if [ "$container_exit_code" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: Container exit code is 0"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        test_results+="✓ Container exit code correct\n"
    else
        echo -e "${RED}✗ FAIL${NC}: Container exit code is $container_exit_code (expected 0)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        context_passed=false
        test_results+="✗ Container exit code incorrect\n"
    fi

    echo ""

    # Phase 4: Cleanup
    echo -e "${BLUE}=== Phase 4: Cleanup ===${NC}"
    echo "Cleaning up test resources on $context_name..."

    ./tests/cleanup-test-resources.sh --context "$context_name" >/dev/null 2>&1 || true

    echo -e "${GREEN}✓ Test resources cleaned${NC}"

    # Store results
    if [ "$context_passed" = true ]; then
        CONTEXT_RESULTS["$context_name"]="PASSED"
        echo -e "${GREEN}✓ All tests passed for context: $context_name${NC}"
        return 0
    else
        CONTEXT_RESULTS["$context_name"]="FAILED - Some tests failed"
        FAILED_CONTEXTS+=("$context_name")
        echo -e "${RED}✗ Some tests failed for context: $context_name${NC}"
        return 1
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${BLUE}   Docker Cleanup - Remote Context Testing${NC}"
    echo -e "${BLUE}=====================================================${NC}"
    echo ""

    echo "Original context: $ORIGINAL_CONTEXT"
    echo ""

    # Determine which contexts to test
    local contexts_to_test=""

    if [ -n "$SPECIFIC_CONTEXT" ]; then
        contexts_to_test="$SPECIFIC_CONTEXT"
        echo "Testing specific context: $SPECIFIC_CONTEXT"
    elif [ -n "$CONTEXTS_LIST" ]; then
        contexts_to_test=$(echo "$CONTEXTS_LIST" | tr ',' ' ')
        echo "Testing specified contexts: $CONTEXTS_LIST"
    else
        # Detect all available contexts
        contexts_to_test=$(docker context ls --format "{{.Name}}")
        echo "Testing all available contexts:"
        docker context ls
    fi

    echo ""

    # Build image on original context if needed
    echo -e "${BLUE}=== Building Test Image on Original Context ===${NC}"
    if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${IMAGE_TAG}$"; then
        echo "Building $IMAGE_TAG..."
        docker build -t "$IMAGE_TAG" . >/dev/null 2>&1
        echo -e "${GREEN}✓ Image built successfully${NC}"
    else
        echo -e "${GREEN}✓ Image already exists${NC}"
    fi
    echo ""

    # Test each context
    local tested_count=0
    local passed_count=0
    local failed_count=0
    local skipped_count=0

    for ctx in $contexts_to_test; do
        tested_count=$((tested_count + 1))

        test_context "$ctx"
        local test_result=$?

        if [ $test_result -eq 0 ]; then
            if [ "${CONTEXT_RESULTS[$ctx]}" = "PASSED" ]; then
                passed_count=$((passed_count + 1))
            else
                skipped_count=$((skipped_count + 1))
            fi
        else
            failed_count=$((failed_count + 1))
        fi

        # Restore to original context between tests
        docker context use "$ORIGINAL_CONTEXT" >/dev/null 2>&1
    done

    # Summary
    echo ""
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${BLUE}   Multi-Context Test Summary${NC}"
    echo -e "${BLUE}=====================================================${NC}"
    echo ""

    echo "Contexts tested: $tested_count"
    echo -e "${GREEN}Passed: $passed_count${NC}"
    echo -e "${YELLOW}Skipped: $skipped_count${NC}"
    if [ $failed_count -gt 0 ]; then
        echo -e "${RED}Failed: $failed_count${NC}"
    else
        echo -e "${GREEN}Failed: $failed_count${NC}"
    fi
    echo ""

    echo "Detailed results by context:"
    for ctx in $contexts_to_test; do
        local result="${CONTEXT_RESULTS[$ctx]}"
        if [ "$result" = "PASSED" ]; then
            echo -e "  ${GREEN}✓${NC} $ctx: $result"
        elif [[ "$result" == SKIPPED* ]]; then
            echo -e "  ${YELLOW}⚠${NC} $ctx: $result"
        else
            echo -e "  ${RED}✗${NC} $ctx: $result"
        fi
    done

    echo ""
    echo "Test assertions:"
    echo -e "${GREEN}PASS: $PASSED_TESTS${NC}"
    if [ $FAILED_TESTS -gt 0 ]; then
        echo -e "${RED}FAIL: $FAILED_TESTS${NC}"
    else
        echo -e "${GREEN}FAIL: $FAILED_TESTS${NC}"
    fi
    echo ""

    if [ $failed_count -eq 0 ]; then
        echo -e "${GREEN}✓ All remote context tests passed (or skipped gracefully)!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some remote context tests failed${NC}"
        echo "Failed contexts: ${FAILED_CONTEXTS[*]}"
        return 1
    fi
}

# Run main
main
