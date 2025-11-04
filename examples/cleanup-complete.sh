#!/bin/bash
# cleanup-complete.sh - Nettoyage COMPLET en 2 passes
#
# Docker vérifie l'utilisation des ressources AU MOMENT du prune.
# Une première passe supprime les conteneurs stopped et leurs ressources.
# Une deuxième passe supprime les images orphelines qui étaient référencées
# par les conteneurs supprimés lors de la première passe.

set -euo pipefail

echo "==========================================="
echo "  Docker Cleanup - 2 PASSES COMPLÈTES"
echo "==========================================="
echo ""
echo "Ce script exécute 2 nettoyages complets pour garantir"
echo "que TOUTES les ressources inutilisées sont supprimées,"
echo "y compris les images de base orphelines."
echo ""

# Option dry-run
DRY_RUN=${DRY_RUN:-false}

if [ "$DRY_RUN" = "true" ]; then
    echo "🔍 Mode DRY-RUN activé - Aucune suppression réelle"
    echo ""
fi

echo "=========================================="
echo "PASSE 1: Nettoyage initial"
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
echo "PASSE 2: Nettoyage des images orphelines"
echo "=========================================="
echo ""
echo "Les images qui étaient référencées par des conteneurs"
echo "supprimés lors de la passe 1 vont maintenant être supprimées."
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
echo "✅ Nettoyage complet terminé (2 passes)!"
echo ""
echo "Pour tester sans suppression:"
echo "  DRY_RUN=true ./cleanup-complete.sh"
