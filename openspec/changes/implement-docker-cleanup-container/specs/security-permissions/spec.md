# Spec: Security and Permissions Management

## Overview
This specification defines security requirements and permission models for the Docker cleanup container, implementing least-privilege principles for local Docker socket access and protection against unauthorized operations.

## ADDED Requirements

### Requirement: Least-Privilege Container Execution
The container MUST run with minimal privileges necessary for cleanup operations.

#### Scenario: Non-root container user
**GIVEN** the container image is built
**WHEN** the container runs
**THEN** the container process MUST NOT run as root user
**AND** MUST run as a dedicated non-root user (UID > 1000)
**AND** MUST have only necessary filesystem permissions

#### Scenario: Dropped capabilities
**GIVEN** the container starts
**WHEN** reviewing container capabilities
**THEN** all Linux capabilities MUST be dropped by default
**AND** only explicitly required capabilities MUST be added
**AND** CAP_SYS_ADMIN MUST NOT be required

#### Scenario: Read-only root filesystem
**GIVEN** the container is configured
**WHEN** the container runs
**THEN** the root filesystem SHOULD be read-only
**AND** writable paths for logs MUST be explicitly defined
**AND** temporary directories MUST use tmpfs mounts

### Requirement: Privileged Mode Not Required
The container MUST NOT require --privileged flag to access Docker socket.

#### Scenario: Validate non-privileged execution
**GIVEN** the container is deployed
**WHEN** running without --privileged flag
**THEN** the container MUST successfully access Docker socket
**AND** MUST execute all cleanup operations
**AND** MUST exit with code 0 on success

#### Scenario: Document privileged mode risks
**GIVEN** a user reviews deployment documentation
**WHEN** examining security requirements
**THEN** the documentation MUST explicitly state:
  - Privileged mode is NOT required
  - Privileged mode is strongly discouraged
  - Alternative GID matching approach is used
**AND** MUST warn about privileged mode security implications

### Requirement: Docker Socket GID Matching
The system MUST dynamically match the Docker socket's group ID to enable non-root access.

#### Scenario: Dynamic GID detection at startup
**GIVEN** the container starts with docker.sock mounted
**WHEN** the entrypoint script executes
**THEN** the system MUST:
  - Detect docker.sock GID using `stat -c '%g' /var/run/docker.sock`
  - Log the detected GID
  - Verify socket exists and is accessible
**AND** MUST exit with error code 2 if socket is not found

#### Scenario: Docker group creation with matching GID
**GIVEN** the docker.sock GID is detected
**WHEN** setting up container user permissions
**THEN** the system MUST:
  - Check if group with detected GID already exists
  - Reuse existing group if GID matches
  - Create new group "docker" with detected GID if not exists
**AND** MUST log group creation or reuse

#### Scenario: Add non-root user to docker group
**GIVEN** the docker group is configured with correct GID
**WHEN** preparing to execute cleanup operations
**THEN** the system MUST:
  - Add the non-root container user to the docker group
  - Verify group membership with `groups` command
  - Log successful group assignment
**AND** user MUST have read/write access to docker.sock

#### Scenario: Permission verification before cleanup
**GIVEN** the user has been added to docker group
**WHEN** validating Docker access
**THEN** the system MUST:
  - Execute `docker info` to verify daemon connectivity
  - Check socket file permissions with `ls -l`
  - Log successful Docker API access
**AND** MUST exit with error code 2 if Docker API is not accessible

#### Scenario: Handle GID mismatch gracefully
**GIVEN** the detected GID conflicts with existing group
**WHEN** attempting to create docker group
**THEN** the system MUST:
  - Log the GID conflict
  - Attempt to use existing group with that GID
  - Verify permissions work with existing group
**AND** MUST exit with error if permissions cannot be established

### Requirement: Docker Socket Security Safeguards
The system MUST implement security safeguards when accessing local Docker socket.

#### Scenario: Socket mount validation
**GIVEN** the container starts
**WHEN** checking for docker.sock mount
**THEN** the system MUST verify:
  - /var/run/docker.sock exists and is a socket file
  - Socket has appropriate permissions (660 or more restrictive)
  - Socket is owned by root:docker (or equivalent)
**AND** MUST log security warning if permissions are too permissive

#### Scenario: Document socket security implications
**GIVEN** a user reviews security documentation
**WHEN** reading about Docker socket access
**THEN** the documentation MUST clearly state:
  - Mounting docker.sock grants equivalent root access to host
  - Container can perform any Docker operation
  - This is required for cleanup operations
  - Mitigations: resource protection, audit logging, least privilege
**AND** MUST provide risk assessment

#### Scenario: Socket access error handling
**GIVEN** Docker socket access fails
**WHEN** attempting to connect to Docker daemon
**THEN** the system MUST:
  - Log specific error (permission denied, socket not found, etc.)
  - Provide troubleshooting guidance
  - Suggest checking volume mount and GID matching
  - Exit with error code 2
**AND** error message MUST be actionable

### Requirement: Resource Protection Mechanisms
The system MUST provide mechanisms to protect critical resources from accidental deletion.

#### Scenario: Label-based protection
**GIVEN** resources are labeled for protection
**WHEN** cleanup operations execute
**THEN** the system MUST respect label filters
**AND** MUST NOT remove resources with protected labels
**AND** MUST log skipped resources

#### Scenario: Running container protection
**GIVEN** containers are currently running
**WHEN** container prune executes
**THEN** the system MUST NOT remove running containers
**AND** MUST NOT stop containers to remove them (unless explicitly configured)

#### Scenario: Volume-in-use protection
**GIVEN** volumes are mounted by running containers
**WHEN** volume prune executes
**THEN** Docker MUST refuse to remove volumes in use
**AND** the system MUST log the refusal
**AND** MUST continue with other cleanup operations

### Requirement: Audit Trail and Logging
The system MUST provide audit capability for all cleanup operations.

#### Scenario: Operation audit logging
**GIVEN** any cleanup operation executes
**WHEN** resources are removed
**THEN** the system MUST log:
  - Timestamp of operation
  - Hostname where cleanup executes
  - Type of resource removed
  - Identifier of removed resource
  - Space freed
**AND** logs MUST be immutable and tamper-evident

#### Scenario: Docker socket access logging
**GIVEN** the container starts and accesses Docker socket
**WHEN** establishing Docker API connection
**THEN** the system MUST log:
  - Socket path and detected GID
  - Group creation/reuse decision
  - User group membership assignment
  - Docker API connectivity verification result
**AND** logs MUST include timestamps

#### Scenario: Error and security event logging
**GIVEN** security-relevant events occur
**WHEN** events like permission denied or socket access failure occur
**THEN** the system MUST log security events with:
  - Event type
  - Timestamp
  - Hostname
  - Action attempted
  - Outcome and error details
**AND** security logs MUST be at WARNING or ERROR level

### Requirement: Host Docker Group Membership (Alternative Approach)
As an alternative to GID matching, the system MUST support pre-configured docker group membership.

#### Scenario: Pre-configured user with docker group
**GIVEN** the host administrator pre-configures container user
**WHEN** deploying the container with --user flag matching host docker group
**THEN** the system SHOULD:
  - Skip GID matching if user already has docker access
  - Verify docker.sock access directly
  - Log that pre-configured permissions are used
**AND** MUST fall back to GID matching if access fails

#### Scenario: Document pre-configuration approach
**GIVEN** a user wants to avoid entrypoint GID matching
**WHEN** reviewing deployment options
**THEN** the documentation MUST describe:
  - How to create user with matching UID/GID on host
  - How to add host user to docker group
  - How to run container with --user flag
  - Trade-offs compared to dynamic GID matching
**AND** MUST provide step-by-step instructions

### Requirement: Secrets Management
The system MUST handle sensitive data securely in logging and configuration.

#### Scenario: Environment variable sanitization
**GIVEN** the container logs output
**WHEN** logging configuration or debug information
**THEN** the system MUST NOT log sensitive values
**AND** MUST sanitize or redact credentials in logs
**AND** MUST NOT expose sensitive environment variables

#### Scenario: Configuration file protection
**GIVEN** configuration files are used
**WHEN** files contain sensitive data
**THEN** files MUST have permissions 600 or more restrictive
**AND** MUST be owned by the container user
**AND** MUST NOT be world-readable

### Requirement: Security Best Practices Documentation
The system documentation MUST provide security guidance for local Docker socket access.

#### Scenario: Security setup guide
**GIVEN** a user wants to deploy the container securely
**WHEN** reviewing documentation
**THEN** the documentation MUST include:
  - Least-privilege setup instructions
  - Docker socket GID matching explanation
  - Resource protection strategies
  - Audit log review procedures
  - Host security considerations

#### Scenario: Threat model documentation
**GIVEN** a security team reviews the system
**WHEN** examining documentation
**THEN** the documentation MUST include:
  - Identified threats and attack vectors
    - Container escape via docker.sock access
    - Accidental deletion of critical resources
    - Unauthorized container deployment
  - Mitigation strategies for each threat
    - Least-privilege execution
    - Resource protection labels
    - Audit logging
  - Limitations and residual risks
    - Docker socket access = root equivalent
    - Cannot prevent all misconfigurations
  - Security assumptions and prerequisites
    - Trusted container image
    - Secure host configuration
    - Protected Docker socket

#### Scenario: Incident response guidance
**GIVEN** a security incident occurs
**WHEN** responding to unauthorized cleanup
**THEN** the documentation MUST provide:
  - How to review audit logs
  - How to identify affected resources
  - How to restore from backups if needed
  - How to prevent future incidents
**AND** MUST include log parsing examples

## Cross-References
- Related to: `docker-cleanup-automation` (protected resource handling)
- Related to: `configuration` (security-related settings)
- Related to: `testing` (security validation in tests)
