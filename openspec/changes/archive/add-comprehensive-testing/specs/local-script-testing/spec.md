# Specification: Local Script Testing

## Overview
Test the cleanup script (`src/cleanup.sh`) by executing it directly in a local terminal environment. This validates the core cleanup logic independently of containerization.

## ADDED Requirements

### Requirement: Direct script execution testing
**ID**: `LST-001`

Tests MUST validate cleanup script execution directly in the terminal without Docker containerization.

#### Scenario: Execute cleanup script locally with default settings
```bash
# Given: Test resources exist on local Docker
# And: src/cleanup.sh is executable
# When: User executes cleanup script directly
./src/cleanup.sh

# Then: Script sources dependencies correctly (logger.sh, config_validator.sh)
# And: Script validates configuration
# And: Script executes all enabled cleanup operations
# And: Script prints summary with space reclaimed
# And: Script exits with code 0 on success
```

#### Scenario: Execute cleanup script with environment variables
```bash
# Given: Test resources exist on local Docker
# When: User executes with full cleanup configuration
export PRUNE_ALL=true
export PRUNE_VOLUMES=true
export CLEANUP_CONTAINERS=true
export CLEANUP_IMAGES=true
export CLEANUP_VOLUMES=true
export CLEANUP_NETWORKS=true
export CLEANUP_BUILD_CACHE=true
export DRY_RUN=false
./src/cleanup.sh

# Then: Script removes ALL unused resources per configuration
# And: Stopped containers are removed
# And: All unused images are removed (not just dangling)
# And: Unused volumes are removed
# And: Unused networks are removed
# And: Build cache is removed
# And: Running containers remain protected
# And: Used volumes remain protected
# And: Used networks remain protected
```

#### Scenario: Execute cleanup script in dry-run mode
```bash
# Given: Test resources exist on local Docker
# When: User executes with DRY_RUN=true
export DRY_RUN=true
./src/cleanup.sh

# Then: Script reports what WOULD be cleaned
# And: Script shows approximate resource counts
# And: Script shows estimated space to reclaim
# And: No actual cleanup operations are performed
# And: All resources remain unchanged
# And: Script exits with code 0
```

### Requirement: End-to-end cleanup validation
**ID**: `LST-002`

Tests MUST validate that cleanup operations correctly remove unused resources and protect used resources.

#### Scenario: Validate complete cleanup workflow
```bash
# Given: Clean environment
# When: Test creates resources via setup-test-resources.sh
# And: Test counts resources before cleanup
# And: Test executes cleanup script with full settings
# And: Test counts resources after cleanup
# Then: All stopped containers are removed
# And: All unused images are removed (when PRUNE_ALL=true)
# And: All dangling images are removed
# And: All unused volumes are removed (when PRUNE_VOLUMES=true)
# And: All unused networks are removed
# And: All running containers remain
# And: All used volumes remain
# And: All used networks remain
# And: Resource counts match expected values
```

#### Scenario: Validate protected resource preservation
```bash
# Given: Test resources with keep=running labels
# And: Containers using volumes and networks
# When: Cleanup script executes
# Then: Running containers are never removed
# And: Volumes mounted by containers are never removed
# And: Networks used by containers are never removed
# And: alpine:latest image (used by running containers) is not removed
# And: Default Docker networks (bridge, host, none) are never removed
```

### Requirement: Automated test execution
**ID**: `LST-003`

An automated test script MUST orchestrate the complete local testing workflow.

#### Scenario: Run automated end-to-end test
```bash
# Given: Clean test environment
# When: User runs automated test script
./tests/test-local-cleanup.sh

# Then: Script creates test resources automatically
# And: Script counts resources before cleanup
# And: Script executes src/cleanup.sh with test configuration
# And: Script counts resources after cleanup
# And: Script validates cleanup results with assertions
# And: Script cleans up all test resources
# And: Script prints test pass/fail summary
# And: Script exits with code 0 if all tests pass
# And: Script exits with code 1 if any test fails
```

#### Scenario: Run automated test with custom configuration
```bash
# Given: Clean test environment
# When: User runs test with custom settings
./tests/test-local-cleanup.sh --prune-all --prune-volumes

# Then: Test uses PRUNE_ALL=true configuration
# And: Test uses PRUNE_VOLUMES=true configuration
# And: Test validates aggressive cleanup behavior
# And: Test ensures all unused resources are removed
```

### Requirement: Test isolation and cleanup
**ID**: `LST-004`

Tests MUST be isolated and clean up after themselves, even on failure.

#### Scenario: Clean up test resources on success
```bash
# Given: Test has completed successfully
# When: Test finishes
# Then: All test resources are automatically removed
# And: Script reports cleanup completion
# And: No test resources remain on the system
```

#### Scenario: Clean up test resources on failure
```bash
# Given: Test encounters an error during execution
# When: Test exits (failure or interruption)
# Then: Cleanup trap handler executes
# And: All test resources are removed
# And: Script reports cleanup despite failure
# And: Script exits with appropriate error code
```

#### Scenario: Manual cleanup of test resources
```bash
# Given: Tests were interrupted or failed to clean up
# When: User manually runs cleanup script
./tests/cleanup-test-resources.sh

# Then: All resources with test-cleanup=true are removed
# And: Script confirms successful cleanup
# And: System returns to clean state
```

## Implementation Notes
- Test script should be located at `tests/test-local-cleanup.sh`
- Use `set -euo pipefail` for strict error handling
- Implement trap handlers for cleanup on exit/interrupt
- Use colored output for test results (pass/fail)
- Include assertion functions: `assert_equals`, `assert_zero`, `assert_not_zero`
- Support `--dry-run` flag for test script itself
- Log all test operations for debugging
- Provide detailed failure messages with expected vs actual values
