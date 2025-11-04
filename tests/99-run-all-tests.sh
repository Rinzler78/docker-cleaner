#!/bin/bash
# 99-run-all-tests.sh - Master test runner for docker-cleaner

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
RUN_LOCAL=true
RUN_CONTAINER=true
RUN_REMOTE=true
SKIP_LOCAL=false
SKIP_CONTAINER=false
SKIP_REMOTE=false
TEST_CONTEXT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-local)
            SKIP_LOCAL=true
            RUN_LOCAL=false
            shift
            ;;
        --skip-container)
            SKIP_CONTAINER=true
            RUN_CONTAINER=false
            shift
            ;;
        --skip-remote)
            SKIP_REMOTE=true
            RUN_REMOTE=false
            shift
            ;;
        --only-local)
            RUN_LOCAL=true
            RUN_CONTAINER=false
            RUN_REMOTE=false
            shift
            ;;
        --only-container)
            RUN_LOCAL=false
            RUN_CONTAINER=true
            RUN_REMOTE=false
            shift
            ;;
        --only-remote)
            RUN_LOCAL=false
            RUN_CONTAINER=false
            RUN_REMOTE=true
            shift
            ;;
        --context)
            TEST_CONTEXT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--skip-local] [--skip-container] [--skip-remote] [--only-local] [--only-container] [--only-remote] [--context <name>]"
            exit 1
            ;;
    esac
done

# Test results tracking
LOCAL_RESULT=""
CONTAINER_RESULT=""
REMOTE_RESULT=""

START_TIME=$(date +%s)

# Print header
print_header() {
    echo ""
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${BLUE}   Docker Cleanup - Comprehensive Test Suite${NC}"
    echo -e "${BLUE}=====================================================${NC}"
    echo ""
    echo "Test configuration:"
    echo "  Local script tests: $([ "$RUN_LOCAL" = true ] && echo "ENABLED" || echo "DISABLED")"
    echo "  Container tests: $([ "$RUN_CONTAINER" = true ] && echo "ENABLED" || echo "DISABLED")"
    echo "  Remote context tests: $([ "$RUN_REMOTE" = true ] && echo "ENABLED" || echo "DISABLED")"
    if [ -n "$TEST_CONTEXT" ]; then
        echo "  Target context: $TEST_CONTEXT"
    fi
    echo ""
    echo "Start time: $(date)"
    echo ""
}

# Run local script tests
run_local_tests() {
    echo ""
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${BLUE}   Running Local Script Tests${NC}"
    echo -e "${BLUE}=====================================================${NC}"
    echo ""

    local exit_code=0

    # Test 1: Default settings
    echo -e "${YELLOW}Test 1: Default cleanup settings${NC}"
    if [ -n "$TEST_CONTEXT" ]; then
        ./tests/11-test-local-cleanup.sh --context "$TEST_CONTEXT" || exit_code=$?
    else
        ./tests/11-test-local-cleanup.sh || exit_code=$?
    fi

    if [ $exit_code -ne 0 ]; then
        LOCAL_RESULT="FAILED"
        echo -e "${RED}✗ Local script tests FAILED${NC}"
        return 1
    fi

    echo ""

    # Test 2: Aggressive settings
    echo -e "${YELLOW}Test 2: Aggressive cleanup settings${NC}"
    if [ -n "$TEST_CONTEXT" ]; then
        ./tests/11-test-local-cleanup.sh --prune-all --prune-volumes --context "$TEST_CONTEXT" || exit_code=$?
    else
        ./tests/11-test-local-cleanup.sh --prune-all --prune-volumes || exit_code=$?
    fi

    if [ $exit_code -ne 0 ]; then
        LOCAL_RESULT="FAILED"
        echo -e "${RED}✗ Local script tests FAILED${NC}"
        return 1
    fi

    echo ""

    # Test 3: Dry-run mode
    echo -e "${YELLOW}Test 3: Dry-run mode${NC}"
    if [ -n "$TEST_CONTEXT" ]; then
        ./tests/11-test-local-cleanup.sh --dry-run --context "$TEST_CONTEXT" || exit_code=$?
    else
        ./tests/11-test-local-cleanup.sh --dry-run || exit_code=$?
    fi

    if [ $exit_code -ne 0 ]; then
        LOCAL_RESULT="FAILED"
        echo -e "${RED}✗ Local script tests FAILED${NC}"
        return 1
    fi

    LOCAL_RESULT="PASSED"
    echo -e "${GREEN}✓ Local script tests PASSED${NC}"
    return 0
}

# Run container tests
run_container_tests() {
    echo ""
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${BLUE}   Running Container Tests${NC}"
    echo -e "${BLUE}=====================================================${NC}"
    echo ""

    local exit_code=0

    if [ -n "$TEST_CONTEXT" ]; then
        ./tests/12-test-container-cleanup.sh --mode all --context "$TEST_CONTEXT" || exit_code=$?
    else
        ./tests/12-test-container-cleanup.sh --mode all || exit_code=$?
    fi

    if [ $exit_code -ne 0 ]; then
        CONTAINER_RESULT="FAILED"
        echo -e "${RED}✗ Container tests FAILED${NC}"
        return 1
    fi

    CONTAINER_RESULT="PASSED"
    echo -e "${GREEN}✓ Container tests PASSED${NC}"
    return 0
}

# Run remote context tests
run_remote_tests() {
    echo ""
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${BLUE}   Running Remote Context Tests${NC}"
    echo -e "${BLUE}=====================================================${NC}"
    echo ""

    # Check if any remote contexts exist
    local context_count=$(docker context ls --format "{{.Name}}" | wc -l | tr -d ' ')

    if [ "$context_count" -le 1 ] && [ -z "$TEST_CONTEXT" ]; then
        echo -e "${YELLOW}⚠ No remote contexts configured. Skipping remote tests.${NC}"
        echo ""
        echo "To add a remote context, use:"
        echo "  docker context create <name> --docker \"host=ssh://user@host\""
        echo ""
        REMOTE_RESULT="SKIPPED"
        return 0
    fi

    local exit_code=0

    if [ -n "$TEST_CONTEXT" ]; then
        ./tests/13-test-remote-contexts.sh --context "$TEST_CONTEXT" || exit_code=$?
    else
        ./tests/13-test-remote-contexts.sh || exit_code=$?
    fi

    if [ $exit_code -ne 0 ]; then
        REMOTE_RESULT="FAILED"
        echo -e "${RED}✗ Remote context tests FAILED${NC}"
        return 1
    fi

    REMOTE_RESULT="PASSED"
    echo -e "${GREEN}✓ Remote context tests PASSED${NC}"
    return 0
}

# Print summary
print_summary() {
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    echo ""
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${BLUE}   Comprehensive Test Suite Summary${NC}"
    echo -e "${BLUE}=====================================================${NC}"
    echo ""

    echo "Test Results:"
    echo ""

    local overall_pass=true

    if [ "$RUN_LOCAL" = true ]; then
        if [ "$LOCAL_RESULT" = "PASSED" ]; then
            echo -e "  ${GREEN}✓${NC} Local Script Tests: PASSED"
        elif [ "$LOCAL_RESULT" = "FAILED" ]; then
            echo -e "  ${RED}✗${NC} Local Script Tests: FAILED"
            overall_pass=false
        else
            echo -e "  ${YELLOW}⚠${NC} Local Script Tests: SKIPPED"
        fi
    fi

    if [ "$RUN_CONTAINER" = true ]; then
        if [ "$CONTAINER_RESULT" = "PASSED" ]; then
            echo -e "  ${GREEN}✓${NC} Container Tests: PASSED"
        elif [ "$CONTAINER_RESULT" = "FAILED" ]; then
            echo -e "  ${RED}✗${NC} Container Tests: FAILED"
            overall_pass=false
        else
            echo -e "  ${YELLOW}⚠${NC} Container Tests: SKIPPED"
        fi
    fi

    if [ "$RUN_REMOTE" = true ]; then
        if [ "$REMOTE_RESULT" = "PASSED" ]; then
            echo -e "  ${GREEN}✓${NC} Remote Context Tests: PASSED"
        elif [ "$REMOTE_RESULT" = "FAILED" ]; then
            echo -e "  ${RED}✗${NC} Remote Context Tests: FAILED"
            overall_pass=false
        elif [ "$REMOTE_RESULT" = "SKIPPED" ]; then
            echo -e "  ${YELLOW}⚠${NC} Remote Context Tests: SKIPPED (no remote contexts)"
        else
            echo -e "  ${YELLOW}⚠${NC} Remote Context Tests: SKIPPED"
        fi
    fi

    echo ""
    echo "Execution time: ${DURATION}s"
    echo "End time: $(date)"
    echo ""

    if [ "$overall_pass" = true ]; then
        echo -e "${GREEN}=====================================================${NC}"
        echo -e "${GREEN}   ✓ ALL TESTS PASSED${NC}"
        echo -e "${GREEN}=====================================================${NC}"
        return 0
    else
        echo -e "${RED}=====================================================${NC}"
        echo -e "${RED}   ✗ SOME TESTS FAILED${NC}"
        echo -e "${RED}=====================================================${NC}"
        return 1
    fi
}

# Main execution
main() {
    print_header

    local failed=false

    # Run local tests
    if [ "$RUN_LOCAL" = true ]; then
        if ! run_local_tests; then
            failed=true
        fi
    else
        LOCAL_RESULT="SKIPPED"
    fi

    # Run container tests
    if [ "$RUN_CONTAINER" = true ]; then
        if ! run_container_tests; then
            failed=true
        fi
    else
        CONTAINER_RESULT="SKIPPED"
    fi

    # Run remote tests
    if [ "$RUN_REMOTE" = true ]; then
        if ! run_remote_tests; then
            # Don't fail overall if remote tests are skipped
            if [ "$REMOTE_RESULT" != "SKIPPED" ]; then
                failed=true
            fi
        fi
    else
        REMOTE_RESULT="SKIPPED"
    fi

    # Print summary
    print_summary

    if [ "$failed" = true ]; then
        exit 1
    else
        exit 0
    fi
}

# Run main
main
