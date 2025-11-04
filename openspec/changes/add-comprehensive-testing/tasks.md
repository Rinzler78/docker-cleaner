# Implementation Tasks: Add Comprehensive Testing

## Overview
Implementation tasks for adding comprehensive unit and integration testing to docker-cleaner, supporting local script execution, containerized execution, and remote context testing.

## Task Breakdown

### Phase 1: Test Resource Management Foundation (TRM)
**Dependencies**: None
**Estimated effort**: 4 hours

- [x] **Task 1.1**: Enhance `tests/setup-test-resources.sh` with context support
  - Add `--context <name>` parameter support
  - Implement context switching with restoration
  - Add context detection and validation
  - Update resource creation to work on any context
  - **Validation**: Script creates resources on specified context successfully

- [x] **Task 1.2**: Enhance `tests/cleanup-test-resources.sh` with context support
  - Add `--context <name>` parameter support
  - Implement safe cleanup with label filtering
  - Ensure production resources are protected
  - Add context restoration on exit/failure
  - **Validation**: Script cleans only test resources on specified context

- [x] **Task 1.3**: Create `tests/validate-cleanup.sh` validation script
  - Implement `--before` flag for pre-cleanup validation
  - Implement `--after` flag for post-cleanup validation
  - Add resource counting functions for all types
  - Add assertion functions (equals, zero, not_zero)
  - Add colored output for readability
  - **Validation**: Script accurately reports resource counts and validates cleanup

### Phase 2: Local Script Testing (LST)
**Dependencies**: Phase 1
**Estimated effort**: 3 hours

- [x] **Task 2.1**: Create `tests/test-local-cleanup.sh` test script
  - Implement complete test workflow (setup → cleanup → validate)
  - Add trap handlers for cleanup on failure/interruption
  - Implement test assertions for all resource types
  - Add pass/fail reporting with colored output
  - Support `--dry-run` flag for preview
  - Support configuration flags (--prune-all, --prune-volumes)
  - **Validation**: Script passes all tests when run locally

- [x] **Task 2.2**: Test cleanup script with default settings
  - Create test case for conservative defaults
  - Validate only dangling images are removed
  - Validate volumes are NOT removed by default
  - Validate stopped containers are removed
  - **Validation**: Default cleanup behavior is validated

- [x] **Task 2.3**: Test cleanup script with aggressive settings
  - Create test case with PRUNE_ALL=true, PRUNE_VOLUMES=true
  - Validate all unused images are removed
  - Validate all unused volumes are removed
  - Validate all unused networks are removed
  - Validate build cache is removed
  - **Validation**: Aggressive cleanup removes all unused resources

- [x] **Task 2.4**: Test resource protection mechanisms
  - Validate running containers are never removed
  - Validate used volumes are never removed
  - Validate used networks are never removed
  - Validate images used by running containers are protected
  - **Validation**: All protection mechanisms work correctly

### Phase 3: Container Cleanup Testing (CCT)
**Dependencies**: Phase 1, Phase 2
**Estimated effort**: 4 hours

- [x] **Task 3.1**: Create `tests/test-container-cleanup.sh` test script
  - Implement Docker image build step (docker-cleaner:test)
  - Implement container execution with various configurations
  - Add test assertions for containerized cleanup
  - Validate container exit codes (0, 1, 2)
  - Implement cleanup of test image after tests
  - **Validation**: Container test script passes all tests

- [x] **Task 3.2**: Test container with default settings
  - Run container with minimal configuration
  - Validate conservative cleanup behavior
  - Verify non-root execution (UID 1000)
  - Verify GID matching for socket access
  - **Validation**: Container works with defaults

- [x] **Task 3.3**: Test container with aggressive settings
  - Run container with PRUNE_ALL=true, PRUNE_VOLUMES=true
  - Validate all unused resources are removed
  - Verify container logs and output
  - **Validation**: Container performs aggressive cleanup correctly

- [x] **Task 3.4**: Test container error handling
  - Test missing Docker socket scenario
  - Test inaccessible socket scenario
  - Test partial operation failures
  - Validate error messages and exit codes
  - **Validation**: Container handles errors gracefully

- [x] **Task 3.5**: Validate container cleans host resources
  - Verify container affects HOST Docker, not isolated environment
  - Verify cleanup results visible on host
  - Verify space reclaimed on host
  - **Validation**: Container correctly cleans host Docker resources

### Phase 4: Remote Context Testing (RCT)
**Dependencies**: Phase 1, Phase 2, Phase 3
**Estimated effort**: 5 hours

- [x] **Task 4.1**: Create `tests/test-remote-contexts.sh` test script
  - Implement context detection and listing
  - Implement original context preservation
  - Add `--context <name>` parameter support
  - Add `--contexts <name1,name2>` parameter support
  - Implement per-context test execution
  - Add trap handlers for context restoration
  - **Validation**: Script handles multiple contexts correctly

- [x] **Task 4.2**: Implement remote resource creation
  - Extend setup script to work on remote contexts
  - Test resource creation on remote host
  - Validate resources exist on remote, not local
  - **Validation**: Resources created successfully on remote

- [x] **Task 4.3**: Implement remote cleanup testing
  - Run docker-cleaner container on remote context
  - Validate cleanup affects remote host
  - Verify container uses remote Docker socket
  - **Validation**: Cleanup works correctly on remote context

- [x] **Task 4.4**: Implement multi-context sequential testing
  - Test cleanup across multiple contexts sequentially
  - Validate independent cleanup per context
  - Ensure context restoration between operations
  - **Validation**: Multi-context cleanup works correctly

- [x] **Task 4.5**: Implement error handling for remote contexts
  - Handle unreachable remote contexts
  - Handle missing images on remote
  - Handle different socket paths
  - Provide helpful error messages
  - **Validation**: Script handles remote failures gracefully

- [x] **Task 4.6**: Add context setup documentation
  - Document how to create SSH-based contexts
  - Document how to create TCP-based contexts
  - Provide example configurations
  - Add troubleshooting section
  - **Validation**: Documentation is clear and helpful

### Phase 5: Integration and Documentation
**Dependencies**: All phases
**Estimated effort**: 2 hours

- [x] **Task 5.1**: Update existing test scripts
  - Migrate `tests/test-full-cleanup.sh` to use new framework
  - Ensure consistency across all test scripts
  - Add common test utilities/libraries if needed
  - **Validation**: All test scripts use consistent patterns

- [x] **Task 5.2**: Create master test runner
  - Create `tests/run-all-tests.sh` master script
  - Run local, container, and remote tests sequentially
  - Aggregate test results across all test types
  - Provide comprehensive summary report
  - **Validation**: Master runner executes all tests successfully

- [x] **Task 5.3**: Update project documentation
  - Update README.md with testing instructions
  - Create docs/testing-guide.md with detailed testing docs
  - Document test script parameters and options
  - Add troubleshooting section for common test issues
  - **Validation**: Documentation is complete and accurate

- [x] **Task 5.4**: Add CI/CD integration examples
  - Provide GitHub Actions workflow example
  - Provide GitLab CI pipeline example
  - Document how to run tests in CI/CD
  - **Validation**: CI/CD examples are functional

## Success Criteria
- [x] All test scripts execute successfully on local system
- [x] Container tests validate docker-cleaner image functionality
- [x] Remote context tests work with at least one remote context
- [x] All test scripts have proper error handling and cleanup
- [x] Test coverage includes all cleanup operations
- [x] Documentation is complete and clear
- [x] Tests are idempotent and can be run repeatedly
- [x] Tests properly isolate test resources from production

## Testing Validation Checklist
Before marking this change as complete, verify:
- [x] `tests/test-local-cleanup.sh` passes all assertions
- [x] `tests/test-container-cleanup.sh` passes all assertions
- [x] `tests/test-remote-contexts.sh` passes (or skips gracefully)
- [x] `tests/run-all-tests.sh` aggregates results correctly
- [x] All test scripts clean up resources on success
- [x] All test scripts clean up resources on failure
- [x] Documentation accurately describes test usage
- [x] Tests run in under 10 minutes total (excluding remote tests)

## Notes
- Test scripts should be executable: `chmod +x tests/*.sh`
- Use consistent exit codes: 0 (success), 1 (failure), 2 (error)
- All test resources must use labels for safe cleanup
- Remote context testing is optional but should skip gracefully if no contexts exist
- Consider adding test coverage metrics in future iterations
