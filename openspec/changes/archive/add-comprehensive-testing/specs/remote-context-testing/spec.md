# Specification: Remote Context Testing

## Overview
Test the docker-cleaner container by deploying it to remote Docker hosts using Docker contexts. This validates that the cleanup functionality works correctly across different hosts, including NAS devices, remote servers, and cloud instances.

## ADDED Requirements

### Requirement: Docker context management
**ID**: `RCT-001`

Tests MUST support executing cleanup on any configured Docker context.

#### Scenario: List available Docker contexts
```bash
# Given: Docker CLI is installed
# When: Test lists available contexts
docker context ls

# Then: Script displays all configured contexts
# And: Script shows which context is currently active
# And: Script provides context information (name, endpoint, description)
```

#### Scenario: Switch to remote context
```bash
# Given: Context "remote-nas" is configured
# And: Current context is "default"
# When: Test switches to remote context
docker context use remote-nas

# Then: Active context becomes "remote-nas"
# And: Subsequent docker commands target remote host
# And: Test can verify with "docker context show"
```

#### Scenario: Restore original context after test
```bash
# Given: Test started with "default" context
# And: Test switched to "remote-nas" for testing
# When: Test completes or fails
# Then: Context is restored to "default"
# And: Subsequent commands target original host
# And: Context restoration happens even on test failure
```

### Requirement: Remote resource creation
**ID**: `RCT-002`

Tests MUST be able to create test resources on any remote Docker context.

#### Scenario: Create test resources on remote context
```bash
# Given: Docker context "remote-nas" is configured and accessible
# When: Test creates resources on remote context
./tests/setup-test-resources.sh --context remote-nas

# Then: Script switches to remote-nas context
# And: Script creates all resource types on remote host
# And: Script labels resources with test-cleanup=true
# And: Script reports resource counts
# And: Script restores original context
# And: Resources exist on remote host, not local host
```

#### Scenario: Validate remote resource creation
```bash
# Given: Resources were created on remote-nas context
# When: Test validates resource creation
docker context use remote-nas
docker ps -a --filter label=test-cleanup=true
docker images --filter label=test-cleanup=true
docker volume ls --filter label=test-cleanup=true
docker network ls --filter label=test-cleanup=true

# Then: All expected resources exist on remote host
# And: Resource counts match creation script output
# And: Resources have correct labels
```

### Requirement: Remote container cleanup testing
**ID**: `RCT-003`

Tests MUST validate that docker-cleaner container executes correctly on remote contexts.

#### Scenario: Run docker-cleaner on remote context
```bash
# Given: Test resources exist on remote-nas context
# And: docker-cleaner image is available on remote host
# When: Test runs cleanup container on remote context
docker context use remote-nas
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e PRUNE_ALL=true \
  -e PRUNE_VOLUMES=true \
  docker-cleaner:test

# Then: Container runs on remote host
# And: Container mounts remote host's Docker socket
# And: Container cleans remote host's Docker resources
# And: Container detects remote host's socket GID
# And: Container completes successfully
# And: Original context is restored
```

#### Scenario: Validate cleanup on remote context
```bash
# Given: docker-cleaner executed on remote-nas context
# When: Test validates cleanup results
docker context use remote-nas
# Count remaining test resources

# Then: All stopped containers are removed from remote host
# And: All unused images are removed from remote host
# And: All unused volumes are removed from remote host
# And: All unused networks are removed from remote host
# And: Running containers on remote host remain protected
# And: Used resources on remote host remain protected
```

### Requirement: Multi-context testing workflow
**ID**: `RCT-004`

Tests MUST support parallel or sequential cleanup across multiple remote contexts.

#### Scenario: Sequential cleanup across multiple contexts
```bash
# Given: Contexts "default", "remote-nas", "remote-dev" are configured
# And: Test resources exist on all contexts
# When: Test runs sequential cleanup
for ctx in default remote-nas remote-dev; do
  docker context use $ctx
  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e PRUNE_ALL=true \
    docker-cleaner:test
done
docker context use default

# Then: Cleanup executes on each context sequentially
# And: Each context's resources are cleaned independently
# And: Original context (default) is restored at end
# And: Test reports results for each context
```

#### Scenario: Automated multi-context test script
```bash
# Given: Multiple contexts are configured
# When: User runs multi-context test script
./tests/test-remote-contexts.sh --contexts "default,remote-nas,remote-dev"

# Then: Script creates resources on each context
# And: Script counts resources on each context
# And: Script runs cleanup on each context
# And: Script validates cleanup on each context
# And: Script cleans up test resources on each context
# And: Script reports per-context test results
# And: Script reports aggregate test summary
# And: Script restores original context
```

### Requirement: Remote context edge cases
**ID**: `RCT-005`

Tests MUST handle edge cases and failures when working with remote contexts.

#### Scenario: Handle unreachable remote context
```bash
# Given: Context "remote-nas" is configured but host is unreachable
# When: Test attempts to use unreachable context
docker context use remote-nas
# Try to run cleanup

# Then: Docker CLI reports connection error
# And: Test logs the error
# And: Test marks this context as failed
# And: Test continues with other contexts
# And: Test restores original context
# And: Test exits with partial failure code
```

#### Scenario: Handle missing Docker image on remote
```bash
# Given: Remote context is accessible
# And: docker-cleaner image does NOT exist on remote host
# When: Test attempts to run container
docker context use remote-nas
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner:test

# Then: Docker CLI reports image not found
# And: Test detects missing image error
# And: Test provides guidance: build or push image to remote
# And: Test marks this context as skipped
# And: Test restores original context
```

#### Scenario: Handle different Docker socket paths
```bash
# Given: Remote host uses non-standard socket path
# And: Context metadata includes custom socket path
# When: Test runs cleanup on this context
# Then: Test uses correct socket path from context config
# And: Container mounts correct socket path
# And: Cleanup succeeds with custom socket
```

### Requirement: Automated remote context testing
**ID**: `RCT-006`

An automated test script MUST orchestrate the complete remote context testing workflow.

#### Scenario: Run automated remote context test
```bash
# Given: At least one remote context is configured
# When: User runs automated remote test script
./tests/test-remote-contexts.sh

# Then: Script detects available contexts
# And: Script creates resources on each context
# And: Script counts resources before cleanup
# And: Script runs docker-cleaner on each context
# And: Script counts resources after cleanup
# And: Script validates cleanup on each context
# And: Script cleans up test resources on each context
# And: Script prints per-context results
# And: Script prints aggregate summary
# And: Script restores original context
# And: Script exits with code 0 if all contexts pass
# And: Script exits with code 1 if any context fails
```

#### Scenario: Run test on specific remote context only
```bash
# Given: Multiple contexts exist
# When: User runs test for specific context
./tests/test-remote-contexts.sh --context remote-nas

# Then: Test executes only on remote-nas context
# And: Other contexts are not affected
# And: Test creates resources only on remote-nas
# And: Test validates cleanup only on remote-nas
# And: Test cleans up only remote-nas resources
```

#### Scenario: Skip remote tests if no contexts configured
```bash
# Given: Only "default" (local) context exists
# And: No remote contexts are configured
# When: User runs remote context test script
./tests/test-remote-contexts.sh

# Then: Script detects no remote contexts
# And: Script logs "No remote contexts found, skipping"
# And: Script exits with code 0 (success/skip)
# And: Script does NOT fail due to missing contexts
```

## Implementation Notes
- Test script should be located at `tests/test-remote-contexts.sh`
- Always store original context and restore it using trap handlers
- Use `docker context show` to get current context
- Use `docker context ls --format "{{.Name}}"` to list contexts
- Filter out "default" context when listing remotes (optional)
- Support `--context <name>` flag to test specific context
- Support `--contexts <name1,name2>` flag for multiple contexts
- Provide clear error messages for unreachable contexts
- Log which context is being tested at each step
- Include assertion functions per context
- Support `--dry-run` flag to preview operations
- Consider parallel execution for independent contexts (future enhancement)

## Context Setup Documentation
The test script should provide guidance on setting up Docker contexts:

```bash
# Example: Create SSH-based remote context
docker context create remote-nas \
  --docker "host=ssh://user@nas.local"

# Example: Create TCP-based remote context
docker context create remote-dev \
  --docker "host=tcp://dev-server:2376" \
  --tls \
  --tlscert=/path/to/cert.pem \
  --tlskey=/path/to/key.pem

# Verify context
docker context use remote-nas
docker info
docker context use default
```
