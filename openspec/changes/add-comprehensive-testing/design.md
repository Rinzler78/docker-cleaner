# Design Document: Comprehensive Testing Architecture

## Architecture Overview

The testing architecture is designed to validate docker-cleaner functionality across three execution contexts:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Testing Architecture                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────────┐ │
│  │  Local Script  │  │  Container     │  │  Remote Context  │ │
│  │  Testing       │  │  Testing       │  │  Testing         │ │
│  └────────┬───────┘  └───────┬────────┘  └────────┬─────────┘ │
│           │                   │                     │           │
│           └───────────────────┼─────────────────────┘           │
│                               │                                 │
│                    ┌──────────▼──────────┐                      │
│                    │  Test Resource      │                      │
│                    │  Management         │                      │
│                    │  (Foundation)       │                      │
│                    └──────────┬──────────┘                      │
│                               │                                 │
│              ┌────────────────┼────────────────┐               │
│              │                │                │               │
│        ┌─────▼─────┐   ┌─────▼─────┐   ┌─────▼─────┐         │
│        │  Resource  │   │  Cleanup  │   │ Validation│         │
│        │  Creation  │   │  Scripts  │   │  Scripts  │         │
│        └────────────┘   └───────────┘   └───────────┘         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Component Design

### 1. Test Resource Management (Foundation Layer)

**Purpose**: Provide reusable resource creation, cleanup, and validation across all test types.

**Key Scripts**:
- `tests/setup-test-resources.sh`: Creates test resources
- `tests/cleanup-test-resources.sh`: Removes test resources
- `tests/validate-cleanup.sh`: Validates cleanup results

**Design Principles**:
- **Context-aware**: All scripts support `--context <name>` parameter
- **Label-based isolation**: Uses `test-cleanup=true` label for all resources
- **Safe defaults**: Never affects production resources
- **Comprehensive coverage**: Creates all Docker resource types
- **Idempotent**: Can be run multiple times safely

**Resource Types Created**:
```bash
Running Containers:   3 (with keep=running, should be protected)
Stopped Containers:   8 (5 stopped + 3 exited, should be removed)
Tagged Images:        3 (unused, should be removed with PRUNE_ALL)
Dangling Images:      ~2 (should always be removed)
Used Volumes:         3 (mounted by containers, should be protected)
Unused Volumes:       5 (should be removed with PRUNE_VOLUMES)
Used Networks:        3 (attached to containers, should be protected)
Unused Networks:      4 (should be removed)
Build Cache:          Generated (should be removed)
```

**Context Management Pattern**:
```bash
# Store original context
ORIGINAL_CONTEXT=$(docker context show)

# Switch to target context
docker context use "$TARGET_CONTEXT"

# Perform operations
# ...

# Always restore (even on failure)
trap 'docker context use "$ORIGINAL_CONTEXT"' EXIT
```

### 2. Local Script Testing Layer

**Purpose**: Test cleanup script directly in terminal (no containerization).

**Key Script**: `tests/test-local-cleanup.sh`

**Test Flow**:
```
1. Setup Phase:
   └─> Create test resources on local Docker
   └─> Count resources (before state)

2. Execution Phase:
   └─> Export configuration environment variables
   └─> Execute src/cleanup.sh directly
   └─> Capture output and exit code

3. Validation Phase:
   └─> Count resources (after state)
   └─> Assert stopped containers removed
   └─> Assert unused images/volumes/networks removed
   └─> Assert running resources protected
   └─> Assert exit code is correct

4. Cleanup Phase:
   └─> Remove all test resources
   └─> Verify clean state
```

**Configuration Test Matrix**:
- Default settings (conservative)
- Aggressive settings (PRUNE_ALL=true, PRUNE_VOLUMES=true)
- Dry-run mode (DRY_RUN=true)
- Selective operations (e.g., only containers)

**Assertion Functions**:
```bash
assert_equals()    # Expected == Actual
assert_zero()      # Value == 0
assert_not_zero()  # Value > 0
```

### 3. Container Testing Layer

**Purpose**: Test docker-cleaner Docker image on local host.

**Key Script**: `tests/test-container-cleanup.sh`

**Test Flow**:
```
1. Build Phase:
   └─> Build docker-cleaner:test image
   └─> Validate image size < 50MB
   └─> Validate image contents

2. Setup Phase:
   └─> Create test resources on local Docker
   └─> Count resources (before state)

3. Execution Phase:
   └─> Run docker-cleaner:test container
   └─> Mount /var/run/docker.sock
   └─> Pass environment configuration
   └─> Capture container logs and exit code

4. Validation Phase:
   └─> Verify container cleaned HOST resources
   └─> Count resources (after state)
   └─> Assert cleanup correctness
   └─> Validate container logs
   └─> Validate exit code

5. Cleanup Phase:
   └─> Remove test resources
   └─> Remove docker-cleaner:test image
```

**Container-Specific Validations**:
- Docker socket GID detection works correctly
- Non-root user (cleanup-user, UID 1000) execution
- No --privileged flag required
- Container affects host Docker (not isolated environment)
- Container exit codes: 0 (success), 1 (partial), 2 (error)

**Error Scenario Testing**:
- Missing Docker socket mount
- Inaccessible Docker socket
- Partial operation failures
- Invalid configuration

### 4. Remote Context Testing Layer

**Purpose**: Test docker-cleaner on remote Docker hosts via contexts.

**Key Script**: `tests/test-remote-contexts.sh`

**Multi-Context Test Flow**:
```
For each context in [default, remote-nas, remote-dev]:
  1. Context Switch:
     └─> Store original context
     └─> Switch to target context
     └─> Validate connectivity

  2. Setup Phase:
     └─> Create test resources on remote host
     └─> Count resources (before state)

  3. Execution Phase:
     └─> Run docker-cleaner container on remote
     └─> Mount remote Docker socket
     └─> Capture results

  4. Validation Phase:
     └─> Verify cleanup on remote host
     └─> Count resources (after state)
     └─> Assert cleanup correctness

  5. Cleanup Phase:
     └─> Remove test resources from remote
     └─> Restore original context

Aggregate results across all contexts
```

**Context Management Design**:
```bash
# Detect available contexts
CONTEXTS=$(docker context ls --format "{{.Name}}")

# Support specific context testing
if [ -n "$SPECIFIC_CONTEXT" ]; then
  CONTEXTS="$SPECIFIC_CONTEXT"
fi

# Test each context independently
for ctx in $CONTEXTS; do
  test_context "$ctx" || FAILED_CONTEXTS+=("$ctx")
done
```

**Remote-Specific Validations**:
- Resources created/removed on remote host, not local
- Context switching and restoration works
- Different socket GIDs on different hosts
- Missing images on remote (error handling)
- Unreachable hosts (error handling)

**Graceful Degradation**:
- If no remote contexts configured: skip with success
- If remote unreachable: log error, continue with others
- If image missing on remote: provide helpful message

## Cross-Cutting Concerns

### Labeling Strategy
All test resources use labels for isolation:
- `test-cleanup=true`: All test resources (foundation)
- `test-e2e=true`: End-to-end test resources
- `test-unit=true`: Unit test resources (future)
- `keep=running`: Protected resources (should not be removed)
- `keep=true`: Other protected resources

### Error Handling Pattern
All test scripts use consistent error handling:
```bash
set -euo pipefail  # Strict error handling

# Trap for cleanup
cleanup_on_exit() {
  local exit_code=$?
  # Restore context
  docker context use "$ORIGINAL_CONTEXT" 2>/dev/null || true
  # Clean test resources
  cleanup_test_resources
  exit $exit_code
}

trap cleanup_on_exit EXIT
```

### Output Formatting
Consistent output across all test scripts:
- **Colors**: GREEN (pass), RED (fail), YELLOW (warning), BLUE (info)
- **Prefixes**: `✓ PASS`, `✗ FAIL`, `INFO`, `TEST`
- **Summaries**: Tests passed/failed, execution time, resources cleaned

### Test Isolation
Ensure tests don't interfere with each other:
- Each test creates uniquely labeled resources
- Cleanup always uses label filters
- Tests can run in parallel (future) if labels are unique
- Dry-run mode for safe preview

## Technology Choices

### Why Bash?
- Consistency with existing codebase (all scripts are Bash)
- Native Docker CLI integration
- No additional runtime dependencies
- Portable across Linux and macOS
- Easy to understand for operations teams

### Why Not bats?
While project.md mentions bats, this design uses bash scripts because:
- Simpler setup (no dependencies)
- More flexible for Docker context switching
- Easier integration with CI/CD
- Better real-world representation of usage
- Can add bats later for unit testing individual functions

### Label-Based Resource Management
- Safe: Production resources never have test labels
- Flexible: Can filter by multiple labels
- Debuggable: Easy to find test resources manually
- Docker-native: Uses standard Docker filtering

## Future Enhancements

### Phase 2 (Future)
- Parallel context testing (execute on multiple contexts simultaneously)
- Performance benchmarking (execution time tracking)
- Test coverage metrics (which operations were tested)
- bats unit tests for individual bash functions
- Docker-in-Docker testing (full isolation)
- Chaos testing (simulate failures, race conditions)

### Phase 3 (Future)
- Integration with monitoring (Prometheus metrics validation)
- Load testing (thousands of resources)
- Security testing (socket permission validation)
- CI/CD matrix testing (multiple Docker versions)

## Success Metrics

Test suite is successful if:
- ✅ All tests pass on local system (100% pass rate)
- ✅ Container tests validate image functionality
- ✅ Remote tests work or skip gracefully
- ✅ Tests complete in < 10 minutes (excluding remote)
- ✅ Zero test resource leakage (all cleaned up)
- ✅ Clear pass/fail reporting
- ✅ Helpful error messages on failure

## Trade-offs and Decisions

### Decision: Use bash scripts instead of bats initially
**Rationale**:
- Faster to implement (leverage existing patterns)
- More flexible for Docker context operations
- Better for integration testing (bats better for unit tests)
- Can add bats later for function-level testing

**Trade-off**: Less structured test framework, but more straightforward

### Decision: Label-based resource filtering
**Rationale**:
- Safest approach (production resources protected)
- Docker-native mechanism
- Easy to understand and debug

**Trade-off**: Requires consistent labeling discipline

### Decision: Sequential context testing (not parallel)
**Rationale**:
- Simpler implementation
- Easier to debug
- Clearer output
- Each context is independent

**Trade-off**: Longer execution time, but acceptable for initial implementation

### Decision: Trap-based cleanup on failure
**Rationale**:
- Ensures cleanup even on errors
- Bash-native mechanism
- Consistent pattern across all scripts

**Trade-off**: Traps can be complex to debug, but well-documented

## Implementation Order Rationale

1. **Phase 1 (Foundation)**: Must be first - all other tests depend on it
2. **Phase 2 (Local)**: Simplest execution model - validate core logic
3. **Phase 3 (Container)**: Builds on local tests - adds containerization layer
4. **Phase 4 (Remote)**: Most complex - requires phases 1-3 working
5. **Phase 5 (Integration)**: Final polish - ties everything together

This ordering ensures each phase validates the previous one.
