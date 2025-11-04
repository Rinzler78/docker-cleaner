# Testing Guide

## Architecture de test

Les tests valident que les **scripts source** (`src/*.sh`) fonctionnent correctement en appelant directement les scripts bash, **pas le conteneur Docker**.

### Principe

```
┌─────────────────────────────────────────────────────────┐
│  Test (tests/test-full-cleanup.sh)                      │
│                                                          │
│  1. Crée ressources avec CLI docker                     │
│     └─> docker run, docker volume create, etc.          │
│                                                          │
│  2. Appelle SCRIPTS SOURCE directement                  │
│     └─> ./src/cleanup.sh (pas le conteneur!)            │
│                                                          │
│  3. Valide que le nettoyage a fonctionné               │
│     └─> Compte les ressources restantes                 │
└─────────────────────────────────────────────────────────┘
```

### Avantages

✅ **Tests rapides** : Pas besoin de rebuilder l'image à chaque modification
✅ **Tests locaux** : Fonctionne sans Docker installé (juste les scripts bash)
✅ **Debugging facile** : Erreurs directement dans les scripts source
✅ **Compatibilité** : Testé sur bash 3.2+ (macOS default) et bash 4.0+ (Linux)

## Test end-to-end complet

### Exécution

```bash
./tests/test-full-cleanup.sh
```

### Ce que le test fait

**Phase 1 : Création des ressources**
- 3 conteneurs running (à garder)
- 8 conteneurs stopped/exited (à supprimer)
- 3 images tagged inutilisées (à supprimer)
- Images dangling (à supprimer)
- 3 volumes utilisés (à garder)
- 5 volumes inutilisés (à supprimer)
- 3 networks utilisés (à garder)
- 4 networks inutilisés (à supprimer)
- Build cache (à supprimer)

**Phase 2 : Comptage avant nettoyage**

**Phase 3 : Exécution du nettoyage**
```bash
# Le test exporte les variables d'environnement
export PRUNE_ALL=true
export PRUNE_VOLUMES=true
export CLEANUP_CONTAINERS=true
export CLEANUP_IMAGES=true
export CLEANUP_VOLUMES=true
export CLEANUP_NETWORKS=true
export CLEANUP_BUILD_CACHE=true

# Puis appelle directement le script source
./src/cleanup.sh
```

**Phase 4 : Comptage après nettoyage**

**Phase 5 : Validation (11 assertions)**
1. ✓ Tous les conteneurs stopped supprimés
2. ✓ Tous les conteneurs running conservés
3. ✓ Toutes les images inutilisées supprimées
4. ✓ Toutes les images dangling supprimées
5. ✓ Tous les volumes inutilisés supprimés
6. ✓ Tous les volumes utilisés conservés
7. ✓ Tous les networks inutilisés supprimés
8. ✓ Tous les networks utilisés conservés
9. ✓ Des conteneurs running existent
10. ✓ Des volumes utilisés existent
11. ✓ Des networks utilisés existent

**Phase 6 : Nettoyage des ressources de test**

### Résultat attendu

```
Tests exécutés: 11
Tests réussis: 11
Tests échoués: 0

╔════════════════════════════════════════╗
║                                        ║
║   ✓✓✓ TOUS LES TESTS RÉUSSIS ✓✓✓     ║
║                                        ║
║  Le nettoyage complet fonctionne      ║
║  parfaitement !                        ║
║                                        ║
╚════════════════════════════════════════╝
```

## Compatibilité bash

Les scripts sont compatibles bash 3.2+ grâce aux modifications suivantes :

### Chemins dynamiques

Au lieu de chemins hardcodés :
```bash
# Avant (ne fonctionne que dans /app/)
source /app/logger.sh
```

Maintenant avec détection automatique :
```bash
# Après (fonctionne partout)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"
```

### Arrays associatifs remplacés

Bash 3.2 ne supporte pas `declare -A`. Remplacé par des fonctions :

```bash
# Avant (bash 4.0+ seulement)
declare -A LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
)

# Après (bash 3.2+)
get_log_level_priority() {
    case "$1" in
        DEBUG) echo 0 ;;
        INFO)  echo 1 ;;
        *)     echo 1 ;;
    esac
}
```

## Tests manuels

### Test rapide sans cleanup

```bash
export DRY_RUN=true
export PRUNE_ALL=true
export PRUNE_VOLUMES=true
export CLEANUP_CONTAINERS=true
export CLEANUP_IMAGES=true
export CLEANUP_VOLUMES=true
export CLEANUP_NETWORKS=true
export CLEANUP_BUILD_CACHE=true
export LOG_LEVEL=DEBUG

./src/cleanup.sh
```

### Test avec cleanup réel

```bash
export DRY_RUN=false
export PRUNE_ALL=true
export LOG_LEVEL=INFO

./src/cleanup.sh
```

## Debugging

### Activer le mode debug bash

```bash
bash -x ./src/cleanup.sh
```

### Voir tous les logs

```bash
export LOG_LEVEL=DEBUG
./src/cleanup.sh
```

### Tester un module individuellement

```bash
# Tester le logger
source ./src/logger.sh
info "Test message"
debug "Debug message"
```

## CI/CD

Le test peut être intégré dans une pipeline CI/CD :

```yaml
# GitHub Actions
- name: Run cleanup tests
  run: |
    chmod +x tests/test-full-cleanup.sh
    chmod +x src/*.sh
    ./tests/test-full-cleanup.sh
```

## Troubleshooting

### Erreur "Permission denied"

```bash
chmod +x src/*.sh tests/*.sh
```

### Erreur "unbound variable"

Vérifier que toutes les variables requises sont exportées avant d'appeler le script.

### Test échoue sur macOS

Vérifier la version de bash :
```bash
bash --version
# Doit être 3.2+ minimum
```

Si problème avec bash 3.2, installer bash plus récent :
```bash
brew install bash
```
