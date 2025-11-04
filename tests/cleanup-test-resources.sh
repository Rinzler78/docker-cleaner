#!/bin/bash
# cleanup-test-resources.sh - Clean up all test resources created by setup-test-resources.sh

set -euo pipefail

# Parse command line arguments
TARGET_CONTEXT=""
ORIGINAL_CONTEXT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --context)
            TARGET_CONTEXT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--context <name>]"
            exit 1
            ;;
    esac
done

# Context management
setup_context() {
    if [ -n "$TARGET_CONTEXT" ]; then
        # Store original context
        ORIGINAL_CONTEXT=$(docker context show)
        echo "Switching from context '$ORIGINAL_CONTEXT' to '$TARGET_CONTEXT'..."

        # Validate target context exists
        if ! docker context ls --format "{{.Name}}" | grep -q "^${TARGET_CONTEXT}$"; then
            echo "Error: Context '$TARGET_CONTEXT' does not exist"
            echo "Available contexts:"
            docker context ls
            exit 1
        fi

        # Switch to target context
        docker context use "$TARGET_CONTEXT" >/dev/null 2>&1
        echo "✓ Switched to context: $TARGET_CONTEXT"
        echo ""
    fi
}

# Restore context on exit
restore_context() {
    if [ -n "$ORIGINAL_CONTEXT" ] && [ "$ORIGINAL_CONTEXT" != "$(docker context show)" ]; then
        echo ""
        echo "Restoring original context: $ORIGINAL_CONTEXT"
        docker context use "$ORIGINAL_CONTEXT" >/dev/null 2>&1
    fi
}

# Set trap for context restoration
trap restore_context EXIT

echo "=== Cleaning Up Test Resources ==="
echo ""

# Setup context if specified
setup_context

# Show current context
current_context=$(docker context show)
echo "Cleaning resources on context: $current_context"
echo ""

# Stop and remove containers
echo "Removing test containers..."
docker rm -f $(docker ps -aq --filter label=test-cleanup=true) 2>/dev/null && echo "✓ Containers removed" || echo "No test containers found"

# Remove images
echo "Removing test images..."
docker rmi -f $(docker images -q --filter label=test-cleanup=true) 2>/dev/null && echo "✓ Labeled images removed" || echo "No labeled test images found"
docker rmi -f test-cleanup-image:v1 test-cleanup-image:labeled test-cleanup-temp:latest 2>/dev/null && echo "✓ Tagged images removed" || true

# Remove volumes
echo "Removing test volumes..."
docker volume rm $(docker volume ls -q --filter label=test-cleanup=true) 2>/dev/null && echo "✓ Volumes removed" || echo "No test volumes found"

# Remove networks
echo "Removing test networks..."
docker network rm $(docker network ls -q --filter label=test-cleanup=true) 2>/dev/null && echo "✓ Networks removed" || echo "No test networks found"

# Prune dangling images
echo "Pruning dangling images..."
docker image prune -f >/dev/null 2>&1 && echo "✓ Dangling images pruned" || true

echo ""
echo "=== Cleanup Complete ==="
