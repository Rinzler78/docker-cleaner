# Spec: Code Comments Language Standardization

## ADDED Requirements

### Requirement: Example Scripts Must Have English Comments
All example shell scripts MUST contain only English comments for international developer accessibility.

#### Scenario: cleanup-all.sh has English header comments
**GIVEN** a developer opens examples/cleanup-all.sh
**WHEN** they read the file header comment
**THEN** the comment MUST be in English
**AND** the comment MUST describe the script purpose clearly
**AND** the comment MUST match the script's actual behavior

#### Scenario: cleanup-all.sh has English inline comments
**GIVEN** a developer reads examples/cleanup-all.sh
**WHEN** they examine inline comments explaining code sections
**THEN** all inline comments MUST be in English
**AND** comments MUST explain the "why" not just the "what"
**AND** comments MUST be clear and concise

### Requirement: Example Scripts Must Have English Output Messages
All user-facing output messages in example scripts MUST be in English.

#### Scenario: cleanup-all.sh displays English messages
**GIVEN** a user executes examples/cleanup-all.sh
**WHEN** the script runs and produces output
**THEN** all echo statements MUST display English text
**AND** status messages MUST be in English
**AND** success/failure messages MUST be in English
**AND** emoji usage MAY be preserved for visual clarity

#### Scenario: cleanup-complete.sh displays English pass indicators
**GIVEN** a user executes examples/cleanup-complete.sh
**WHEN** the script indicates which pass is running
**THEN** pass indicators MUST be in English (e.g., "PASS 1", "PASS 2")
**AND** pass descriptions MUST be in English
**AND** completion messages MUST be in English

### Requirement: Example Script Behavior Must Match Documentation
Example scripts MUST behave exactly as described in the translated English documentation.

#### Scenario: Script output matches README descriptions
**GIVEN** README.md describes an example script's behavior in English
**WHEN** a user runs that example script
**THEN** the actual output MUST match the documented behavior
**AND** the output MUST be in English as documented
**AND** the script MUST perform the documented operations

#### Scenario: Script comments align with README examples
**GIVEN** README.md includes code snippets from example scripts
**WHEN** a developer compares the snippets to actual script files
**THEN** the comments in the snippets MUST match the actual script comments
**AND** both MUST be in English
**AND** the functionality described MUST match the implementation

### Requirement: Example Scripts Must Be Executable After Translation
Example scripts MUST remain functional and executable after comment translation.

#### Scenario: cleanup-all.sh executes successfully in dry-run
**GIVEN** cleanup-all.sh has been translated to English
**WHEN** a user runs it with DRY_RUN=true
**THEN** the script MUST execute without errors
**AND** the script MUST display English output
**AND** the script MUST show what would be cleaned
**AND** the script MUST not modify any Docker resources

#### Scenario: cleanup-complete.sh executes both passes
**GIVEN** cleanup-complete.sh has been translated to English
**WHEN** a user runs it with DRY_RUN=true
**THEN** the script MUST execute both passes
**AND** each pass MUST display English status messages
**AND** the script MUST complete successfully
**AND** the script MUST summarize results in English

### Requirement: Example Script Structure Must Remain Unchanged
Translation MUST NOT alter the functional structure or logic of example scripts.

#### Scenario: Script logic is preserved during translation
**GIVEN** an example script contains French comments
**WHEN** the comments are translated to English
**THEN** all bash commands MUST remain unchanged
**AND** all control flow (if/while/for) MUST remain unchanged
**AND** all variable assignments MUST remain unchanged
**AND** all function calls MUST remain unchanged
**AND** only comments and string literals MUST be modified

#### Scenario: Script dependencies remain intact
**GIVEN** an example script sources other scripts or uses Docker commands
**WHEN** comments are translated to English
**THEN** all source statements MUST remain unchanged
**AND** all Docker CLI commands MUST remain unchanged
**AND** all environment variable references MUST remain unchanged
**AND** script functionality MUST be identical pre- and post-translation

### Requirement: Validation Tests Must Verify English Content
Automated validation MUST confirm all example scripts contain only English comments and output.

#### Scenario: Grep validation finds no French in example scripts
**GIVEN** example scripts have been translated
**WHEN** grep searches for common French keywords in examples/ directory
**THEN** no French keywords MUST be found
**AND** the search MUST include case-insensitive matching
**AND** common French programming terms MUST not appear

#### Scenario: Dry-run execution validates English output
**GIVEN** example scripts have been translated
**WHEN** each script is executed in dry-run mode
**THEN** all output MUST be in English
**AND** no French text MUST appear in stdout or stderr
**AND** scripts MUST complete successfully
**AND** scripts MUST perform their documented operations
