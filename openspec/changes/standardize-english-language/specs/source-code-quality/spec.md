# Spec: Source Code Quality Review

## ADDED Requirements

### Requirement: All Source Files Must Pass ShellCheck
All bash scripts MUST pass shellcheck linting with no warnings or errors to ensure code correctness and best practices compliance.

#### Scenario: Source scripts pass shellcheck validation
**GIVEN** all source bash scripts in src/ directory
**WHEN** shellcheck is run on each script
**THEN** no SC errors MUST be reported
**AND** no SC warnings MUST be reported
**AND** shellcheck version MUST be 0.7.0 or higher
**AND** all recommended fixes MUST be applied

#### Scenario: Test scripts pass shellcheck validation
**GIVEN** all test bash scripts in tests/ directory
**WHEN** shellcheck is run on each script
**THEN** no SC errors MUST be reported
**AND** no SC warnings MUST be reported
**AND** scripts MUST follow bash best practices

### Requirement: All Functions Must Have Header Comments
Every function in source scripts MUST have a descriptive header comment explaining its purpose, parameters, and return values.

#### Scenario: Cleanup functions have complete documentation
**GIVEN** a function in src/cleanup.sh
**WHEN** a developer reads the function definition
**THEN** a header comment MUST appear immediately before the function
**AND** the comment MUST describe the function's purpose
**AND** the comment MUST document parameters (if any)
**AND** the comment MUST document return values or exit codes
**AND** the comment MUST use consistent format across all functions

#### Scenario: Logger functions have complete documentation
**GIVEN** a function in src/logger.sh
**WHEN** a developer reads the function definition
**THEN** a header comment MUST explain the logging behavior
**AND** the comment MUST document parameters
**AND** the comment MUST explain side effects (stderr output, variables set)
**AND** the comment MUST include usage examples for complex functions

#### Scenario: Utility functions have clear documentation
**GIVEN** utility functions like space_to_bytes() or bytes_to_human()
**WHEN** a developer examines the function
**THEN** a header comment MUST explain the conversion logic
**AND** the comment MUST provide input/output examples
**AND** the comment MUST document edge cases or limitations

### Requirement: Complex Logic Must Have Explanatory Comments
Code sections with complex logic, algorithms, or non-obvious behavior MUST include inline comments explaining the reasoning.

#### Scenario: GID detection logic is well-commented
**GIVEN** the Docker socket GID detection code in entrypoint.sh
**WHEN** a developer reads the GID matching section
**THEN** comments MUST explain why dynamic GID detection is necessary
**AND** comments MUST explain the stat command usage
**AND** comments MUST explain fallback behavior for different platforms
**AND** comments MUST explain security implications

#### Scenario: Space calculation logic is explained
**GIVEN** the space_to_bytes() and bytes_to_human() functions
**WHEN** a developer examines the conversion logic
**THEN** comments MUST explain the byte conversion factors
**AND** comments MUST explain why awk is used for calculations
**AND** comments MUST explain rounding behavior

#### Scenario: Filter building logic is clear
**GIVEN** the build_filter_args() function in cleanup.sh
**WHEN** a developer reads the filter construction code
**THEN** comments MUST explain how filters are combined
**AND** comments MUST explain the Docker filter format
**AND** comments MUST note any Docker API version considerations

### Requirement: Error Messages Must Be Descriptive and Actionable
All error messages MUST clearly describe the problem and suggest corrective actions when possible.

#### Scenario: Docker socket errors provide guidance
**GIVEN** an error occurs when accessing Docker socket
**WHEN** the error message is displayed to the user
**THEN** the message MUST clearly state the socket path checked
**AND** the message MUST explain what access is required
**AND** the message MUST suggest corrective actions (mount volume, check permissions)
**AND** the message MUST include relevant context (GID, permissions)

#### Scenario: Configuration errors provide clear guidance
**GIVEN** an invalid configuration is detected
**WHEN** the validation error is reported
**THEN** the message MUST state which variable is invalid
**AND** the message MUST state the invalid value provided
**AND** the message MUST list valid values or formats
**AND** the message MUST provide an example of correct configuration

#### Scenario: Operation failures include diagnostic information
**GIVEN** a Docker prune operation fails
**WHEN** the error is logged
**THEN** the message MUST state which operation failed
**AND** the message MUST include the Docker error output
**AND** the message MUST suggest common causes
**AND** the message MUST maintain appropriate log level (ERROR)

### Requirement: Code Must Follow Project Conventions
All code MUST adhere to the conventions documented in project.md for consistency and maintainability.

#### Scenario: Functions follow naming conventions
**GIVEN** any function defined in source scripts
**WHEN** the function name is examined
**THEN** the name MUST use snake_case (lowercase with underscores)
**AND** the name MUST be descriptive of the function's purpose
**AND** the name MUST follow Google Shell Style Guide
**AND** the name MUST not conflict with bash built-ins

#### Scenario: Constants follow naming conventions
**GIVEN** any constant or configuration variable
**WHEN** the variable name is examined
**THEN** readonly variables MUST use UPPERCASE
**AND** configuration variables MUST use UPPERCASE
**AND** local variables MUST use lowercase
**AND** variable names MUST be descriptive and clear

#### Scenario: Scripts follow structure conventions
**GIVEN** any source bash script
**WHEN** the script structure is examined
**THEN** the script MUST start with `#!/bin/bash`
**AND** the script MUST include `set -euo pipefail`
**AND** the script MUST use 2-space indentation
**AND** the script MUST define functions before calling them
**AND** the script MUST have a main() function or clear execution flow

### Requirement: Comments Must Explain "Why" Not "What"
Code comments MUST focus on explaining the reasoning, context, or design decisions rather than restating what the code obviously does.

#### Scenario: Comments provide context not redundancy
**GIVEN** a code section with comments
**WHEN** the comments are reviewed
**THEN** comments MUST NOT simply restate the code (bad: "# Set x to 5")
**AND** comments MUST explain why the code is necessary (good: "# Initialize retry counter before network ops")
**AND** comments MUST explain non-obvious design decisions
**AND** comments MUST explain workarounds or platform-specific code

#### Scenario: Comments document security considerations
**GIVEN** code with security implications
**WHEN** security-sensitive sections are reviewed
**THEN** comments MUST explain the security rationale
**AND** comments MUST document trust boundaries
**AND** comments MUST note security trade-offs
**AND** comments MUST reference relevant security documentation

### Requirement: Code Style Must Be Consistent Across All Files
All bash scripts MUST maintain consistent formatting, structure, and style for professional appearance and maintainability.

#### Scenario: Indentation is consistent
**GIVEN** all source bash scripts
**WHEN** indentation is examined
**THEN** all scripts MUST use 2-space indentation
**AND** no tabs MUST be used for indentation
**AND** function bodies MUST be indented consistently
**AND** case statements MUST follow standard indentation

#### Scenario: Quoting is consistent
**GIVEN** all variable references and strings
**WHEN** quoting style is examined
**THEN** all variable expansions MUST be quoted ("$var" not $var)
**AND** double quotes MUST be used for strings with variables
**AND** single quotes MUST be used for literal strings
**AND** command substitution MUST use $() not backticks

#### Scenario: Function definitions are consistent
**GIVEN** all function definitions
**WHEN** function syntax is examined
**THEN** all functions MUST use format: `function_name() {`
**AND** opening brace MUST be on same line as function name
**AND** local variables MUST be declared with `local` keyword
**AND** functions MUST have consistent spacing and structure
