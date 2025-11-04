#!/bin/bash
# cleanup-all.sh - Nettoyage COMPLET de Docker (conteneurs, images, volumes, networks, build cache)

set -euo pipefail

echo "=========================================="
echo "  Docker Cleanup - Nettoyage COMPLET"
echo "=========================================="
echo ""
echo "Ce script va nettoyer:"
echo "  ✓ Conteneurs arrêtés"
echo "  ✓ Images inutilisées (toutes, pas seulement dangling)"
echo "  ✓ Volumes inutilisés"
echo "  ✓ Networks inutilisés"
echo "  ✓ Build cache"
echo ""
echo "⚠️  ATTENTION: Les volumes seront SUPPRIMÉS DÉFINITIVEMENT"
echo "⚠️  Les conteneurs en cours d'exécution seront PROTÉGÉS"
echo ""

# Option dry-run
DRY_RUN=${DRY_RUN:-false}

if [ "$DRY_RUN" = "true" ]; then
    echo "🔍 Mode DRY-RUN activé - Aucune suppression réelle"
    echo ""
fi

# Exécuter le nettoyage
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
echo "✅ Nettoyage terminé!"
echo ""
echo "Pour nettoyer en mode test (sans suppression):"
echo "  DRY_RUN=true ./cleanup-all.sh"
