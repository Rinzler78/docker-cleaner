# Spec: Configuration and Customization

## Overview
This specification defines the configuration system for the Docker cleanup container, enabling users to customize cleanup behavior, filters, and execution parameters.

## ADDED Requirements

### Requirement: Environment Variable Configuration
The system MUST support configuration via environment variables for Docker-native deployment.

#### Scenario: Docker host configuration
**GIVEN** the container is deployed
**WHEN** DOCKER_HOST environment variable is set
**THEN** the system MUST use the specified Docker host
**AND** MUST support formats: unix:///var/run/docker.sock (default), tcp://host:port (advanced use)

#### Scenario: Prune behavior configuration
**GIVEN** cleanup behavior needs customization
**WHEN** environment variables are set
**THEN** the system MUST support:
  - PRUNE_ALL (boolean): Remove all unused images, not just dangling
  - PRUNE_VOLUMES (boolean): Include volumes in cleanup
  - PRUNE_FORCE (boolean): Skip confirmation prompts
**AND** default values MUST be: PRUNE_ALL=false, PRUNE_VOLUMES=false, PRUNE_FORCE=true

#### Scenario: Filter configuration
**GIVEN** time-based or label-based filtering is needed
**WHEN** filter environment variables are set
**THEN** the system MUST support:
  - PRUNE_FILTER_UNTIL (duration): Remove resources older than duration (e.g., "24h", "7d")
  - PRUNE_FILTER_LABEL (string): Filter by label (e.g., "keep!=true")
**AND** filters MUST be applied to all prune operations

### Requirement: Selective Operation Control
The system MUST allow users to enable or disable specific cleanup operations.

#### Scenario: Individual operation toggles
**GIVEN** selective cleanup is desired
**WHEN** operation-specific environment variables are set
**THEN** the system MUST support:
  - CLEANUP_CONTAINERS (boolean, default: true)
  - CLEANUP_IMAGES (boolean, default: true)
  - CLEANUP_VOLUMES (boolean, default: false)
  - CLEANUP_NETWORKS (boolean, default: true)
  - CLEANUP_BUILD_CACHE (boolean, default: true)
**AND** disabled operations MUST be skipped entirely

#### Scenario: System prune vs individual operations
**GIVEN** both system prune and individual operations are configured
**WHEN** the container executes
**THEN** the system MUST execute individual operations if any are explicitly enabled
**AND** MUST execute system prune only if no individual operations are configured

### Requirement: Logging Configuration
The system MUST provide configurable logging levels and formats.

#### Scenario: Log level configuration
**GIVEN** log verbosity needs adjustment
**WHEN** LOG_LEVEL environment variable is set
**THEN** the system MUST support levels: DEBUG, INFO, WARN, ERROR
**AND** default level MUST be INFO
**AND** MUST filter log output based on configured level

#### Scenario: Log format configuration
**GIVEN** log format needs customization
**WHEN** LOG_FORMAT environment variable is set
**THEN** the system MUST support formats:
  - "text": Human-readable text format (default)
  - "json": Structured JSON format for log aggregation
**AND** MUST include timestamp, level, and message in both formats

#### Scenario: Quiet mode
**GIVEN** minimal output is desired
**WHEN** QUIET environment variable is set to true
**THEN** the system MUST output only errors and final summary
**AND** MUST suppress INFO and DEBUG messages

### Requirement: Dry-Run Mode
The system MUST support dry-run mode for previewing cleanup operations without actual deletion.

#### Scenario: Dry-run execution
**GIVEN** DRY_RUN environment variable is set to true
**WHEN** cleanup operations execute
**THEN** the system MUST:
  - Log what would be removed without removing
  - Show estimated space that would be freed
  - Execute "docker system df" to show current usage
**AND** MUST NOT modify any Docker resources

#### Scenario: Dry-run output format
**GIVEN** dry-run mode is enabled
**WHEN** logging preview results
**THEN** the system MUST clearly indicate "DRY RUN" in all output
**AND** MUST use conditional language ("would remove" instead of "removed")

### Requirement: Configuration Validation
The system MUST validate configuration at startup and provide clear error messages.

#### Scenario: Invalid environment variable values
**GIVEN** invalid configuration is provided
**WHEN** the container starts
**THEN** the system MUST validate all environment variables
**AND** MUST exit with error code 2 if validation fails
**AND** MUST log specific validation errors with corrective guidance

#### Scenario: Conflicting configuration detection
**GIVEN** conflicting settings are provided
**WHEN** validating configuration
**THEN** the system MUST detect conflicts like:
  - DRY_RUN=true with PRUNE_FORCE=true
  - DOCKER_HOST not set and no local socket available
**AND** MUST log warnings or errors for conflicts

#### Scenario: Configuration summary logging
**GIVEN** the container starts successfully
**WHEN** configuration is validated
**THEN** the system MUST log effective configuration including:
  - Docker host target (local or remote)
  - Enabled cleanup operations
  - Active filters
  - Logging level
**AND** MUST redact any sensitive values if present

### Requirement: Default Configuration Safety
The system MUST have safe defaults that protect critical resources.

#### Scenario: Conservative defaults
**GIVEN** no configuration is provided
**WHEN** the container starts with defaults
**THEN** the default configuration MUST:
  - NOT remove volumes (PRUNE_VOLUMES=false)
  - NOT remove all images (PRUNE_ALL=false)
  - NOT stop running containers
  - Apply no time-based filters (clean all eligible resources)

#### Scenario: Explicit opt-in for aggressive cleanup
**GIVEN** aggressive cleanup is desired
**WHEN** configuring the container
**THEN** users MUST explicitly set:
  - PRUNE_ALL=true for removing all unused images
  - PRUNE_VOLUMES=true for removing volumes
**AND** documentation MUST warn about data loss risks

### Requirement: Configuration Documentation
The system documentation MUST comprehensively document all configuration options.

#### Scenario: Environment variable reference
**GIVEN** a user wants to configure the container
**WHEN** reviewing documentation
**THEN** the documentation MUST include for each variable:
  - Variable name and purpose
  - Accepted values and format
  - Default value
  - Usage example
  - Related variables

#### Scenario: Configuration examples
**GIVEN** users need configuration guidance
**WHEN** reviewing documentation
**THEN** the documentation MUST provide example configurations for:
  - Basic local cleanup
  - Aggressive cleanup with volumes
  - Filtered cleanup (by time or label)
  - Label-based protection
  - Dry-run preview

#### Scenario: Docker Compose integration
**GIVEN** users deploy via Docker Compose
**WHEN** reviewing documentation
**THEN** the documentation MUST provide docker-compose.yml examples
**AND** MUST show how to pass secrets and environment variables

## Cross-References
- Related to: `docker-cleanup-automation` (operation control)
- Related to: `security-permissions` (security-related configuration and Docker socket access)
- Related to: `testing` (configuration validation in tests)
