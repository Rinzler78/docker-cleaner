# Docker Cleaner - Comprehensive Testing Guide

This guide describes the testing framework for docker-cleaner and how to run tests across different execution contexts.

## Table of Contents

- [Overview](#overview)
- [Test Architecture](#test-architecture)
- [Quick Start](#quick-start)
- [Test Scripts](#test-scripts)
- [Running Tests](#running-tests)
- [Docker Context Setup](#docker-context-setup)
- [Troubleshooting](#troubleshooting)
- [CI/CD Integration](#cicd-integration)

## Overview

The docker-cleaner testing framework validates cleanup operations across three execution contexts:

1. **Local Script Testing**: Test cleanup script directly in terminal
2. **Container Testing**: Test docker-cleaner Docker image on local host
3. **Remote Context Testing**: Test docker-cleaner on remote Docker hosts via contexts

All tests use label-based resource isolation (`test-cleanup=true`) to ensure production resources are never affected.

## Test Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Testing Architecture                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────────┐ │
│  │  Local Script  │  │  Container     │  │  Remote Context  │ │
│  │  Testing       │  │  Testing       │  │  Testing         │ │
│  └────────┬───────┘  └───────┬────────┘  └────────┬─────────┘ │
│           │                   │                     │           │
│           └───────────────────┼─────────────────────┘           │
│                               │                                 │
│                    ┌──────────▼──────────┐                      │
│                    │  Test Resource      │                      │
│                    │  Management         │                      │
│                    │  (Foundation)       │                      │
│                    └─────────────────────┘                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Run All Tests

```bash
# Run complete test suite (local + container + remote)
./tests/99-run-all-tests.sh
```

### Run Specific Test Types

```bash
# Run only local script tests
./tests/99-run-all-tests.sh --only-local

# Run only container tests
./tests/99-run-all-tests.sh --only-container

# Run only remote context tests
./tests/99-run-all-tests.sh --only-remote

# Skip specific test types
./tests/99-run-all-tests.sh --skip-remote
```

### Run Tests on Specific Context

```bash
# Test on a specific Docker context
./tests/99-run-all-tests.sh --context my-remote-host
```

## Test Scripts

### Foundation Scripts

#### `01-setup-test-resources.sh`

Creates test Docker resources for cleanup testing.

**Usage:**
```bash
./tests/01-setup-test-resources.sh [--context <name>]
```

**Resources Created:**
- Running containers: 2 (protected by `keep=true` label)
- Stopped containers: 3
- Tagged images: 2
- Dangling images: ~2
- Used volumes: 2 (protected by active containers)
- Unused volumes: 3
- Used networks: 2 (protected by active containers)
- Unused networks: 2
- Build cache: Generated

**Examples:**
```bash
# Create resources on default context
./tests/01-setup-test-resources.sh

# Create resources on remote context
./tests/01-setup-test-resources.sh --context remote-nas
```

#### `03-cleanup-test-resources.sh`

Removes all test resources created by `01-setup-test-resources.sh`.

**Usage:**
```bash
./tests/03-cleanup-test-resources.sh [--context <name>]
```

**Safety:**
- Only removes resources with `test-cleanup=true` label
- Production resources are never affected
- Uses `--context` flag to avoid changing active Docker context

**Examples:**
```bash
# Cleanup resources on default context
./tests/03-cleanup-test-resources.sh

# Cleanup resources on remote context
./tests/03-cleanup-test-resources.sh --context remote-nas
```

#### `02-validate-cleanup.sh`

Validates cleanup operations with before/after resource counting.

**Usage:**
```bash
./tests/02-validate-cleanup.sh [--before|--after] [--context <name>]
```

**Modes:**
- `--before`: Count resources before cleanup (validation prep)
- `--after`: Count resources after cleanup (validation check)
- No flag: Full validation (setup + cleanup + validate)

**Examples:**
```bash
# Full validation test
./tests/02-validate-cleanup.sh

# Before cleanup validation
./tests/02-validate-cleanup.sh --before

# After cleanup validation
./tests/02-validate-cleanup.sh --after

# Validate on remote context
./tests/02-validate-cleanup.sh --context remote-nas
```

### Local Script Testing

#### `11-test-local-cleanup.sh`

Tests cleanup script execution directly in terminal.

**Usage:**
```bash
./tests/11-test-local-cleanup.sh [OPTIONS]

Options:
  --dry-run           Test in dry-run mode (no deletions)
  --prune-all         Test with PRUNE_ALL=true
  --prune-volumes     Test with PRUNE_VOLUMES=true
  --context <name>    Test on specific Docker context
```

**Test Coverage:**
- Default cleanup behavior (conservative)
- Aggressive cleanup (prune all + volumes)
- Dry-run mode validation
- Resource protection mechanisms
- Exit code validation

**Examples:**
```bash
# Test default cleanup
./tests/11-test-local-cleanup.sh

# Test aggressive cleanup
./tests/11-test-local-cleanup.sh --prune-all --prune-volumes

# Test dry-run mode
./tests/11-test-local-cleanup.sh --dry-run

# Test on remote context
./tests/11-test-local-cleanup.sh --context remote-dev
```

### Container Testing

#### `12-test-container-cleanup.sh`

Tests docker-cleaner Docker image on local or remote host.

**Usage:**
```bash
./tests/12-test-container-cleanup.sh [OPTIONS]

Options:
  --mode <mode>       Test mode: all|default|aggressive|errors|host
  --context <name>    Test on specific Docker context
  --image <tag>       Docker image tag (default: docker-cleaner:test)
```

**Test Modes:**
- `all`: Run all container tests (default, aggressive, errors, host)
- `default`: Test default cleanup settings
- `aggressive`: Test aggressive cleanup settings
- `errors`: Test error handling (missing socket, etc.)
- `host`: Test that container affects host Docker resources

**Test Coverage:**
- Docker image build and validation
- Container execution with various configurations
- Non-root execution (UID 1000)
- Docker socket GID detection
- Container exit codes (0=success, 1=partial, 2=error)
- Error scenario handling
- Host resource cleanup verification

**Examples:**
```bash
# Run all container tests
./tests/12-test-container-cleanup.sh

# Test default settings only
./tests/12-test-container-cleanup.sh --mode default

# Test aggressive settings
./tests/12-test-container-cleanup.sh --mode aggressive

# Test error handling
./tests/12-test-container-cleanup.sh --mode errors

# Test on remote context
./tests/12-test-container-cleanup.sh --context remote-nas
```

### Remote Context Testing

#### `13-test-remote-contexts.sh`

Tests docker-cleaner on remote Docker hosts via Docker contexts.

**Usage:**
```bash
./tests/13-test-remote-contexts.sh [OPTIONS]

Options:
  --context <name>          Test specific context
  --contexts <name1,name2>  Test multiple contexts (comma-separated)
  --image <tag>             Docker image tag (default: docker-cleaner:test)
```

**Test Coverage:**
- Context switching and restoration
- Remote connectivity validation
- Image availability checking
- Resource creation on remote hosts
- Cleanup execution on remote hosts
- Result validation across multiple contexts
- Graceful degradation (unreachable hosts, missing images)

**Examples:**
```bash
# Test all available contexts
./tests/13-test-remote-contexts.sh

# Test specific context
./tests/13-test-remote-contexts.sh --context remote-nas

# Test multiple contexts
./tests/13-test-remote-contexts.sh --contexts "remote-nas,remote-dev"
```

**Prerequisites:**
- Docker contexts must be configured (see [Docker Context Setup](#docker-context-setup))
- docker-cleaner image must exist on remote host
- Remote host must be reachable

### Master Test Runner

#### `99-run-all-tests.sh`

Orchestrates all test types with comprehensive reporting.

**Usage:**
```bash
./tests/99-run-all-tests.sh [OPTIONS]

Options:
  --skip-local        Skip local script tests
  --skip-container    Skip container tests
  --skip-remote       Skip remote context tests
  --only-local        Run only local script tests
  --only-container    Run only container tests
  --only-remote       Run only remote context tests
  --context <name>    Run all tests on specific context
```

**Features:**
- Runs local, container, and remote tests sequentially
- Aggregates results across all test types
- Provides comprehensive summary report
- Tracks execution time
- Supports selective test execution

**Examples:**
```bash
# Run all tests
./tests/99-run-all-tests.sh

# Run only local and container tests
./tests/99-run-all-tests.sh --skip-remote

# Run only remote tests
./tests/99-run-all-tests.sh --only-remote

# Run all tests on specific context
./tests/99-run-all-tests.sh --context remote-dev
```

## Docker Context Setup

### Important: Context Switching Behavior

**All test scripts now use the `--context` flag** instead of `docker context use`. This means:
- ✅ **Your active context is never changed** during test execution
- ✅ **No need to restore context** after running tests
- ✅ **Safe to run multiple tests in parallel** on different contexts
- ✅ **Explicit control** over which context is targeted

Example:
```bash
# Your active context remains unchanged
docker context show  # Output: default

# Run tests on remote context
./tests/11-test-local-cleanup.sh --context remote-nas

# Active context is still default (not changed)
docker context show  # Output: default
```

### SSH-Based Context

Create a Docker context for remote host access via SSH:

```bash
# Create SSH-based context
docker context create remote-nas \
  --docker "host=ssh://user@nas.example.com"

# Test connectivity using --context flag
docker --context remote-nas ps

# No need to switch back - active context never changed
```

### TCP-Based Context

Create a Docker context for remote host access via TCP:

```bash
# Create TCP-based context
docker context create remote-tcp \
  --docker "host=tcp://remote.example.com:2375"

# For TLS (recommended):
docker context create remote-tls \
  --docker "host=tcp://remote.example.com:2376" \
  --docker "ca=/path/to/ca.pem" \
  --docker "cert=/path/to/cert.pem" \
  --docker "key=/path/to/key.pem"
```

### Remote Docker Host Configuration

#### Prerequisites for TCP-Based Contexts

**IMPORTANT**: To use TCP-based Docker contexts, port 2375 (or 2376 for TLS) must be open on the remote Docker host.

#### Option 1: Expose Docker Socket via Socat Container (Recommended)

For systems where you cannot or don't want to modify the Docker daemon configuration, use a socat container to expose the Docker socket over TCP:

```bash
# On the remote Docker host, run:
docker run -d \
  --name docker-socat \
  --restart unless-stopped \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  alpine/socat \
  tcp-listen:2375,fork,reuseaddr unix-connect:/var/run/docker.sock
```

**Security Notes**:
- This exposes Docker without authentication on port 2375
- Only use on trusted networks or with firewall rules
- For production, use SSH-based contexts or TLS authentication
- Consider restricting access with iptables rules:
  ```bash
  # Example: Allow only from specific IP
  sudo iptables -A INPUT -p tcp --dport 2375 -s 192.168.1.100 -j ACCEPT
  sudo iptables -A INPUT -p tcp --dport 2375 -j DROP
  ```

**Verify the socat container is running**:
```bash
# On remote host
docker ps | grep docker-socat

# From local machine
docker --context remote-tcp ps
```

#### Option 2: Configure Docker Daemon (Alternative)

Alternatively, you can configure the Docker daemon to listen on TCP:

**Edit `/etc/docker/daemon.json`**:
```json
{
  "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2375"]
}
```

**Restart Docker**:
```bash
sudo systemctl restart docker
```

**Warning**: This method requires daemon restart and affects all Docker operations on the host.

#### Testing Remote Connection

After setting up TCP access, test the connection:

```bash
# Create context
docker context create my-remote \
  --docker "host=tcp://remote-host:2375"

# Test connection
docker --context my-remote version
docker --context my-remote ps
```

### List Contexts

```bash
# List all contexts
docker context ls

# Show current context
docker context show
```

### Remove Context

```bash
# Remove a context
docker context rm remote-nas
```

## Troubleshooting

### Issue: Tests fail with "Permission denied" on Docker socket

**Solution:**
Ensure your user is in the `docker` group:
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

### Issue: Remote context tests skip with "Image not found"

**Solution:**
Build or push the image to the remote host using `--context` flag:
```bash
# Build image on remote host (no context switching needed)
docker --context remote-nas build -t docker-cleaner:test .

# Or using buildx for multi-context builds
docker buildx build --context remote-nas -t docker-cleaner:test .
```

### Issue: Test resources not cleaned up after failure

**Solution:**
Manually cleanup test resources:
```bash
./tests/03-cleanup-test-resources.sh

# For specific context:
./tests/03-cleanup-test-resources.sh --context remote-nas
```

### Issue: Tests fail with "Context does not exist"

**Solution:**
Verify context exists and is accessible:
```bash
# List all available contexts
docker context ls

# Test connectivity using --context flag (no switching needed)
docker --context <context-name> ps

# If context doesn't exist, create it
docker context create <context-name> --docker "host=ssh://user@host"
```

### Issue: Tests fail on macOS with "Cannot connect to Docker daemon"

**Solution:**
Ensure Docker Desktop is running:
```bash
# Check Docker is running
docker ps

# If not, start Docker Desktop application
```

## CI/CD Integration

### GitHub Actions

Example workflow for running tests in GitHub Actions:

```yaml
name: Test Docker Cleaner

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Run local script tests
        run: ./tests/99-run-all-tests.sh --only-local

      - name: Run container tests
        run: ./tests/99-run-all-tests.sh --only-container

      - name: Cleanup test resources
        if: always()
        run: ./tests/03-cleanup-test-resources.sh
```

### GitLab CI

Example pipeline for GitLab CI:

```yaml
stages:
  - test

test-local:
  stage: test
  image: docker:latest
  services:
    - docker:dind
  script:
    - apk add --no-cache bash
    - ./tests/99-run-all-tests.sh --only-local

test-container:
  stage: test
  image: docker:latest
  services:
    - docker:dind
  script:
    - apk add --no-cache bash
    - ./tests/99-run-all-tests.sh --only-container

cleanup:
  stage: test
  when: always
  image: docker:latest
  services:
    - docker:dind
  script:
    - apk add --no-cache bash
    - ./tests/03-cleanup-test-resources.sh
```

### Jenkins

Example Jenkinsfile:

```groovy
pipeline {
    agent any

    stages {
        stage('Test Local') {
            steps {
                sh './tests/99-run-all-tests.sh --only-local'
            }
        }

        stage('Test Container') {
            steps {
                sh './tests/99-run-all-tests.sh --only-container'
            }
        }
    }

    post {
        always {
            sh './tests/03-cleanup-test-resources.sh'
        }
    }
}
```

## Test Execution Time

Expected execution times (on typical hardware):

- Local script tests: 2-3 minutes
- Container tests: 3-5 minutes (includes image build)
- Remote context tests: 3-10 minutes (depends on remote host count)
- Complete test suite: 8-15 minutes

## Best Practices

1. **Always run tests before committing changes** to ensure functionality
2. **Use `--dry-run` mode** to preview test behavior without affecting resources
3. **Run cleanup scripts** manually if tests are interrupted
4. **Test on remote contexts** before deploying to production environments
5. **Use specific contexts** (`--context`) for targeted testing
6. **Review test logs** in `/tmp/` for debugging failures
7. **Keep test resources isolated** using labels to prevent production impact
8. **No need to restore context** - all tests use `--context` flag without changing active context
9. **Run tests in parallel** on different contexts safely since they don't interfere

## Support

For issues or questions about testing:
- Check the [Troubleshooting](#troubleshooting) section
- Review test script source code in `tests/` directory
- Report issues on GitHub issue tracker

## Contributing

When adding new tests:
1. Follow existing test script patterns
2. Use consistent error handling (`set -euo pipefail`)
3. **Use `docker_ctx()` helper function** instead of direct `docker` commands
4. **Use `--context` flag pattern** instead of `docker context use`
5. Add trap handlers for cleanup on failure
6. Use colored output for readability
7. Document test purpose and usage
8. Update this guide with new test information

### docker_ctx() Helper Pattern

All test scripts use a helper function to handle contexts:

```bash
# Docker context wrapper - uses --context flag when TARGET_CONTEXT is set
docker_ctx() {
    if [ -n "$TARGET_CONTEXT" ]; then
        docker --context "$TARGET_CONTEXT" "$@"
    else
        docker "$@"
    fi
}

# Usage in tests
docker_ctx ps -q
docker_ctx run --rm myimage
docker_ctx volume ls
```

This ensures:
- Context is never switched globally
- Tests are isolated and can run in parallel
- No cleanup of context state is needed
- More predictable and safer behavior
