# Contributing to Docker Cleaner

Thank you for your interest in contributing to docker-cleaner! This document provides guidelines for contributing to the project.

## Language Requirement

**All contributions must be in English**, including:
- Code comments
- Documentation
- Commit messages
- Pull request descriptions
- Issue reports
- Variable and function names

This ensures consistency and accessibility for the international open source community.

## Code Style Guidelines

### Shell Scripts (Bash)

All bash scripts must follow these conventions:

- **Shebang**: Always use `#!/bin/bash`
- **Strict mode**: Include `set -euo pipefail` at the top of all scripts
- **Indentation**: 2 spaces (no tabs)
- **Naming conventions**:
  - Functions: `snake_case`
  - Variables: `UPPER_CASE` for globals, `lower_case` for locals
  - Constants: `UPPER_CASE`
- **Command substitution**: Use `$()` instead of backticks
- **Quoting**: Always quote variables: `"$variable"`
- **Function style**: Use `function_name() {` format

### Comments

- **Explain WHY, not WHAT**: Comments should explain the reasoning, not restate the code
- **Function headers**: Document purpose, parameters, return values, and side effects
- **Complex logic**: Add explanatory comments for non-obvious code
- **Security considerations**: Always document security implications

Example function header:
```bash
# Function: prune_containers
# Purpose: Remove stopped and created containers
# Parameters: None
# Returns: 0 on success, 1 on failure
# Side effects:
#   - Modifies TOTAL_SPACE_FREED global variable
#   - Calls Docker daemon
```

### Code Quality

- **ShellCheck**: All scripts must pass `shellcheck` with no warnings
- **Error handling**: Always check return codes and handle errors gracefully
- **Error messages**: Provide descriptive, actionable error messages
- **Logging**: Use the logger functions (`info`, `warn`, `error`, `debug`)
- **DRY_RUN support**: All destructive operations must support dry-run mode

## Testing Requirements

All changes must include appropriate tests:

1. **Local script tests**: Test functionality directly
2. **Container tests**: Test Docker image behavior
3. **Validation**: Ensure cleanup operations work correctly

Run the test suite before submitting:
```bash
./tests/run-all-tests.sh
```

For detailed testing documentation, see [docs/testing-guide.md](docs/testing-guide.md).

## Pull Request Process

1. **Fork the repository** and create a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**:
   - Follow the code style guidelines
   - Add tests for new functionality
   - Update documentation as needed
   - Ensure all tests pass

3. **Commit your changes**:
   - Use clear, descriptive commit messages
   - Reference related issues if applicable
   - Follow the commit message format below

4. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

5. **Create a Pull Request**:
   - Provide a clear description of the changes
   - Reference any related issues
   - Include test results
   - Request review from maintainers

## Commit Message Format

Use clear, descriptive commit messages:

```
<type>: <short summary>

<detailed description>

Fixes #<issue-number>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Test changes
- `chore`: Build/tooling changes

**Examples**:
```
feat: add support for label-based filtering

Implement PRUNE_FILTER_LABEL environment variable to allow
users to protect resources with specific labels.

Fixes #42
```

```
fix: correct GID detection on macOS

The stat command syntax differs between macOS and Linux.
Add platform detection and use appropriate syntax.

Fixes #38
```

## Security Considerations

When contributing, always consider security implications:

- **Docker socket access**: This tool has root-equivalent access
- **Volume deletion**: Always warn about data loss
- **Input validation**: Validate all environment variables
- **Dry-run mode**: Test destructive operations safely
- **Error messages**: Don't expose sensitive information

## Documentation

Update documentation when:

- Adding new features
- Changing existing behavior
- Adding new environment variables
- Modifying security considerations
- Updating dependencies

Documentation files to update:
- `README.md`: Main documentation
- `docs/testing-guide.md`: Testing procedures
- `docs/SECURITY.md`: Security considerations
- `CHANGELOG.md`: Version history

## Getting Help

If you need help:

- **Issues**: Check existing issues for similar problems
- **Discussions**: Ask questions in GitHub Discussions
- **Documentation**: Review the README and docs/ directory
- **Debug mode**: Use `LOG_LEVEL=DEBUG` for troubleshooting

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on the issue, not the person
- Accept that disagreements happen
- Seek to understand before being understood

## License

By contributing to docker-cleaner, you agree that your contributions will be licensed under the MIT License.

## Recognition

Contributors are recognized in:
- Git commit history
- Release notes
- Project documentation

Thank you for helping make docker-cleaner better! 🎉
