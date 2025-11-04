# Spec: Code Comment Standards

## ADDED Requirements

### Requirement: Source File Headers Must Be Complete
Every source bash script MUST have a complete header comment block with file purpose and usage information.

#### Scenario: Script headers include purpose and usage
**GIVEN** any source script in src/ directory
**WHEN** the file is opened
**THEN** a header comment MUST appear in the first 10 lines
**AND** the header MUST include the script filename
**AND** the header MUST describe the script's purpose
**AND** the header MUST note any dependencies on other scripts
**AND** the header format MUST be consistent across all files

#### Scenario: Entrypoint script has comprehensive header
**GIVEN** the src/entrypoint.sh file
**WHEN** a developer reads the file header
**THEN** the header MUST explain its role as container entrypoint
**AND** the header MUST document the GID matching process
**AND** the header MUST list the scripts it calls
**AND** the header MUST note security considerations

### Requirement: Function Comments Must Follow Standard Format
All function comments MUST use a consistent format for documentation clarity.

#### Scenario: Function comment format is standardized
**GIVEN** any function in source scripts
**WHEN** the function header comment is examined
**THEN** the comment MUST start with `# Function:` or `# Function Name`
**AND** the comment MUST include a one-line purpose description
**AND** parameters MUST be documented with `# Parameters:` section
**AND** return values MUST be documented with `# Returns:` or `# Exit codes:` section
**AND** side effects MUST be documented if present

**Example format**:
```bash
# Function: prune_containers
# Purpose: Remove stopped Docker containers and log results
# Parameters: None
# Returns: 0 on success, 1 on failure
# Side effects:
#   - Modifies TOTAL_SPACE_FREED global variable
#   - Modifies OPERATIONS_SUCCEEDED or OPERATIONS_FAILED counters
#   - Logs to stderr via logger functions
```

#### Scenario: Complex functions include examples
**GIVEN** a function with complex behavior or multiple use cases
**WHEN** the function documentation is reviewed
**THEN** the comment MUST include usage examples
**AND** examples MUST show common use cases
**AND** examples MUST be syntactically correct
**AND** examples MUST demonstrate parameter usage

### Requirement: Inline Comments Must Be Meaningful
Inline comments within functions MUST add value by explaining non-obvious logic, not restating code.

#### Scenario: Comments explain why not what
**GIVEN** inline comments within a function
**WHEN** each comment is evaluated
**THEN** the comment MUST NOT simply restate the code
**AND** the comment MUST explain the reasoning or context
**AND** the comment MUST clarify non-obvious behavior
**AND** the comment MUST be placed above or beside the relevant code

**Bad example**:
```bash
# Set x to 5
x=5
```

**Good example**:
```bash
# Initialize retry counter (max 5 attempts for network resilience)
x=5
```

#### Scenario: Security-sensitive code has explanatory comments
**GIVEN** code that handles security, permissions, or sensitive data
**WHEN** the code section is reviewed
**THEN** comments MUST explain the security rationale
**AND** comments MUST note any security trade-offs
**AND** comments MUST reference security best practices when applicable
**AND** comments MUST warn about potential risks

### Requirement: TODOs and FIXMEs Must Be Tracked
Any TODO or FIXME comments MUST follow a standard format for tracking and resolution.

#### Scenario: TODO comments are properly formatted
**GIVEN** a TODO comment in any source file
**WHEN** the comment is examined
**THEN** the comment MUST use format: `# TODO: description`
**AND** the description MUST be specific and actionable
**AND** the TODO MUST include context about why it's deferred
**AND** the TODO SHOULD include a ticket/issue reference if available

#### Scenario: FIXMEs include context
**GIVEN** a FIXME comment in any source file
**WHEN** the comment is examined
**THEN** the comment MUST use format: `# FIXME: description`
**AND** the description MUST explain what is broken or suboptimal
**AND** the comment MUST explain why a proper fix wasn't implemented yet
**AND** the comment MUST note any workarounds in place

### Requirement: Comments Must Be Maintained With Code
Comments MUST be updated when the associated code changes to prevent misleading or outdated information.

#### Scenario: Function comments match implementation
**GIVEN** a function with header documentation
**WHEN** the function implementation is examined
**THEN** the documented parameters MUST match actual parameters
**AND** the documented return values MUST match actual returns
**AND** the documented side effects MUST match actual side effects
**AND** no documented behavior MUST contradict the implementation

#### Scenario: Inline comments remain accurate
**GIVEN** inline comments within a function
**WHEN** the surrounding code is examined
**THEN** comments MUST accurately describe the current code behavior
**AND** comments MUST NOT reference removed or refactored code
**AND** comments MUST NOT contain outdated variable names
**AND** comments MUST reflect current logic and control flow

### Requirement: Special Cases and Edge Cases Must Be Documented
Code that handles special cases, edge cases, or platform-specific behavior MUST have explanatory comments.

#### Scenario: Platform differences are documented
**GIVEN** code with platform-specific behavior (macOS vs Linux)
**WHEN** the platform-specific section is reviewed
**THEN** comments MUST explain why platform differences exist
**AND** comments MUST identify which platforms are affected
**AND** comments MUST explain the different behaviors
**AND** comments MUST note any limitations or workarounds

**Example**:
```bash
# macOS uses BSD stat requiring -f flag, Linux uses GNU stat with -c flag
DOCKER_GID=$(stat -c '%g' "$DOCKER_SOCKET" 2>/dev/null || stat -f '%g' "$DOCKER_SOCKET" 2>/dev/null)
```

#### Scenario: Edge cases are explained
**GIVEN** code that handles edge cases or boundary conditions
**WHEN** the edge case handling is reviewed
**THEN** comments MUST explain what edge case is being handled
**AND** comments MUST explain why the edge case occurs
**AND** comments MUST explain how the edge case is resolved
**AND** comments MUST provide examples when helpful

### Requirement: Comment Density Must Be Balanced
Code MUST have appropriate comment density - not too sparse (missing context) nor too dense (restating obvious code).

#### Scenario: Complex functions have adequate comments
**GIVEN** a function with complex logic (>20 lines)
**WHEN** the function is reviewed for comment density
**THEN** major logic sections MUST have explanatory comments
**AND** non-obvious variable usage MUST be explained
**AND** complex conditionals MUST have context comments
**AND** the function MUST NOT have excessive line-by-line comments

**Guideline**: Aim for 1 meaningful comment per 5-10 lines of complex logic.

#### Scenario: Simple functions avoid over-commenting
**GIVEN** a simple function with straightforward logic
**WHEN** the function is reviewed for comments
**THEN** obvious operations MUST NOT be commented
**AND** self-explanatory variable names MUST NOT need comments
**AND** standard patterns MUST NOT be over-explained
**AND** only non-obvious aspects MUST be commented

### Requirement: Error Handling Must Be Documented
Code sections that handle errors or exceptional conditions MUST have comments explaining the error handling strategy.

#### Scenario: Error traps are explained
**GIVEN** code using trap statements for error handling
**WHEN** the trap code is reviewed
**THEN** comments MUST explain what errors are being caught
**AND** comments MUST explain the cleanup actions performed
**AND** comments MUST note any resources that need cleanup
**AND** comments MUST explain why the trap is necessary

#### Scenario: Fallback behavior is documented
**GIVEN** code with fallback or retry logic
**WHEN** the fallback section is reviewed
**THEN** comments MUST explain under what conditions fallback is used
**AND** comments MUST explain the fallback strategy
**AND** comments MUST note any limitations of the fallback
**AND** comments MUST explain retry limits or backoff strategies
