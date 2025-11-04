# Design: Standardize English Language

## Overview

This change standardizes all user-facing text to English for international professional presentation. The implementation is straightforward: translate French content to English while preserving technical accuracy.

## Architecture Impact

**None**. This is purely a documentation/presentation change with no impact on:
- Code functionality
- System architecture
- Testing framework
- Build/deployment processes

## Implementation Approach

### Phase 1: Documentation Translation

**Files to modify**:
1. **README.md**
   - Translate section "NETTOYAGE COMPLET" → "COMPLETE CLEANUP"
   - Translate "Niveaux de Nettoyage" → "Cleanup Levels"
   - Translate French comments in code examples
   - Translate French bullet points and descriptions

2. **docs/TESTING.md**
   - Delete file (redundant with docs/testing-guide.md)
   - Verify docs/testing-guide.md is comprehensive

### Phase 2: Example Scripts Translation

**Files to modify**:
1. **examples/cleanup-all.sh**
   - Line 2: "Nettoyage COMPLET" → "COMPLETE cleanup"
   - Line 7: "Nettoyage COMPLET" → "COMPLETE CLEANUP"
   - Line 29: "Exécuter le nettoyage" → "Execute cleanup"
   - Line 44: "Nettoyage terminé!" → "Cleanup completed!"

2. **examples/cleanup-complete.sh**
   - Line 2: "Nettoyage COMPLET en 2 passes" → "COMPLETE cleanup in 2 passes"
   - Lines 5-6: Translate pass descriptions
   - Lines 15, 29, 48, 69: Translate echo messages

### Phase 3: Validation

**Validation steps**:
1. Grep for remaining French keywords
2. Verify technical accuracy
3. Check all links still work
4. Verify examples still match actual behavior

## Translation Guidelines

### Preserve Technical Accuracy

- Docker terminology remains unchanged (container, image, volume, network, prune)
- Command examples remain identical
- Configuration variables remain unchanged
- Technical concepts translated accurately

### Key Translations

| French | English |
|--------|---------|
| Nettoyage | Cleanup |
| Supprime | Removes/Deletes |
| Protégés | Protected |
| Conteneurs arrêtés | Stopped containers |
| Images inutilisées | Unused images |
| Volumes inutilisés | Unused volumes |
| Networks inutilisés | Unused networks |
| Conservateur | Conservative |
| Complet | Complete |
| Passe | Pass |
| Exécuter | Execute |
| Terminé | Completed |

### Style Consistency

- Use present tense for descriptions ("removes" not "will remove")
- Use imperative for commands ("Run the cleanup" not "You should run")
- Maintain existing tone and formality level
- Keep emoji usage consistent with current style

## Affected Files Summary

### Critical (User-Facing Documentation)
- `README.md` - Main project documentation (French → English translation)
- `examples/cleanup-all.sh` - Example script (French → English translation)
- `examples/cleanup-complete.sh` - Example script (French → English translation)
- `docs/TESTING.md` - Delete (redundant with docs/testing-guide.md)

### Code Quality Review (Source Files)
- `src/cleanup.sh` - Add function headers, improve comments, run shellcheck
- `src/entrypoint.sh` - Add explanatory comments, document GID logic
- `src/logger.sh` - Add function headers, document logging behavior
- `src/config_validator.sh` - Add function headers, improve error messages

### No Changes Required
- Test scripts (`tests/*.sh`) - Already in English with good quality
- `docs/testing-guide.md` - Already in English
- `docs/SECURITY.md` - Already in English
- `Dockerfile` - Already in English
- `docker-compose.yml` - Already in English

## Code Quality Review Approach

### Function Documentation Standard

All functions will follow this format:
```bash
# Function: function_name
# Purpose: Brief description of what the function does
# Parameters:
#   $1 - description of first parameter
#   $2 - description of second parameter (if applicable)
# Returns: 0 on success, 1 on failure
# Exit codes: (if applicable)
#   0 - success
#   1 - partial failure
#   2 - complete failure
# Side effects:
#   - Modifies GLOBAL_VARIABLE
#   - Writes to stderr
#   - Calls other_function()
```

### Comment Guidelines

**DO**:
- Explain WHY code exists, not WHAT it does
- Document security considerations
- Explain platform-specific behavior
- Document edge cases and limitations
- Provide context for complex logic

**DON'T**:
- Restate obvious code (`# Set x to 5`)
- Over-comment simple operations
- Leave outdated comments
- Comment self-explanatory code

### ShellCheck Integration

All scripts must pass shellcheck with:
- No SC errors (blocking)
- No SC warnings (blocking)
- Use shellcheck 0.7.0+

Common issues to fix:
- SC2086: Quote to prevent word splitting
- SC2034: Unused variables
- SC2155: Declare and assign separately
- SC2164: Use cd ... || exit

## Risk Assessment

### Risks

1. **Translation Accuracy**: Risk of losing technical nuance in translation
   - **Mitigation**: Review translations for technical accuracy, preserve Docker terminology

2. **Link Breakage**: Risk of breaking cross-references
   - **Mitigation**: Verify all links after translation

3. **Example Mismatch**: Risk of examples not matching actual behavior
   - **Mitigation**: Test examples after translation

4. **Over-Commenting**: Risk of adding too many obvious comments
   - **Mitigation**: Follow "explain why not what" guideline, review comment density

5. **Code Changes**: Risk of accidentally changing logic while adding comments
   - **Mitigation**: Only add/modify comments, no logic changes

### Risk Level: **LOW-MEDIUM**

Translation risks remain low. Code review adds minor risk of over-commenting but is easily mitigated through guidelines. No functional code changes planned.

## Testing Strategy

### Validation Tests

1. **Grep for French content**:
   ```bash
   grep -rn "nettoyage\|supprime\|exécute\|terminé" README.md examples/ docs/
   # Should return no results
   ```

2. **Verify examples work**:
   ```bash
   DRY_RUN=true ./examples/cleanup-all.sh
   DRY_RUN=true ./examples/cleanup-complete.sh
   ```

3. **Link validation**:
   - Check all markdown links resolve correctly
   - Verify section references work

4. **Technical accuracy review**:
   - Docker commands unchanged
   - Environment variables unchanged
   - Configuration options unchanged

## Rollout Plan

1. **Create branch**: `docs/standardize-english`
2. **Translate README.md**: Commit after translation
3. **Translate examples**: Commit after translation
4. **Remove docs/TESTING.md**: Commit removal
5. **Validate**: Run all validation tests
6. **PR Review**: Request review for translation accuracy
7. **Merge**: Merge to main after approval

## Rollback Plan

Simple: Git revert commits if translation issues discovered. No functional code impact means safe to revert anytime.

## Future Considerations

### Internationalization (i18n)

If future demand for French/other languages:
- Consider separate translation files (README.fr.md)
- Use standard i18n approach
- Primary docs remain English

### Contribution Guidelines

Add to CONTRIBUTING.md (when created):
- All contributions must be in English
- Comments, docs, and examples in English
- Code variable names in English
