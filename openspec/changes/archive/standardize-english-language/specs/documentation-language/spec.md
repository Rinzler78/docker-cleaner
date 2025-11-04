# Spec: Documentation Language Standardization

## ADDED Requirements

### Requirement: All User-Facing Documentation Must Be in English
All documentation files intended for end users MUST be written exclusively in English to ensure international accessibility and professional presentation.

#### Scenario: README.md contains only English content
**GIVEN** a user views the README.md file
**WHEN** they read any section, heading, or example
**THEN** all text MUST be in English
**AND** no French words or phrases MUST appear
**AND** technical accuracy MUST be preserved
**AND** Docker terminology MUST remain unchanged

#### Scenario: Documentation files are language-consistent
**GIVEN** a user browses the docs/ directory
**WHEN** they open any documentation file
**THEN** the content MUST be exclusively in English
**AND** if duplicate translations exist, English MUST be the primary version
**AND** French versions MUST be removed to avoid maintenance burden

### Requirement: Code Examples Must Use English Comments
All code examples in documentation MUST use English comments and output messages for clarity and consistency.

#### Scenario: README code examples have English comments
**GIVEN** a user reads a code example in README.md
**WHEN** they examine inline comments or echo statements
**THEN** all comments MUST be in English
**AND** all echo/print statements MUST be in English
**AND** the code behavior MUST match the English descriptions

#### Scenario: Shell script examples have English output
**GIVEN** a user runs an example shell script
**WHEN** the script executes and produces output
**THEN** all status messages MUST be in English
**AND** all user prompts MUST be in English
**AND** all error messages MUST be in English

### Requirement: Section Headings Must Be in English
All markdown section headings and titles MUST be in English for consistent navigation and indexing.

#### Scenario: README sections have English headings
**GIVEN** a user navigates the README.md file
**WHEN** they scan section headings and subsections
**THEN** all headings MUST be in English
**AND** heading capitalization MUST follow title case or sentence case consistently
**AND** table of contents (if present) MUST reflect English headings

### Requirement: Technical Terminology Must Be Preserved
Docker-specific and technical terminology MUST remain unchanged during translation to maintain accuracy.

#### Scenario: Docker commands remain unchanged
**GIVEN** documentation contains Docker commands
**WHEN** French content is translated to English
**THEN** Docker commands MUST remain exactly as originally written
**AND** Docker resource types (container, image, volume, network) MUST use standard Docker terminology
**AND** Docker CLI flags and options MUST remain unchanged

#### Scenario: Configuration variables remain unchanged
**GIVEN** documentation references environment variables
**WHEN** surrounding text is translated
**THEN** variable names MUST remain unchanged
**AND** variable values MUST remain unchanged
**AND** only descriptions and explanations MUST be translated

### Requirement: Redundant Translations Must Be Removed
Duplicate documentation files in different languages MUST be removed to reduce maintenance burden.

#### Scenario: French testing documentation is removed
**GIVEN** docs/TESTING.md exists with French content
**AND** docs/testing-guide.md exists with comprehensive English content
**WHEN** language standardization is implemented
**THEN** docs/TESTING.md MUST be deleted
**AND** docs/testing-guide.md MUST remain as the authoritative testing documentation
**AND** any references to docs/TESTING.md MUST be updated to docs/testing-guide.md

### Requirement: Translation Validation Must Pass
All user-facing files MUST be validated to ensure no French content remains after standardization.

#### Scenario: Grep validation finds no French keywords
**GIVEN** language standardization is complete
**WHEN** a grep search is performed for common French keywords
**THEN** no French keywords MUST be found in README.md
**AND** no French keywords MUST be found in example scripts
**AND** no French keywords MUST be found in docs/ directory
**AND** only intentional French terms (like "rendezvous" in technical context) MAY remain

#### Scenario: Translation accuracy is verified
**GIVEN** content has been translated from French to English
**WHEN** the English version is reviewed
**THEN** the technical meaning MUST be preserved
**AND** the level of detail MUST be equivalent
**AND** no information MUST be lost in translation
**AND** clarity MUST be equal to or better than the original
