# Specification: Container Cleanup Testing

## Overview
Test the docker-cleaner container by building the Docker image and executing it on the local Docker host. This validates the complete containerized deployment including Docker socket mounting, GID matching, and non-root execution.

## ADDED Requirements

### Requirement: Container build and execution testing
**ID**: `CCT-001`

Tests MUST validate that the docker-cleaner container can be built and executed correctly on the local Docker host.

#### Scenario: Build docker-cleaner image
```bash
# Given: Dockerfile and source files exist
# When: User builds the docker-cleaner image
docker build -t docker-cleaner:test .

# Then: Image builds successfully
# And: Image size is less than 50MB
# And: Image contains all required scripts
# And: Image uses docker:cli-alpine base
# And: Image creates non-root cleanup-user (UID 1000)
```

#### Scenario: Run container with default settings
```bash
# Given: docker-cleaner:test image exists
# And: Test resources exist on local Docker
# When: User runs container on local Docker
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  docker-cleaner:test

# Then: Container starts successfully
# And: Container detects Docker socket GID
# And: Container adds cleanup-user to docker group
# And: Container executes cleanup.sh as non-root user
# And: Container performs cleanup operations
# And: Container prints summary
# And: Container exits with code 0
# And: Container is automatically removed (--rm)
```

#### Scenario: Run container with environment variables
```bash
# Given: docker-cleaner:test image exists
# When: User runs container with full cleanup config
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e PRUNE_ALL=true \
  -e PRUNE_VOLUMES=true \
  -e CLEANUP_CONTAINERS=true \
  -e CLEANUP_IMAGES=true \
  -e CLEANUP_VOLUMES=true \
  -e CLEANUP_NETWORKS=true \
  -e CLEANUP_BUILD_CACHE=true \
  -e LOG_LEVEL=DEBUG \
  docker-cleaner:test

# Then: Container executes with provided configuration
# And: Container performs aggressive cleanup (all resources)
# And: Container outputs DEBUG level logs
# And: Container removes all unused resources
# And: Container protects running resources
```

#### Scenario: Run container in dry-run mode
```bash
# Given: docker-cleaner:test image exists
# When: User runs container with DRY_RUN=true
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e DRY_RUN=true \
  docker-cleaner:test

# Then: Container reports what WOULD be cleaned
# And: Container shows resource counts
# And: Container performs NO actual cleanup
# And: All test resources remain unchanged
```

### Requirement: Docker socket access validation
**ID**: `CCT-002`

Tests MUST validate that the container correctly accesses the host Docker daemon via socket mounting.

#### Scenario: Validate socket GID detection
```bash
# Given: Docker socket exists at /var/run/docker.sock
# And: Socket has specific GID (varies by system)
# When: Container starts
# Then: Entrypoint script detects socket GID
# And: Script adds cleanup-user to group with matching GID
# And: User can execute docker commands without sudo
# And: Container logs the detected GID
```

#### Scenario: Validate non-root execution
```bash
# Given: Container is running
# When: Container executes cleanup operations
# Then: Operations run as cleanup-user (UID 1000)
# And: Container does NOT run as root
# And: Container does NOT require --privileged flag
# And: Container can still access Docker daemon via GID matching
```

#### Scenario: Validate container cleans host Docker resources
```bash
# Given: Test resources exist on HOST Docker daemon
# And: docker-cleaner container is running
# When: Container executes cleanup
# Then: Container removes resources from HOST Docker
# And: Container does NOT create isolated environment
# And: Resources removed are visible on host via "docker ps -a"
# And: Space reclaimed is reflected in host "docker system df"
```

### Requirement: End-to-end container testing workflow
**ID**: `CCT-003`

An automated test script MUST orchestrate the complete containerized testing workflow.

#### Scenario: Run automated container test
```bash
# Given: Clean test environment
# When: User runs automated container test script
./tests/test-container-cleanup.sh

# Then: Script builds docker-cleaner:test image
# And: Script creates test resources on host Docker
# And: Script counts resources before cleanup
# And: Script runs docker-cleaner container with test config
# And: Script counts resources after cleanup
# And: Script validates cleanup results with assertions
# And: Script removes docker-cleaner:test image
# And: Script cleans up all test resources
# And: Script prints test pass/fail summary
# And: Script exits with code 0 if all tests pass
```

#### Scenario: Test with multiple container runs
```bash
# Given: docker-cleaner:test image exists
# When: Test runs container multiple times sequentially
# Then: Each run is idempotent
# And: First run cleans resources
# And: Second run finds nothing to clean
# And: Third run still completes successfully
# And: No errors occur on subsequent runs
```

### Requirement: Container failure handling
**ID**: `CCT-004`

Tests MUST validate container behavior on errors and edge cases.

#### Scenario: Container handles missing Docker socket
```bash
# Given: docker-cleaner:test image exists
# When: User runs container WITHOUT socket mount
docker run --rm docker-cleaner:test

# Then: Entrypoint script detects missing socket
# And: Container logs error about missing Docker socket
# And: Container exits with code 2 (configuration error)
# And: Container provides helpful error message
```

#### Scenario: Container handles inaccessible socket
```bash
# Given: Docker socket exists but has restrictive permissions
# When: Container attempts to access socket
# Then: Container detects permission error
# And: Container logs error about socket access
# And: Container provides guidance on fixing permissions
# And: Container exits with code 2
```

#### Scenario: Container handles partial operation failures
```bash
# Given: Some cleanup operations fail (e.g., locked resources)
# When: Container executes cleanup
# Then: Container continues with remaining operations
# And: Container logs which operations failed
# And: Container completes successfully-executing operations
# And: Container exits with code 1 (partial failure)
# And: Container reports operations_succeeded and operations_failed counts
```

### Requirement: Test result validation
**ID**: `CCT-005`

Tests MUST comprehensively validate that containerized cleanup works correctly.

#### Scenario: Validate container removes all stopped containers
```bash
# Given: 5 stopped containers with test-cleanup=true exist
# When: docker-cleaner container executes
# Then: All 5 stopped containers are removed
# And: Count of stopped test containers is 0 after cleanup
```

#### Scenario: Validate container removes unused images
```bash
# Given: 3 unused tagged images and dangling images exist
# And: PRUNE_ALL=true is set
# When: docker-cleaner container executes
# Then: All unused tagged images are removed
# And: All dangling images are removed
# And: Count of test images is 0 after cleanup
```

#### Scenario: Validate container removes unused volumes
```bash
# Given: 5 unused volumes with test-cleanup=true exist
# And: 3 used volumes with test-cleanup=true exist
# And: PRUNE_VOLUMES=true is set
# When: docker-cleaner container executes
# Then: All 5 unused volumes are removed
# And: All 3 used volumes remain
# And: Count of unused test volumes is 0 after cleanup
```

#### Scenario: Validate container removes unused networks
```bash
# Given: 4 unused networks with test-cleanup=true exist
# And: 3 used networks with test-cleanup=true exist
# When: docker-cleaner container executes
# Then: All 4 unused networks are removed
# And: All 3 used networks remain
# And: Count of unused test networks is 0 after cleanup
```

#### Scenario: Validate container protects running resources
```bash
# Given: 3 running containers exist
# And: Volumes are mounted by running containers
# And: Networks are used by running containers
# When: docker-cleaner container executes with aggressive settings
# Then: All running containers remain
# And: All used volumes remain
# And: All used networks remain
# And: Images used by running containers are not removed
```

## Implementation Notes
- Test script should be located at `tests/test-container-cleanup.sh`
- Build image with tag `docker-cleaner:test` to avoid conflicts
- Use `docker run --rm` to automatically remove container after execution
- Always mount `/var/run/docker.sock:/var/run/docker.sock`
- Test both default settings and custom environment configurations
- Validate exit codes: 0 (success), 1 (partial), 2 (failure)
- Capture and validate container logs
- Use assertion functions to validate resource counts
- Clean up test image after tests complete
- Implement trap handlers for cleanup on test failure
