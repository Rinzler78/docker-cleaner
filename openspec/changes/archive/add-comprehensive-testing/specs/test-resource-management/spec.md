# Specification: Test Resource Management

## Overview
Automated test resource creation and cleanup functionality that supports any Docker context (local or remote). This provides the foundation for all testing scenarios by creating predictable, labeled resources that can be safely created and cleaned up.

## ADDED Requirements

### Requirement: Context-aware resource creation
**ID**: `TRM-001`

The test resource creation script MUST support creating resources on any Docker context.

#### Scenario: Create test resources on default (local) context
```bash
# Given: Docker daemon running on local machine
# When: User runs setup script without context parameter
./tests/setup-test-resources.sh

# Then: Resources are created on local Docker daemon
# And: All resources are labeled with test-cleanup=true
# And: Script reports resource counts
```

#### Scenario: Create test resources on remote context
```bash
# Given: Docker context "remote-nas" is configured
# When: User runs setup script with context parameter
./tests/setup-test-resources.sh --context remote-nas

# Then: Resources are created on remote-nas context
# And: All resources are labeled with test-cleanup=true
# And: Script reports resource counts
# And: Original context is restored after completion
```

### Requirement: Comprehensive resource type coverage
**ID**: `TRM-002`

The resource creation script MUST create all Docker resource types that cleanup operations handle.

#### Scenario: Create running containers (to be protected)
```bash
# Given: Clean test environment
# When: Script creates running containers
# Then: At least 3 running containers are created
# And: Containers are labeled with test-cleanup=true
# And: Containers are labeled with keep=running
# And: Containers use alpine:latest for minimal footprint
# And: Containers run "sleep 3600" to stay alive during tests
```

#### Scenario: Create stopped containers (to be removed)
```bash
# Given: Clean test environment
# When: Script creates stopped containers
# Then: At least 5 stopped/created/exited containers are created
# And: Containers are labeled with test-cleanup=true
# And: Containers have no keep label (marked for removal)
```

#### Scenario: Create unused tagged images (to be removed with PRUNE_ALL)
```bash
# Given: Clean test environment
# When: Script creates unused tagged images
# Then: At least 3 tagged images are created
# And: Images are labeled with test-cleanup=true
# And: Images are not referenced by any containers
# And: Images can be built from inline Dockerfiles
```

#### Scenario: Create dangling images (to be removed always)
```bash
# Given: Clean test environment
# When: Script creates dangling images
# Then: At least 1 dangling image exists
# And: Dangling images have <none>:<none> tag
# And: Script builds and re-tags images to create dangling layers
```

#### Scenario: Create used volumes (to be protected)
```bash
# Given: Clean test environment
# When: Script creates used volumes
# Then: At least 3 volumes are created
# And: Volumes are labeled with test-cleanup=true
# And: Each volume is mounted by a running container
# And: Volumes are marked as "in use" by Docker
```

#### Scenario: Create unused volumes (to be removed with PRUNE_VOLUMES)
```bash
# Given: Clean test environment
# When: Script creates unused volumes
# Then: At least 5 unused volumes are created
# And: Volumes are labeled with test-cleanup=true
# And: Volumes are not mounted by any container
# And: Volumes are marked as "dangling" by Docker
```

#### Scenario: Create used networks (to be protected)
```bash
# Given: Clean test environment
# When: Script creates used networks
# Then: At least 3 custom networks are created
# And: Networks are labeled with test-cleanup=true
# And: Each network has at least one container attached
# And: Networks are marked as "in use" by Docker
```

#### Scenario: Create unused networks (to be removed)
```bash
# Given: Clean test environment
# When: Script creates unused networks
# Then: At least 4 unused networks are created
# And: Networks are labeled with test-cleanup=true
# And: Networks have no containers attached
# And: Networks can be safely removed
```

#### Scenario: Generate build cache (to be removed)
```bash
# Given: Clean test environment
# When: Script generates build cache
# Then: Build cache is generated via multi-stage builds
# And: Cache includes intermediate layers
# And: Script builds then removes temporary image to leave cache
# And: Cache can be detected via "docker system df"
```

### Requirement: Safe cleanup of test resources
**ID**: `TRM-003`

The test cleanup script MUST safely remove all test resources without affecting production resources.

#### Scenario: Clean up test resources by label filter
```bash
# Given: Test resources exist with label test-cleanup=true
# And: Production resources exist without this label
# When: User runs cleanup script
./tests/cleanup-test-resources.sh

# Then: All containers with test-cleanup=true are removed
# And: All images with test-cleanup=true are removed
# And: All volumes with test-cleanup=true are removed
# And: All networks with test-cleanup=true are removed
# And: Production resources remain untouched
# And: Script confirms cleanup completion
```

#### Scenario: Clean up test resources on specific context
```bash
# Given: Test resources exist on remote context
# When: User runs cleanup with context parameter
./tests/cleanup-test-resources.sh --context remote-nas

# Then: Resources on remote-nas context are cleaned
# And: Original context is restored
# And: Local resources remain untouched
```

### Requirement: Resource validation and reporting
**ID**: `TRM-004`

The resource management scripts MUST provide clear reporting of resource states.

#### Scenario: Report resources before cleanup
```bash
# Given: Test resources have been created
# When: User runs validation script
./tests/validate-cleanup.sh --before

# Then: Script reports count of running containers
# And: Script reports count of stopped containers
# And: Script reports count of images (tagged and dangling)
# And: Script reports count of volumes (used and unused)
# And: Script reports count of networks (used and unused)
# And: Script reports approximate build cache size
```

#### Scenario: Report resources after cleanup
```bash
# Given: Cleanup has been executed
# When: User runs validation script
./tests/validate-cleanup.sh --after

# Then: Script reports remaining resource counts
# And: Script highlights any unexpected remaining resources
# And: Script exits with code 0 if cleanup was complete
# And: Script exits with code 1 if cleanup was incomplete
```

## Implementation Notes
- Use consistent labeling: `test-cleanup=true` for all test resources
- Use additional labels like `test-e2e=true` or `test-unit=true` for test type isolation
- Use `keep=running` or `keep=true` labels to mark protected resources
- Support `--dry-run` flag to preview resource creation without executing
- Always restore original Docker context after remote operations
- Provide colored output for better readability (optional, can be disabled)
- Include resource count summaries after each operation
