#!/bin/bash
# 11-13-test-remote-contexts.sh - Test docker-cleaner on remote Docker hosts via contexts

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source context utilities
source "${SCRIPT_DIR}/lib/context-utils.sh"

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

# Test results tracking (Bash 3.2 compatible - no associative arrays)
# Use parallel arrays for context results
TESTED_CONTEXTS=()
CONTEXT_RESULTS=()
FAILED_CONTEXTS=()

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Helper functions for managing context results (Bash 3.2 compatible)
set_context_result() {
    local ctx="$1"
    local result="$2"

    # Check if context already exists
    local idx=-1
    for i in "${!TESTED_CONTEXTS[@]}"; do
        if [ "${TESTED_CONTEXTS[$i]}" = "$ctx" ]; then
            idx=$i
            break
        fi
    done

    if [ $idx -ge 0 ]; then
        # Update existing
        CONTEXT_RESULTS[$idx]="$result"
    else
        # Add new
        TESTED_CONTEXTS+=("$ctx")
        CONTEXT_RESULTS+=("$result")
    fi
}

get_context_result() {
    local ctx="$1"

    for i in "${!TESTED_CONTEXTS[@]}"; do
        if [ "${TESTED_CONTEXTS[$i]}" = "$ctx" ]; then
            echo "${CONTEXT_RESULTS[$i]}"
            return 0
        fi
    done

    echo ""
    return 1
}

# Docker context wrapper for a specific context (used within test_context)
docker_ctx() {
    local ctx="$1"
    shift
    docker --context "$ctx" "$@"
}

# Resource counting functions (use context-specific commands)
count_running_containers() {
    local ctx="$1"
    docker_ctx "$ctx" ps -q --filter label=test-cleanup=true 2>/dev/null | wc -l | tr -d ' '
}

count_stopped_containers() {
    local ctx="$1"
    docker_ctx "$ctx" ps -aq -f status=exited -f status=created --filter label=test-cleanup=true 2>/dev/null | wc -l | tr -d ' '
}

count_volumes() {
    local ctx="$1"
    docker_ctx "$ctx" volume ls -q --filter label=test-cleanup=true 2>/dev/null | wc -l | tr -d ' '
}

count_networks() {
    local ctx="$1"
    docker_ctx "$ctx" network ls -q --filter label=test-cleanup=true 2>/dev/null | wc -l | tr -d ' '
}

# Check if context is reachable
check_context_connectivity() {
    local context_name="$1"

    # Try to list containers
    if docker_ctx "$context_name" ps >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check if image exists on context
check_image_exists() {
    local context_name="$1"
    local image="$2"

    if docker_ctx "$context_name" images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image}$"; then
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
        set_context_result "$context_name" "FAILED - Cannot switch context"
        FAILED_CONTEXTS+=("$context_name")
        return 1
    fi

    echo -e "${GREEN}✓ Switched to context: $context_name${NC}"
    echo ""

    # Check connectivity
    echo "Checking context connectivity..."
    if ! check_context_connectivity "$context_name"; then
        echo -e "${RED}✗ Context unreachable: $context_name${NC}"
        set_context_result "$context_name" "FAILED - Context unreachable"
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
        set_context_result "$context_name" "SKIPPED - Image not available"
        return 0
    fi

    echo -e "${GREEN}✓ Image found: $IMAGE_TAG${NC}"
    echo ""

    # Phase 1: Setup resources
    echo -e "${BLUE}=== Phase 1: Setup Resources ===${NC}"
    echo "Creating test resources on $context_name..."

    if ! ./tests/01-setup-test-resources.sh --context "$context_name" >/dev/null 2>&1; then
        echo -e "${RED}✗ Failed to create test resources on $context_name${NC}"
        set_context_result "$context_name" "FAILED - Setup failed"
        FAILED_CONTEXTS+=("$context_name")
        return 1
    fi

    echo -e "${GREEN}✓ Test resources created${NC}"
    echo ""

    # Count before
    local BEFORE_RUNNING=$(count_running_containers "$context_name")
    local BEFORE_STOPPED=$(count_stopped_containers "$context_name")
    local BEFORE_VOLUMES=$(count_volumes "$context_name")
    local BEFORE_NETWORKS=$(count_networks "$context_name")

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
    docker_ctx "$context_name" run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        "$IMAGE_TAG" 2>&1 | tee "/tmp/remote-cleanup-$context_name.log" || container_exit_code=$?

    echo ""
    echo "Container exit code: $container_exit_code"
    echo ""

    # Phase 3: Validation
    echo -e "${BLUE}=== Phase 3: Validation ===${NC}"

    local AFTER_RUNNING=$(count_running_containers "$context_name")
    local AFTER_STOPPED=$(count_stopped_containers "$context_name")
    local AFTER_VOLUMES=$(count_volumes "$context_name")
    local AFTER_NETWORKS=$(count_networks "$context_name")

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

    ./tests/03-cleanup-test-resources.sh --context "$context_name" >/dev/null 2>&1 || true

    echo -e "${GREEN}✓ Test resources cleaned${NC}"

    # Store results
    if [ "$context_passed" = true ]; then
        set_context_result "$context_name" "PASSED"
        echo -e "${GREEN}✓ All tests passed for context: $context_name${NC}"
        return 0
    else
        set_context_result "$context_name" "FAILED - Some tests failed"
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
        # Check if specific context is active
        echo "Checking if requested context '$SPECIFIC_CONTEXT' is active..."
        if is_context_active "$SPECIFIC_CONTEXT"; then
            contexts_to_test="$SPECIFIC_CONTEXT"
            echo -e "${GREEN}✓ Context is active: $SPECIFIC_CONTEXT${NC}"
        else
            echo -e "${RED}✗ Requested context '$SPECIFIC_CONTEXT' is NOT active${NC}"
            echo ""
            echo "Searching for an alternative active context..."

            # Try to find any active context
            local active_ctx
            active_ctx=$(find_active_context "")
            if [ $? -eq 0 ] && [ -n "$active_ctx" ]; then
                contexts_to_test="$active_ctx"
                echo -e "${YELLOW}⚠ Using alternative active context: $active_ctx${NC}"
            else
                echo -e "${RED}✗ No active contexts found${NC}"
                echo ""
                echo "Available contexts:"
                docker context ls
                return 1
            fi
        fi
    elif [ -n "$CONTEXTS_LIST" ]; then
        # Filter contexts list to only active ones
        echo "Checking which contexts from list are active..."
        local requested_contexts=$(echo "$CONTEXTS_LIST" | tr ',' ' ')
        local active_contexts_found=""

        for ctx in $requested_contexts; do
            if is_context_active "$ctx"; then
                echo -e "${GREEN}✓ Active: $ctx${NC}"
                if [ -n "$active_contexts_found" ]; then
                    active_contexts_found="$active_contexts_found $ctx"
                else
                    active_contexts_found="$ctx"
                fi
            else
                echo -e "${YELLOW}⚠ Inactive (skipped): $ctx${NC}"
            fi
        done

        if [ -z "$active_contexts_found" ]; then
            echo -e "${RED}✗ None of the requested contexts are active${NC}"
            return 1
        fi

        contexts_to_test="$active_contexts_found"
        echo ""
        echo "Testing active contexts: $active_contexts_found"
    else
        # Find all active remote contexts
        echo "Searching for all active remote contexts..."
        local active_contexts
        active_contexts=$(find_all_active_contexts)
        if [ $? -eq 0 ] && [ -n "$active_contexts" ]; then
            contexts_to_test=$(echo "$active_contexts" | tr '\n' ' ')
            echo -e "${GREEN}✓ Found active contexts:${NC}"
            echo "$active_contexts" | while read -r ctx; do
                echo "  - $ctx"
            done
        else
            echo -e "${YELLOW}⚠ No active remote contexts found${NC}"
            echo ""
            echo "Available contexts:"
            docker context ls
            echo ""
            echo -e "${YELLOW}Note: Remote context tests require at least one active remote context${NC}"
            return 1
        fi
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
            local ctx_result=$(get_context_result "$ctx")
            if [ "$ctx_result" = "PASSED" ]; then
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
        local result=$(get_context_result "$ctx")
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
