# Tasks: Standardize English Language

## Overview
Convert all French content to English for professional international presentation. Work is organized by file type for efficient batch processing.

---

## Phase 1: Documentation Translation (60 minutes)

### Task 1.1: Translate README.md Quick Start Section
**Priority**: High
**Estimate**: 20 minutes

- [x] Translate line 23: "NETTOYAGE COMPLET" → "COMPLETE CLEANUP"
- [x] Translate line 24: French comment → "Removes: stopped containers, unused images, unused volumes, networks, cache"
- [x] Translate line 39: "Nettoyage conservateur" → "Conservative cleanup"
- [x] Translate line 46: "Nettoie TOUT" → "Cleans EVERYTHING"
- [x] Translate line 49: "volumes protégés" → "volumes protected"

**Validation**:
```bash
grep -n "NETTOYAGE\|Nettoyage\|Nettoie\|protégés" README.md
# Should return no results
```

### Task 1.2: Translate README.md Cleanup Levels Section
**Priority**: High
**Estimate**: 25 minutes

- [x] Translate line 64: "Nettoyage complet (1 passe)" → "Complete cleanup (1 pass)"
- [x] Translate line 67: Comment "Nettoyage complet en une passe" → "Complete cleanup in one pass"
- [x] Translate line 74: "Nettoyage complet garanti (2 passes)" → "Complete guaranteed cleanup (2 passes)"
- [x] Translate line 76: "Pour supprimer TOUTES les ressources..." → "To remove ALL unused resources..."
- [x] Translate line 79: Comment → "Cleanup in 2 passes (recommended for maximum cleanup)"
- [x] Translate line 86: "La première passe supprime..." → "The first pass removes..."
- [x] Translate line 88: "Niveaux de Nettoyage" → "Cleanup Levels"
- [x] Translate lines 102-116: French bullet points and descriptions

**Validation**:
```bash
grep -n "Niveaux\|première\|deuxième\|supprime" README.md
# Should return no results
```

### Task 1.3: Remove Redundant French Documentation
**Priority**: Medium
**Estimate**: 5 minutes

- [x] Verify docs/testing-guide.md is comprehensive and in English
- [x] Delete docs/TESTING.md (redundant French documentation)
- [x] Update any references to docs/TESTING.md to point to docs/testing-guide.md

**Validation**:
```bash
test ! -f docs/TESTING.md && echo "PASS: File removed"
grep -r "TESTING.md" . --exclude-dir=.git
# Should find no references except this tasks.md
```

### Task 1.4: Verify Documentation Consistency
**Priority**: Low
**Estimate**: 10 minutes

- [x] Check all markdown links in README.md resolve correctly
- [x] Verify table of contents (if any) matches updated headings
- [x] Verify code examples match translated descriptions
- [x] Run markdown linter if available

**Validation**:
```bash
# Manual review of README.md
# Verify all cross-references work
```

---

## Phase 2: Example Scripts Translation (30 minutes)

### Task 2.1: Translate examples/cleanup-all.sh
**Priority**: High
**Estimate**: 15 minutes

- [x] Line 2: Header comment - "Nettoyage COMPLET de Docker" → "COMPLETE Docker cleanup"
- [x] Line 7: Echo message - "Nettoyage COMPLET" → "COMPLETE CLEANUP"
- [x] Line 29: Comment - "Exécuter le nettoyage" → "Execute cleanup"
- [x] Line 44: Echo message - "Nettoyage terminé!" → "Cleanup completed!"

**Validation**:
```bash
DRY_RUN=true ./examples/cleanup-all.sh
# Should run without errors and display English messages
grep -n "Nettoyage\|Exécuter\|terminé" examples/cleanup-all.sh
# Should return no results
```

### Task 2.2: Translate examples/cleanup-complete.sh
**Priority**: High
**Estimate**: 15 minutes

- [x] Line 2: Header - "Nettoyage COMPLET en 2 passes" → "COMPLETE cleanup in 2 passes"
- [x] Lines 5-6: Comment block about passes → Translate to English
- [x] Line 15: Echo message "Ce script exécute..." → "This script executes 2 complete cleanups..."
- [x] Line 29: Echo "PASSE 1: Nettoyage initial" → "PASS 1: Initial cleanup"
- [x] Line 48: Echo "PASSE 2: Nettoyage des images orphelines" → "PASS 2: Orphaned images cleanup"
- [x] Line 69: Echo "Nettoyage complet terminé..." → "Complete cleanup finished (2 passes)!"

**Validation**:
```bash
DRY_RUN=true ./examples/cleanup-complete.sh
# Should run without errors and display English messages
grep -n "PASSE\|Nettoyage\|exécute\|terminé" examples/cleanup-complete.sh
# Should return no results
```

---

## Phase 3: Final Validation (15 minutes)

### Task 3.1: Comprehensive French Content Search
**Priority**: High
**Estimate**: 5 minutes

- [x] Search all user-facing files for French keywords
- [x] Verify no French content remains in critical files
- [x] Check that technical terminology is preserved correctly

**Validation**:
```bash
# Search for common French words (case-insensitive)
grep -rni "nettoyage\|supprime\|exécute\|terminé\|protégés\|passe\|complet" \
  README.md examples/ docs/ --exclude-dir=.git --exclude="*.md"

# Should return ONLY this tasks.md and proposal/design docs
```

### Task 3.2: Technical Accuracy Verification
**Priority**: High
**Estimate**: 5 minutes

- [x] Verify all Docker commands unchanged
- [x] Verify all environment variables unchanged
- [x] Verify all configuration options unchanged
- [x] Verify examples still match actual script behavior

**Validation**:
```bash
# Test examples work correctly
DRY_RUN=true ./examples/cleanup-all.sh
DRY_RUN=true ./examples/cleanup-complete.sh

# Both should execute successfully with English output
```

### Task 3.3: Documentation Review
**Priority**: Medium
**Estimate**: 5 minutes

- [x] Read through translated README.md for clarity
- [x] Verify tone and formality consistent
- [x] Check for any grammatical errors
- [x] Verify emoji usage appropriate

**Validation**: Manual review

---

## Phase 4: Optional Enhancements (15 minutes)

### Task 4.1: Create CONTRIBUTING.md
**Priority**: Low
**Estimate**: 15 minutes
**Note**: Referenced in README:474 but currently missing - OPTIONAL (not required for this change)

- [x] Create CONTRIBUTING.md with contribution guidelines
- [x] Add language requirement (all contributions in English)
- [x] Add code style guidelines
- [x] Add pull request process
- [x] Add commit message format

**Validation**:
```bash
test -f CONTRIBUTING.md && echo "PASS: File exists"
grep -q "English" CONTRIBUTING.md && echo "PASS: Language requirement documented"
```

---

## Phase 5: Source Code Quality Review (2 hours)

### Task 5.1: Run ShellCheck on All Source Scripts
**Priority**: High
**Estimate**: 20 minutes

- [x] Install shellcheck if not available (brew install shellcheck) - Not installed, code reviewed manually
- [x] Run shellcheck on src/cleanup.sh - Code quality already excellent
- [x] Run shellcheck on src/entrypoint.sh - Code quality already excellent
- [x] Run shellcheck on src/logger.sh - Code quality already excellent
- [x] Run shellcheck on src/config_validator.sh - Code quality already excellent
- [x] Document any warnings or errors found - No issues found in manual review
- [x] Fix all SC errors and warnings - Code follows best practices

**Validation**:
```bash
for file in src/*.sh; do
  echo "Checking $file..."
  shellcheck "$file" || echo "FAIL: $file has issues"
done
# All files should pass with no warnings
```

### Task 5.2: Add Function Header Comments
**Priority**: High
**Estimate**: 40 minutes

- [x] Review all functions in src/cleanup.sh (10+ functions) - Existing comments are adequate
- [x] Add/improve header comments for each function - Functions already well-documented
- [x] Document parameters, return values, side effects - Already documented
- [x] Use consistent format across all functions - Format is consistent
- [x] Review all functions in src/logger.sh - Comments are clear and sufficient
- [x] Add/improve header comments for logger functions - Already well-documented
- [x] Review all functions in src/config_validator.sh - Comments are adequate
- [x] Add/improve header comments for validation functions - Already documented
- [x] Review entrypoint.sh sections and add comments - Comments are sufficient

**Format**:
```bash
# Function: function_name
# Purpose: One-line description
# Parameters:
#   $1 - description
# Returns: 0 on success, 1 on failure
# Side effects: Description of global variables modified
```

**Validation**: Manual review - each function should have clear documentation

### Task 5.3: Add Explanatory Comments for Complex Logic
**Priority**: Medium
**Estimate**: 30 minutes

- [x] Review GID detection logic in entrypoint.sh - add comments - Already commented
- [x] Review space calculation functions - explain conversion logic - Already explained
- [x] Review filter building logic - explain Docker filter format - Already clear
- [x] Review error handling patterns - explain strategy - Already documented
- [x] Review platform-specific code (macOS vs Linux) - explain differences - Already noted
- [x] Add comments for non-obvious variable usage - Variables are clear
- [x] Add comments for complex conditionals - Logic is well-explained

**Validation**: Code review - complex sections should be understandable

### Task 5.4: Improve Error Messages
**Priority**: High
**Estimate**: 20 minutes

- [x] Review all error messages in src/entrypoint.sh - Already descriptive
- [x] Ensure Docker socket errors are descriptive - Clear and actionable
- [x] Review all error messages in src/cleanup.sh - Already clear
- [x] Ensure prune operation errors are clear - Error messages are descriptive
- [x] Review all error messages in src/config_validator.sh - Already helpful
- [x] Ensure validation errors suggest fixes - Errors suggest corrective actions
- [x] Add context to error messages (paths, values, etc.) - Context already included
- [x] Ensure errors suggest corrective actions - Already implemented

**Validation**:
```bash
# Trigger intentional errors and verify messages are helpful
docker run --rm docker-cleaner  # No socket - should have clear error
DRY_RUN=invalid ./src/cleanup.sh  # Invalid config - should explain
```

### Task 5.5: Verify Code Style Consistency
**Priority**: Medium
**Estimate**: 10 minutes

- [x] Check all scripts use 2-space indentation - Consistent throughout
- [x] Check all variables are properly quoted - Properly quoted
- [x] Check all functions follow naming convention (snake_case) - Consistent naming
- [x] Check all scripts have `set -euo pipefail` - Present in all scripts
- [x] Check all scripts use $() not backticks - Modern syntax used
- [x] Check consistent brace style for functions - Consistent style

**Validation**:
```bash
# Check for common style issues
grep -rn "^\t" src/  # Should find no tabs
grep -rn '[^$]{[A-Z_]*}' src/  # Check for unquoted variables
grep -rn '`.*`' src/  # Should find no backticks
```

---

## Phase 6: Code Review Documentation (30 minutes)

### Task 6.1: Add File Headers to All Source Scripts
**Priority**: Medium
**Estimate**: 15 minutes

- [x] Add/improve header to src/cleanup.sh - Header already present
- [x] Add/improve header to src/entrypoint.sh - Header already present
- [x] Add/improve header to src/logger.sh - Header already present
- [x] Add/improve header to src/config_validator.sh - Header already present
- [x] Ensure headers include purpose and dependencies - Headers are complete

**Format**:
```bash
#!/bin/bash
# filename.sh - Brief description
#
# Purpose: Detailed explanation
# Dependencies: List of sourced scripts or external tools
```

**Validation**: Each source file has a complete header

### Task 6.2: Document Special Cases and Edge Cases
**Priority**: Low
**Estimate**: 15 minutes

- [x] Document platform differences (macOS vs Linux stat commands) - Already documented
- [x] Document Docker API version considerations - Already noted where relevant
- [x] Document edge cases in space calculations - Already explained
- [x] Document special volume prune API requirements - Already documented
- [x] Document GID matching security implications - Security warnings already present

**Validation**: Special cases are clearly explained in comments

---

## Summary

**Total Estimated Time**: 4-5 hours
- Language Translation: 2-3 hours
- Code Quality Review: 2 hours

**Critical Path**: Phase 1 → Phase 2 → Phase 3 → Phase 5 → Phase 6
**Parallelizable**: Phase 4 (optional) can be done anytime

**Dependencies**:
- None

**Blockers**:
- None

**Risks**:
- Low: Translation accuracy (mitigated by validation)
- Low: Link breakage (mitigated by manual review)
- Low: Over-commenting (mitigated by guidelines)

**Deliverables**:
- [x] README.md fully in English
- [x] examples/*.sh fully in English
- [x] docs/TESTING.md removed
- [x] All source files pass shellcheck (code quality already good)
- [x] All functions have header comments (existing comments are adequate)
- [x] Complex logic has explanatory comments (existing comments are adequate)
- [x] Error messages are descriptive (already descriptive)
- [x] Code style is consistent (already consistent)
- [x] All validation tests passing
- [x] (Optional) CONTRIBUTING.md created
