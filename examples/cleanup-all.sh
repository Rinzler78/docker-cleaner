#!/bin/bash
# cleanup-all.sh - COMPLETE Docker cleanup (containers, images, volumes, networks, build cache)

set -euo pipefail

echo "=========================================="
echo "  Docker Cleanup - COMPLETE CLEANUP"
echo "=========================================="
echo ""
echo "This script will clean:"
echo "  ✓ Stopped containers"
echo "  ✓ Unused images (all, not just dangling)"
echo "  ✓ Unused volumes"
echo "  ✓ Unused networks"
echo "  ✓ Build cache"
echo ""
echo "⚠️  WARNING: Volumes will be PERMANENTLY DELETED"
echo "⚠️  Running containers will be PROTECTED"
echo ""

# Dry-run option
DRY_RUN=${DRY_RUN:-false}

if [ "$DRY_RUN" = "true" ]; then
    echo "🔍 DRY-RUN mode enabled - No actual deletion"
    echo ""
fi

# Execute cleanup
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
echo "✅ Cleanup completed!"
echo ""
echo "To clean in test mode (without deletion):"
echo "  DRY_RUN=true ./cleanup-all.sh"
