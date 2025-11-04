# Spec: Docker Cleanup Automation

## Overview
This specification defines the automated Docker cleanup functionality that removes unused containers, images, volumes, networks, and build cache to reclaim disk space.

## ADDED Requirements

### Requirement: Execute Comprehensive Docker Cleanup Operations
The system MUST execute Docker prune commands to remove all types of unused Docker resources.

#### Scenario: System-wide cleanup execution
**GIVEN** the cleanup container is started
**WHEN** the cleanup operation begins
**THEN** the system MUST execute the following operations in order:
  1. Container prune to remove stopped containers
  2. Image prune to remove dangling and unused images
  3. Volume prune to remove unused volumes
  4. Network prune to remove unused networks
  5. Build cache prune to remove build cache
**AND** each operation MUST log the results including space freed

#### Scenario: Selective cleanup based on configuration
**GIVEN** the cleanup container is configured with selective operations
**WHEN** PRUNE_VOLUMES environment variable is set to false
**THEN** the system MUST skip volume pruning
**AND** MUST still execute all other configured cleanup operations

#### Scenario: Cleanup with time-based filters
**GIVEN** a time filter is configured via PRUNE_FILTER_UNTIL
**WHEN** the cleanup executes
**THEN** the system MUST only remove resources older than the specified duration
**AND** MUST preserve resources created within the filter window

### Requirement: One-Shot Execution Pattern
The container MUST execute cleanup operations and terminate automatically upon completion.

#### Scenario: Successful cleanup termination
**GIVEN** all cleanup operations complete successfully
**WHEN** the cleanup finishes
**THEN** the container MUST exit with code 0
**AND** MUST log a summary of operations performed
**AND** MUST report total disk space freed

#### Scenario: Partial failure handling
**GIVEN** some cleanup operations fail but others succeed
**WHEN** the cleanup completes
**THEN** the container MUST exit with code 1
**AND** MUST log which operations succeeded and failed
**AND** MUST report space freed by successful operations

#### Scenario: Complete failure termination
**GIVEN** the container cannot connect to Docker daemon
**WHEN** connection attempts fail
**THEN** the container MUST exit with code 2
**AND** MUST log the connection error details

### Requirement: Resource-Aware Cleanup
The system MUST preserve resources that are in use or explicitly protected.

#### Scenario: Running container protection
**GIVEN** containers are currently running
**WHEN** container prune executes
**THEN** the system MUST NOT remove running containers
**AND** MUST only remove stopped containers

#### Scenario: Image in-use protection
**GIVEN** images are associated with existing containers
**WHEN** image prune executes
**THEN** the system MUST NOT remove images used by containers
**AND** MUST only remove dangling or unused images

#### Scenario: Label-based protection
**GIVEN** PRUNE_FILTER_LABEL is set to "keep=true"
**WHEN** any prune operation executes
**THEN** the system MUST NOT remove resources with label "keep=true"
**AND** MUST only remove resources without the protection label

### Requirement: Detailed Operation Logging
The system MUST provide comprehensive logging of all cleanup operations.

#### Scenario: Operation-level logging
**GIVEN** a cleanup operation executes
**WHEN** the operation starts and completes
**THEN** the system MUST log:
  - Operation name and type
  - Number of resources removed
  - Disk space freed
  - Duration of operation
**AND** logs MUST include ISO 8601 timestamps

#### Scenario: Error logging
**GIVEN** a cleanup operation fails
**WHEN** the error occurs
**THEN** the system MUST log:
  - Operation that failed
  - Error message from Docker
  - Resource that caused the failure (if applicable)
  - Timestamp of failure
**AND** MUST continue with remaining operations

#### Scenario: Summary logging
**GIVEN** all cleanup operations complete
**WHEN** the container prepares to exit
**THEN** the system MUST log a summary including:
  - Total resources removed across all types
  - Total disk space freed
  - Total execution time
  - Count of successful and failed operations

### Requirement: Space Reclamation Verification
The system MUST accurately report disk space freed by cleanup operations.

#### Scenario: Space calculation per operation
**GIVEN** a prune operation executes
**WHEN** resources are removed
**THEN** the system MUST capture the "Space reclaimed" output from Docker
**AND** MUST convert to consistent units (GB or MB)

#### Scenario: Cumulative space reporting
**GIVEN** multiple cleanup operations execute
**WHEN** all operations complete
**THEN** the system MUST sum the space freed across all operations
**AND** MUST report total space reclaimed in summary log

## Cross-References
- Related to: `configuration` (cleanup customization)
- Related to: `security-permissions` (operation authorization and Docker socket access)
- Related to: `testing` (validation of cleanup operations)
