# Change Proposal: Add Comprehensive Testing

## Change ID
`add-comprehensive-testing`

## Summary
Add a comprehensive testing framework to validate docker-cleaner operations across different execution contexts: local script execution, containerized execution on local Docker host, and containerized execution on remote Docker contexts. This ensures the cleanup functionality works correctly regardless of deployment method.

## Motivation
Currently, the project has basic test scripts (`test-full-cleanup.sh`, `setup-test-resources.sh`) but lacks:
1. **Structured test framework** for unit and integration testing
2. **Container-based test validation** to test the actual Docker image
3. **Multi-context testing** to validate remote Docker context support
4. **Automated test resource management** with configurable contexts
5. **Test isolation and cleanup** to prevent test pollution

## Goals
1. Enable testing the cleanup script locally in terminal
2. Enable testing the cleanup from within the docker-cleaner container (local context)
3. Enable testing the cleanup from docker-cleaner container on remote contexts
4. Provide automated test resource creation for any Docker context
5. Ensure all tests are idempotent and properly clean up after themselves

## Non-Goals
- Performance benchmarking (future work)
- Load testing with thousands of resources (future work)
- Chaos engineering / fault injection (future work)

## Dependencies
- Requires Docker daemon running on host (existing requirement)
- Requires Docker contexts configured for remote testing (optional, for remote tests only)
- Uses existing bats framework mentioned in project.md

## Risk Assessment
**Risk Level**: Low

**Risks**:
- Test resources might not be fully cleaned up on test failure
- Remote context tests require additional infrastructure setup
- Tests may interfere with existing Docker resources if labels are not properly enforced

**Mitigations**:
- Implement robust cleanup-on-failure mechanisms
- Use unique test labels (`test-cleanup=true`, `test-e2e=true`) to isolate test resources
- Provide dry-run modes for all test operations
- Clear documentation on remote context setup requirements

## Implementation Approach
1. Create structured test resource creation scripts that support any Docker context
2. Implement local script testing that calls `src/cleanup.sh` directly
3. Implement containerized testing that builds and runs the Docker image
4. Implement remote context testing using Docker context switching
5. Ensure all tests validate both cleanup success and resource protection
6. Add comprehensive test documentation

## Related Specifications
- `local-script-testing`: Testing cleanup script execution in local terminal
- `container-cleanup-testing`: Testing docker-cleaner container on local Docker
- `remote-context-testing`: Testing docker-cleaner container on remote contexts
- `test-resource-management`: Automated creation and cleanup of test resources

## Open Questions
None - the requirements are well-defined based on user request.
