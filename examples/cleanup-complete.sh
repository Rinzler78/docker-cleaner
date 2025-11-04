#!/bin/bash
# cleanup-complete.sh - COMPLETE cleanup in 2 passes
#
# Docker checks resource usage AT THE TIME of pruning.
# The first pass removes stopped containers and their resources.
# The second pass removes orphaned images that were referenced
# by containers removed during the first pass.

set -euo pipefail

echo "==========================================="
echo "  Docker Cleanup - 2 COMPLETE PASSES"
echo "==========================================="
echo ""
echo "This script executes 2 complete cleanups to ensure"
echo "that ALL unused resources are removed,"
echo "including orphaned base images."
echo ""

# Dry-run option
DRY_RUN=${DRY_RUN:-false}

if [ "$DRY_RUN" = "true" ]; then
    echo "🔍 DRY-RUN mode enabled - No actual deletion"
    echo ""
fi

echo "=========================================="
echo "PASS 1: Initial cleanup"
echo "=========================================="
echo ""

docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e PRUNE_ALL=true \
    -e PRUNE_VOLUMES=true \
    -e CLEANUP_CONTAINERS=true \
    -e CLEANUP_IMAGES=true \
    -e CLEANUP_VOLUMES=true \
    -e CLEANUP_NETWORKS=true \
    -e CLEANUP_BUILD_CACHE=true \
    -e DRY_RUN="$DRY_RUN" \
    -e LOG_LEVEL=INFO \
    docker-cleaner:latest

echo ""
echo "=========================================="
echo "PASS 2: Orphaned images cleanup"
echo "=========================================="
echo ""
echo "Images that were referenced by containers"
echo "removed in pass 1 will now be removed."
echo ""

docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e PRUNE_ALL=true \
    -e PRUNE_VOLUMES=true \
    -e CLEANUP_CONTAINERS=true \
    -e CLEANUP_IMAGES=true \
    -e CLEANUP_VOLUMES=true \
    -e CLEANUP_NETWORKS=true \
    -e CLEANUP_BUILD_CACHE=true \
    -e DRY_RUN="$DRY_RUN" \
    -e LOG_LEVEL=INFO \
    docker-cleaner:latest

echo ""
echo "✅ Complete cleanup finished (2 passes)!"
echo ""
echo "To test without deletion:"
echo "  DRY_RUN=true ./cleanup-complete.sh"
