#!/bin/bash
# 03-cleanup-test-resources.sh - Clean up all test resources created by setup-test-resources.sh

set -euo pipefail

# Parse command line arguments
TARGET_CONTEXT=""

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
        echo "Error: Context '$TARGET_CONTEXT' does not exist"
        echo "Available contexts:"
        docker context ls
        exit 1
    fi
    echo "Using Docker context: $TARGET_CONTEXT"
    echo ""
fi

echo "=== Cleaning Up Test Resources ==="
echo ""

# Show current context
current_context=$(docker_ctx context show)
echo "Cleaning resources on context: $current_context"
echo ""

# Stop and remove containers
echo "Removing test containers..."
docker_ctx rm -f $(docker_ctx ps -aq --filter label=test-cleanup=true) 2>/dev/null && echo "✓ Containers removed" || echo "No test containers found"

# Remove images
echo "Removing test images..."
docker_ctx rmi -f $(docker_ctx images -q --filter label=test-cleanup=true) 2>/dev/null && echo "✓ Labeled images removed" || echo "No labeled test images found"
docker_ctx rmi -f test-cleanup-image:v1 test-cleanup-image:labeled test-cleanup-temp:latest 2>/dev/null && echo "✓ Tagged images removed" || true

# Remove volumes
echo "Removing test volumes..."
docker_ctx volume rm $(docker_ctx volume ls -q --filter label=test-cleanup=true) 2>/dev/null && echo "✓ Volumes removed" || echo "No test volumes found"

# Remove networks
echo "Removing test networks..."
docker_ctx network rm $(docker_ctx network ls -q --filter label=test-cleanup=true) 2>/dev/null && echo "✓ Networks removed" || echo "No test networks found"

# Prune dangling images
echo "Pruning dangling images..."
docker_ctx image prune -f >/dev/null 2>&1 && echo "✓ Dangling images pruned" || true

echo ""
echo "=== Cleanup Complete ==="
