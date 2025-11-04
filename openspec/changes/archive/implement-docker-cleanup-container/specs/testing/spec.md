# Spec: Testing and Validation

## Overview
This specification defines comprehensive testing requirements for the Docker cleanup container, including unit tests, integration tests, test resource creation, and validation procedures.

## ADDED Requirements

### Requirement: Unit Testing Framework Setup
The system MUST provide a unit testing framework for bash scripts with proper test isolation.

#### Scenario: bats framework installation
**GIVEN** the project requires unit testing
**WHEN** the test environment is set up
**THEN** the system MUST install bats (Bash Automated Testing System)
**AND** MUST configure bats to discover tests in tests/unit/ directory
**AND** MUST support TAP (Test Anything Protocol) output format

#### Scenario: Test helper functions
**GIVEN** tests need common utilities
**WHEN** writing unit tests
**THEN** the system MUST provide test helper functions for:
  - Mocking Docker commands
  - Capturing command output
  - Asserting exit codes
  - Comparing strings and numbers
**AND** helpers MUST be in tests/test_helper.bash

#### Scenario: Test isolation
**GIVEN** multiple tests execute
**WHEN** each test runs
**THEN** each test MUST run in isolation
**AND** MUST NOT affect other tests
**AND** MUST clean up any temporary files or state

### Requirement: Test Docker Resource Creation
The system MUST create Docker resources for testing cleanup operations.

#### Scenario: Create test containers (running)
**GIVEN** testing requires running containers
**WHEN** test setup executes
**THEN** the system MUST create at least 3 running containers with:
  - Names: test-cleanup-container-running-1, test-cleanup-container-running-2, test-cleanup-container-running-3
  - Image: alpine:latest
  - Command: sleep infinity
  - Label: test-cleanup=true
**AND** containers MUST be actually running (not stopped)

#### Scenario: Create test containers (stopped)
**GIVEN** testing requires stopped containers for pruning
**WHEN** test setup executes
**THEN** the system MUST create at least 3 stopped containers with:
  - Names: test-cleanup-container-stopped-1, test-cleanup-container-stopped-2, test-cleanup-container-stopped-3
  - Image: alpine:latest
  - State: Exited
  - Label: test-cleanup=true
**AND** containers MUST be stopped (exit code 0)

#### Scenario: Create test images (tagged)
**GIVEN** testing requires tagged images
**WHEN** test setup executes
**THEN** the system MUST create at least 2 tagged images:
  - Tags: test-cleanup-image:v1, test-cleanup-image:v2
  - Based on: alpine:latest with minimal modifications
  - Label: test-cleanup=true
**AND** images MUST be properly tagged and visible via docker images

#### Scenario: Create test images (dangling)
**GIVEN** testing requires dangling images for pruning
**WHEN** test setup executes
**THEN** the system MUST create at least 2 dangling images:
  - Method: Build image, re-tag with same name, original becomes dangling
  - Size: Small (<10MB)
  - Label: test-cleanup=true (if possible on dangling)
**AND** images MUST have <none> tag

#### Scenario: Create test volumes (used)
**GIVEN** testing requires volumes in use
**WHEN** test setup executes
**THEN** the system MUST create at least 2 volumes:
  - Names: test-cleanup-volume-used-1, test-cleanup-volume-used-2
  - Mounted by: Running test containers
  - Label: test-cleanup=true
**AND** volumes MUST be actually mounted (in use)

#### Scenario: Create test volumes (unused)
**GIVEN** testing requires unused volumes for pruning
**WHEN** test setup executes
**THEN** the system MUST create at least 2 unused volumes:
  - Names: test-cleanup-volume-unused-1, test-cleanup-volume-unused-2
  - Not mounted by any container
  - Label: test-cleanup=true
**AND** volumes MUST exist but not be in use

#### Scenario: Create test networks (used)
**GIVEN** testing requires networks in use
**WHEN** test setup executes
**THEN** the system MUST create at least 2 custom networks:
  - Names: test-cleanup-network-used-1, test-cleanup-network-used-2
  - Type: bridge
  - Connected to: Running test containers
  - Label: test-cleanup=true
**AND** networks MUST have at least one container connected

#### Scenario: Create test networks (unused)
**GIVEN** testing requires unused networks for pruning
**WHEN** test setup executes
**THEN** the system MUST create at least 2 unused networks:
  - Names: test-cleanup-network-unused-1, test-cleanup-network-unused-2
  - Type: bridge
  - No containers connected
  - Label: test-cleanup=true
**AND** networks MUST exist with zero endpoints

#### Scenario: Create build cache
**GIVEN** testing requires build cache for pruning
**WHEN** test setup executes
**THEN** the system MUST generate build cache by:
  - Building test images with multiple layers
  - Using multi-stage builds to create intermediate layers
  - Ensuring cache layers are not referenced by final images
**AND** cache MUST be visible via docker system df

### Requirement: Cleanup Operation Validation
The system MUST validate that cleanup operations work correctly on test resources.

#### Scenario: Verify stopped containers removed
**GIVEN** stopped test containers exist
**WHEN** container prune operation executes
**THEN** the system MUST verify:
  - All stopped test containers are removed
  - Running test containers still exist
  - Container count matches expectations
**AND** MUST assert space was reclaimed

#### Scenario: Verify dangling images removed
**GIVEN** dangling test images exist
**WHEN** image prune operation executes (without --all)
**THEN** the system MUST verify:
  - All dangling test images are removed
  - Tagged test images still exist
  - Image count matches expectations
**AND** MUST assert space was reclaimed

#### Scenario: Verify all unused images removed
**GIVEN** tagged but unused test images exist
**WHEN** image prune operation executes with --all flag
**THEN** the system MUST verify:
  - All unused tagged test images are removed
  - Images used by containers still exist
  - Image count matches expectations
**AND** MUST assert space was reclaimed

#### Scenario: Verify unused volumes removed
**GIVEN** unused test volumes exist
**WHEN** volume prune operation executes
**THEN** the system MUST verify:
  - All unused test volumes are removed
  - Volumes in use by containers still exist
  - Volume count matches expectations
**AND** MUST assert space was reclaimed

#### Scenario: Verify unused networks removed
**GIVEN** unused test networks exist
**WHEN** network prune operation executes
**THEN** the system MUST verify:
  - All unused test networks are removed
  - Networks with connected containers still exist
  - Built-in networks (bridge, host, none) still exist
  - Network count matches expectations
**AND** MUST assert space was reclaimed

#### Scenario: Verify build cache removed
**GIVEN** build cache exists
**WHEN** builder prune operation executes
**THEN** the system MUST verify:
  - Build cache is cleared
  - Cache size reduced to near zero
**AND** MUST assert space was reclaimed

#### Scenario: Verify protected resources NOT removed
**GIVEN** resources with protection labels exist
**WHEN** prune operations execute with label filters
**THEN** the system MUST verify:
  - Resources with protection labels still exist
  - Only unprotected resources are removed
**AND** MUST log protected resources that were skipped

### Requirement: Integration Testing Framework
The system MUST provide end-to-end integration testing of complete cleanup workflows.

#### Scenario: End-to-end cleanup execution
**GIVEN** a full set of test resources exists (containers, images, volumes, networks)
**WHEN** the cleanup container executes with default configuration
**THEN** the system MUST:
  - Execute all cleanup operations in correct sequence
  - Remove eligible resources across all types
  - Preserve protected and in-use resources
  - Exit with code 0 on success
  - Log summary of operations
**AND** final state MUST match expected resource counts

#### Scenario: Dry-run mode validation
**GIVEN** test resources exist
**WHEN** the cleanup container executes with DRY_RUN=true
**THEN** the system MUST:
  - Log what would be removed without removing
  - Show estimated space that would be freed
  - NOT modify any Docker resources
  - Exit with code 0
**AND** resource counts MUST remain unchanged

#### Scenario: Selective operation execution
**GIVEN** test resources exist
**WHEN** the cleanup container executes with only CLEANUP_CONTAINERS=true
**THEN** the system MUST:
  - Remove only stopped containers
  - NOT remove images, volumes, networks
  - Exit with code 0
**AND** only container count MUST decrease

#### Scenario: Filter application validation
**GIVEN** test resources with various ages and labels exist
**WHEN** the cleanup container executes with PRUNE_FILTER_UNTIL=24h
**THEN** the system MUST:
  - Remove only resources older than 24 hours
  - Preserve resources created within 24 hours
  - Log filtered resources
**AND** resource counts MUST reflect filter application

#### Scenario: Label-based protection validation
**GIVEN** test resources with label "keep=true" exist
**WHEN** the cleanup container executes with PRUNE_FILTER_LABEL="keep!=true"
**THEN** the system MUST:
  - Remove only resources without "keep=true" label
  - Preserve all resources with "keep=true" label
  - Log protected resources
**AND** protected resource count MUST remain unchanged

#### Scenario: Partial failure handling
**GIVEN** some cleanup operations will fail (e.g., volume in use)
**WHEN** the cleanup container executes
**THEN** the system MUST:
  - Log the failures
  - Continue with remaining operations
  - Exit with code 1 (partial failure)
  - Report successful operations
**AND** summary MUST list both successes and failures

### Requirement: Docker-in-Docker Test Environment
The system MUST support testing in isolated Docker-in-Docker environments.

#### Scenario: DinD container setup
**GIVEN** integration tests need isolation
**WHEN** setting up test environment
**THEN** the system MUST:
  - Start a Docker-in-Docker container
  - Expose Docker socket for test access
  - Use privileged mode for DinD container
  - Mount cleanup container code into DinD
**AND** DinD MUST have clean Docker state

#### Scenario: Test resource isolation
**GIVEN** tests execute in DinD
**WHEN** creating test resources
**THEN** test resources MUST:
  - Only exist within DinD environment
  - NOT affect host Docker daemon
  - Be automatically cleaned on DinD teardown
**AND** host Docker MUST remain unaffected

### Requirement: Performance Testing
The system MUST validate cleanup performance under various resource counts.

#### Scenario: Large-scale resource cleanup
**GIVEN** 100+ test resources of each type exist
**WHEN** cleanup executes
**THEN** the system MUST:
  - Complete within reasonable time (<5 minutes)
  - Handle large resource counts without errors
  - Report accurate space reclaimed
**AND** performance MUST not degrade significantly with resource count

#### Scenario: Space reclamation accuracy
**GIVEN** resources with known sizes exist
**WHEN** cleanup executes
**THEN** the system MUST:
  - Report space reclaimed per operation
  - Calculate total space reclaimed accurately
  - Match space reported by Docker commands
**AND** space calculations MUST be within 5% accuracy

### Requirement: Test Cleanup and Teardown
The system MUST clean up all test resources after test execution.

#### Scenario: Test resource cleanup after successful tests
**GIVEN** tests complete successfully
**WHEN** test teardown executes
**THEN** the system MUST:
  - Remove all test containers (running and stopped)
  - Remove all test images
  - Remove all test volumes
  - Remove all test networks
  - Remove test build cache
**AND** Docker environment MUST return to pre-test state

#### Scenario: Test resource cleanup after failed tests
**GIVEN** tests fail or are interrupted
**WHEN** test teardown executes
**THEN** the system MUST:
  - Identify and remove orphaned test resources
  - Use label-based cleanup (test-cleanup=true)
  - Log resources that could not be removed
  - Attempt forced removal if necessary
**AND** MUST NOT leave test resources behind

#### Scenario: Host resource protection during cleanup
**GIVEN** test cleanup executes
**WHEN** removing test resources
**THEN** the system MUST:
  - Only remove resources with test-cleanup=true label
  - NOT remove any host system resources
  - NOT remove user containers/images/volumes/networks
  - Verify resource labels before deletion
**AND** host resources MUST remain untouched

### Requirement: Continuous Integration Testing
The system MUST support automated testing in CI/CD pipelines.

#### Scenario: CI pipeline test execution
**GIVEN** code is pushed to repository
**WHEN** CI pipeline executes
**THEN** the CI MUST:
  - Set up Docker-in-Docker environment
  - Run unit tests with bats
  - Run integration tests with full resource creation
  - Report test results in standard format
  - Fail build on test failures
**AND** tests MUST complete within CI timeout limits

#### Scenario: Test coverage reporting
**GIVEN** tests execute in CI
**WHEN** tests complete
**THEN** the system MUST:
  - Generate code coverage report
  - Report coverage percentage
  - Identify untested code paths
  - Fail if coverage drops below threshold (80%)
**AND** coverage report MUST be published as artifact

#### Scenario: Security scanning integration
**GIVEN** Docker image is built in CI
**WHEN** security scanning executes
**THEN** the CI MUST:
  - Scan image with Trivy or similar tool
  - Report vulnerabilities by severity
  - Fail build on HIGH or CRITICAL vulnerabilities
  - Generate security report
**AND** security report MUST be published as artifact

## Cross-References
- Related to: `docker-cleanup-automation` (operations being tested)
- Related to: `security-permissions` (permission validation in tests)
- Related to: `configuration` (configuration testing)
