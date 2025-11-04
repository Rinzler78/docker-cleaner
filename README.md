# Docker Cleaner

```text
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    ██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗         ║
║    ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗        ║
║    ██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝        ║
║    ██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗        ║
║    ██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║        ║
║    ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝        ║
║                                                              ║
║         ██████╗██╗     ███████╗ █████╗ ███╗   ██╗           ║
║        ██╔════╝██║     ██╔════╝██╔══██╗████╗  ██║           ║
║        ██║     ██║     █████╗  ███████║██╔██╗ ██║           ║
║        ██║     ██║     ██╔══╝  ██╔══██║██║╚██╗██║           ║
║        ╚██████╗███████╗███████╗██║  ██║██║ ╚████║           ║
║         ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

## 🧹 Automated Docker Cleanup Container

Reclaim disk space instantly with secure, one-shot Docker cleanup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker Image](https://img.shields.io/badge/docker-rinzlerfr%2Fdocker--cleaner-blue?logo=docker)](https://hub.docker.com/r/rinzlerfr/docker-cleaner)
[![Docker Pulls](https://img.shields.io/docker/pulls/rinzlerfr/docker-cleaner)](https://hub.docker.com/r/rinzlerfr/docker-cleaner)
[![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macOS-lightgrey)](https://github.com/rinzlerfr/docker-cleaner)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

---

## 📋 Table of Contents

- [At a Glance](#at-a-glance)
- [Why Docker Cleaner?](#why-docker-cleaner)
- [Quick Start](#quick-start)
- [How It Works](#how-it-works)
- [Cleanup Levels](#cleanup-levels)
- [Configuration](#configuration)
- [Use Cases](#use-cases)
- [Security Considerations](#security-considerations)
- [Performance](#performance)
- [Docker Hub](#docker-hub)
- [Development & Testing](#development-and-testing)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## ✨ At a Glance

| 🎯 Feature | 📊 Details |
|-----------|-----------|
| **Execution Mode** | One-shot (cron-ready) |
| **Security** | Non-root, GID matching, no `--privileged` |
| **Configurability** | 15+ environment variables |
| **Multi-Host** | Docker context support |
| **Safety** | DRY_RUN mode, conservative defaults |
| **Performance** | ~50MB memory, 30s-4min execution |
| **Platforms** | Linux, macOS (Docker daemon required) |

Automated Docker cleanup container that reclaims disk space by removing unused
containers, images, volumes, networks, and build cache. Designed for
**one-shot execution** with **secure, non-privileged** access to Docker daemon.

**🔑 Key Advantages:**

- ✅ **Security First**: No `--privileged` mode needed
- ✅ **Local Execution**: Always cleans the host where it runs
- ✅ **Safe Defaults**: Protects volumes and critical resources
- ✅ **Production Ready**: Comprehensive logging and error handling

[⬆️ Back to top](#-table-of-contents)

---

## 🤔 Why Docker Cleaner?

### The Problem

Docker accumulates disk space quickly:

- Stopped containers pile up after deployments
- Dangling images from builds consume GBs
- Unused volumes remain after testing
- Build cache grows indefinitely

### The Solution

**docker-cleaner** provides:

| Feature | docker-cleaner | `docker system prune` | Manual cleanup |
|---------|---------------|---------------------|---------------|
| **One command** | ✅ | ✅ | ❌ |
| **Scheduled execution** | ✅ | ❌ | ❌ |
| **Multi-host support** | ✅ | ❌ | ❌ |
| **Non-root security** | ✅ | N/A | N/A |
| **Comprehensive logging** | ✅ | ⚠️ | ❌ |
| **Configuration flexibility** | ✅ | ⚠️ | ✅ |
| **DRY_RUN preview** | ✅ | ⚠️ | ❌ |

### Use Cases

- 🏠 **Home Labs**: Schedule weekly cleanups on Docker NAS/servers
- 🔧 **CI/CD**: Reclaim space after builds in pipelines
- 💻 **Development**: Keep local Docker environment lean
- 🏢 **DevOps**: Manage cleanup across multiple hosts

[⬆️ Back to top](#-table-of-contents)

---

## 🚀 Quick Start

### From Docker Hub (Recommended)

```bash
# Pull latest version
docker pull rinzlerfr/docker-cleaner:latest

# Run complete cleanup
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e PRUNE_ALL=true \
  -e PRUNE_VOLUMES=true \
  -e CLEANUP_VOLUMES=true \
  rinzlerfr/docker-cleaner:latest
```

### Build from Source

```bash
# Clone repository
git clone https://github.com/rinzlerfr/docker-cleaner.git
cd docker-cleaner

# Build image
docker build -t docker-cleaner .

# Run cleanup
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e PRUNE_ALL=true \
  docker-cleaner
```

### Preview Before Cleaning

```bash
# Test with DRY_RUN mode (recommended first time)
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e PRUNE_ALL=true \
  -e PRUNE_VOLUMES=true \
  -e CLEANUP_VOLUMES=true \
  -e DRY_RUN=true \
  rinzlerfr/docker-cleaner:latest
```

**Expected output:**

```text
🧹 Docker Cleanup Container v1.0.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚙️  Configuration:
   • Mode: DRY_RUN (no deletion)
   • Cleanup: containers, images (all), volumes, networks, cache
   • Filters: none
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔍 [DRY_RUN] Would remove 15 stopped containers
🔍 [DRY_RUN] Would remove 8 unused images (2.3 GB)
🔍 [DRY_RUN] Would remove 3 unused volumes (450 MB)
🔍 [DRY_RUN] Would remove 2 unused networks
🔍 [DRY_RUN] Would remove build cache (1.1 GB)

📊 Total space reclaimable: 3.85 GB
✅ Dry-run completed successfully
```

### Using Docker Compose

```bash
# FULL CLEANUP - Cleans EVERYTHING (recommended)
docker-compose --profile full up docker-cleaner-full

# Default cleanup (conservative - volumes protected)
docker-compose up docker-cleaner

# Dry-run mode (preview without deletion)
docker-compose --profile dryrun up docker-cleaner-dryrun
```

### Shell Scripts

```bash
# Complete cleanup in one pass
./examples/cleanup-all.sh

# Complete guaranteed cleanup (2 passes - removes orphaned images)
./examples/cleanup-complete.sh

# Test with dry-run
DRY_RUN=true ./examples/cleanup-all.sh
```

[⬆️ Back to top](#-table-of-contents)

---

## 🔧 How It Works

### Architecture Overview

```text
┌─────────────────────────────────────────────────────────┐
│                    HOST MACHINE                         │
│                                                          │
│  ┌──────────────────────────────────────────┐          │
│  │     Docker Daemon (dockerd)              │          │
│  │                                           │          │
│  │  /var/run/docker.sock (GID: 998)        │          │
│  └─────────────┬────────────────────────────┘          │
│                │ Socket Access                          │
│                │ (via GID matching)                     │
│  ┌─────────────▼────────────────────────────┐          │
│  │  docker-cleaner Container                │          │
│  │  ┌────────────────────────────────────┐  │          │
│  │  │ 1. Detect socket GID (998)        │  │          │
│  │  │ 2. Create group with GID 998      │  │          │
│  │  │ 3. Add user to group              │  │          │
│  │  │ 4. Execute cleanup as non-root    │  │          │
│  │  └────────────────────────────────────┘  │          │
│  │                                           │          │
│  │  User: cleaner (UID 1000) ✅ Non-root   │          │
│  │  Group: docker (GID 998)  ✅ Socket access│          │
│  └───────────────────────────────────────────┘          │
│                                                          │
│  Result: Secure cleanup without --privileged            │
└─────────────────────────────────────────────────────────┘
```

### Local Execution Principle

⚠️ **IMPORTANT**: The container **always runs on the host to be cleaned** -
it never connects to remote hosts.

When you use Docker contexts (e.g., `docker context use nas`), the Docker
client on your machine sends the `docker run` command to the remote daemon,
which then executes the container locally on that host. The volume mount
`/var/run/docker.sock:/var/run/docker.sock` is interpreted by the execution
host's daemon, not your client machine.

**In other words**: If you run this container while in NAS context, the
container runs ON the NAS and mounts the NAS's socket, cleaning the NAS's
Docker resources. Your client machine only displays the output.

### Docker Socket GID Matching

Instead of requiring `--privileged` mode, the container uses dynamic GID
matching:

1. **Detect** GID of `/var/run/docker.sock` at startup
2. **Create** or reuse group with matching GID
3. **Add** non-root user to this group
4. **Execute** cleanup operations as non-root user with Docker access

This provides **secure, non-root access** to the Docker daemon without
privileged mode.

[⬆️ Back to top](#-table-of-contents)

---

## 🎯 Cleanup Levels

### 🔥 FULL CLEANUP (Recommended)

Cleans **EVERYTHING** except running containers and volumes in use:

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -e PRUNE_ALL=true \
  -e PRUNE_VOLUMES=true \
  -e CLEANUP_VOLUMES=true \
  rinzlerfr/docker-cleaner:latest
```

**What gets removed**:

- ✅ Stopped containers (exited, created)
- ✅ Unused images (all, not just dangling)
- ✅ Unused volumes (not mounted by containers)
- ✅ Unused networks (not used by containers)
- ✅ Build cache (intermediate layers)

**What is protected**:

- ✅ Running containers
- ✅ Volumes mounted by running containers
- ✅ Networks used by running containers
- ✅ Images used by running containers

⚠️ **Important note**: Docker checks image usage AT THE TIME of pruning. If
you have stopped containers that are removed by cleanup, their base images
remain because they were referenced at the time of verification. To remove
these orphaned images, simply run docker-cleaner a second time.

### 🛡️ Conservative (Default)

Conservative cleanup that protects volumes:

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  rinzlerfr/docker-cleaner:latest
```

**What gets removed**:

- ✅ Stopped containers
- ✅ Dangling images (untagged)
- ✅ Unused networks
- ✅ Build cache

**What is protected**:

- ✅ ALL volumes (even unused)
- ✅ Tagged images (even unused)
- ✅ Running containers

[⬆️ Back to top](#-table-of-contents)

---

## ⚙️ Configuration

All configuration is done via environment variables:

### Core Operations

| Variable | Default | Description |
|----------|---------|-------------|
| `PRUNE_ALL` | `false` | Remove all unused images (not just dangling) |
| `PRUNE_VOLUMES` | `false` | Include volumes in cleanup ⚠️ **DANGER** |
| `PRUNE_FORCE` | `true` | Skip confirmation prompts |

### Selective Operations

| Variable | Default | Description |
|----------|---------|-------------|
| `CLEANUP_CONTAINERS` | `true` | Prune stopped containers |
| `CLEANUP_IMAGES` | `true` | Prune unused images |
| `CLEANUP_VOLUMES` | `false` | Prune unused volumes ⚠️ |
| `CLEANUP_NETWORKS` | `true` | Prune unused networks |
| `CLEANUP_BUILD_CACHE` | `true` | Prune build cache |

### Filters

| Variable | Default | Description |
|----------|---------|-------------|
| `PRUNE_FILTER_UNTIL` | _(none)_ | Remove resources older than duration |
| `PRUNE_FILTER_LABEL` | _(none)_ | Filter by label (e.g., `keep!=true`) |

### Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL` | `INFO` | Log level: `DEBUG`, `INFO`, `WARN`, `ERROR` |
| `LOG_FORMAT` | `text` | Output format: `text` or `json` |
| `QUIET` | `false` | Minimal output |

### Execution Mode

| Variable | Default | Description |
|----------|---------|-------------|
| `DRY_RUN` | `false` | Preview without deleting |

[⬆️ Back to top](#-table-of-contents)

---

## 💡 Use Cases

### Use Case 1: Local Mac Cleanup

```bash
# One-time cleanup
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  rinzlerfr/docker-cleaner:latest

# Weekly cron job
0 2 * * 0 docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  rinzlerfr/docker-cleaner:latest
```

### Use Case 2: Remote NAS Cleanup

```bash
# Switch to NAS context
docker context use nas

# Run cleanup (executes on NAS, cleans NAS Docker)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  rinzlerfr/docker-cleaner:latest

# Switch back
docker context use default
```

### Use Case 3: CI/CD Pipeline Cleanup

#### GitLab CI

```yaml
cleanup:
  stage: post-build
  script:
    - docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
        rinzlerfr/docker-cleaner:latest
```

#### GitHub Actions

```yaml
name: Docker Cleanup
on:
  schedule:
    - cron: '0 2 * * *'

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Run Docker Cleanup
        run: |
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -e PRUNE_FILTER_UNTIL=168h \
            rinzlerfr/docker-cleaner:latest
```

### Use Case 4: Multiple Hosts Management

```bash
# Define contexts for each host
docker context create dev-server --docker "host=ssh://dev-server"
docker context create staging-server --docker "host=ssh://staging-server"

# Cleanup script for all hosts
for ctx in default dev-server staging-server; do
  echo "Cleaning $ctx..."
  docker context use $ctx
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    rinzlerfr/docker-cleaner:latest
done
docker context use default
```

### Example Output

```bash
$ docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    -e PRUNE_ALL=true -e PRUNE_VOLUMES=true -e CLEANUP_VOLUMES=true \
    rinzlerfr/docker-cleaner:latest

🧹 Docker Cleanup Container v1.0.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚙️  Configuration:
   • Mode: CLEANUP (deletion enabled)
   • Cleanup: containers, images (all), volumes, networks, cache
   • Filters: none
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🗑️  Removing stopped containers...
    ✓ Removed 15 containers

🗑️  Removing unused images (all)...
    ✓ Removed 8 images
    ✓ Reclaimed 2.3 GB

🗑️  Removing unused volumes...
    ✓ Removed 3 volumes
    ✓ Reclaimed 450 MB

🗑️  Removing unused networks...
    ✓ Removed 2 networks

🗑️  Removing build cache...
    ✓ Removed cache
    ✓ Reclaimed 1.1 GB

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Summary:
   • Total space reclaimed: 3.85 GB
   • Operations: 5/5 successful
   • Exit code: 0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Cleanup completed successfully
```

[⬆️ Back to top](#-table-of-contents)

---

## 🔒 Security Considerations

### Risks

⚠️ **WARNING**: Mounting `docker.sock` grants **equivalent root access** to
the host.

- Container can start new containers, including privileged ones
- Container can mount any host path
- Container can read/write all Docker resources

### Mitigations

1. **Least Privilege Execution**
   - Non-root user in container (UID 1000)
   - No `--privileged` flag required
   - GID matching for secure socket access

2. **Resource Protection**
   - Label-based filters to protect critical resources
   - Running container protection (Docker's default)
   - Volume-in-use protection (Docker's default)
   - Conservative defaults (no volumes, no all images)

3. **Audit Trail**
   - Comprehensive logging of all operations
   - Structured logging for SIEM integration
   - Security warnings about socket sharing

4. **Best Practices**
   - Only run on hosts you control
   - Use trusted images
   - Review logs regularly
   - Test with `DRY_RUN=true` first
   - Use label filters to protect important resources

### Acceptable Use

- ✅ Scheduled cleanup on development/staging hosts
- ✅ CI/CD pipeline cleanup after builds
- ✅ Manual cleanup on production (with caution and dry-run first)
- ❌ Untrusted hosts
- ❌ Multi-tenant environments without isolation

For detailed security documentation, see
[docs/security-guide.md](docs/security-guide.md).

[⬆️ Back to top](#-table-of-contents)

---

## 📊 Performance

### Execution Times

Expected execution times vary based on resource count:

| Resource Count | Estimated Time |
|----------------|----------------|
| Small (<50) | ~30 seconds |
| Medium (50-200) | ~1 minute |
| Large (200-1000) | ~2 minutes |
| Very Large (>1000) | ~4 minutes |

**Memory usage**: ~50MB peak

### Exit Codes

- `0`: Success (all operations succeeded)
- `1`: Partial failure (some operations failed, some succeeded)
- `2`: Complete failure (cannot connect to Docker or all operations failed)

[⬆️ Back to top](#-table-of-contents)

---

## 🐳 Docker Hub

The docker-cleaner image is automatically published to Docker Hub with each
release:

```bash
# Pull latest version
docker pull rinzlerfr/docker-cleaner:latest

# Pull specific version
docker pull rinzlerfr/docker-cleaner:v1.0.0

# Run from Docker Hub
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  rinzlerfr/docker-cleaner:latest
```

### Available Tags

- `latest` - Latest stable release
- `v1.0.0`, `v1.0`, `v1` - Semantic version tags
- Multi-architecture support: `amd64`, `arm64`

### Automated Releases

Releases are triggered automatically when you push a version tag:

```bash
# Create and push a release tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

This triggers a GitHub Action that:

- Builds multi-architecture images (amd64 and arm64)
- Pushes to Docker Hub with semantic version tags
- Updates Docker Hub description with README content

[⬆️ Back to top](#-table-of-contents)

---

## 🛠️ Development and Testing

### Building

```bash
docker build -t docker-cleaner .
```

### Testing

docker-cleaner includes a comprehensive testing framework that validates
cleanup operations across different execution contexts:

- **Local Script Testing**: Test cleanup script directly in terminal
- **Container Testing**: Test docker-cleaner Docker image on local host
- **Remote Context Testing**: Test docker-cleaner on remote Docker hosts

#### Quick Testing

```bash
# Run complete test suite (local + container + remote)
./tests/99-run-all-tests.sh

# Run only local script tests
./tests/99-run-all-tests.sh --only-local

# Run only container tests
./tests/99-run-all-tests.sh --only-container

# Run specific test types
./tests/11-test-local-cleanup.sh           # Local script testing
./tests/12-test-container-cleanup.sh       # Container testing
./tests/13-test-remote-contexts.sh         # Remote context testing

# Test with different configurations
./tests/11-test-local-cleanup.sh --prune-all --prune-volumes
./tests/11-test-local-cleanup.sh --dry-run

# Test on specific Docker context
./tests/99-run-all-tests.sh --context remote-nas
```

#### Test Resource Management

```bash
# Create test resources for manual testing
./tests/01-setup-test-resources.sh

# Cleanup test resources
./tests/03-cleanup-test-resources.sh

# Validate cleanup operations
./tests/02-validate-cleanup.sh --before  # Before cleanup
./tests/02-validate-cleanup.sh --after   # After cleanup
```

For detailed testing documentation, see
[docs/testing-guide.md](docs/testing-guide.md).

**Note**: All test resources are labeled with `test-cleanup=true` to ensure
production resources are never affected.

[⬆️ Back to top](#-table-of-contents)

---

## 🔍 Troubleshooting

### Socket Not Found

```text
ERROR: Docker socket not found at /var/run/docker.sock
```

**Solution**: Ensure volume is mounted:
`-v /var/run/docker.sock:/var/run/docker.sock`

### Cannot Connect to Docker Daemon

```text
ERROR: Cannot connect to Docker daemon
```

**Solutions**:

1. Verify Docker daemon is running: `docker info`
2. Check socket permissions: `ls -l /var/run/docker.sock`
3. Verify GID matching succeeded (check logs)

### All Operations Disabled

```text
ERROR: All cleanup operations are disabled - nothing to do
```

**Solution**: Enable at least one cleanup operation via environment variables

### More Help

For issues and questions:

- 🐛 [Open an issue on GitHub](https://github.com/rinzlerfr/docker-cleaner/issues)
- 📖 Check existing issues for solutions
- 🔍 Review logs with `LOG_LEVEL=DEBUG`

[⬆️ Back to top](#-table-of-contents)

---

## 🤝 Contributing

Contributions welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for
guidelines.

### Development Roadmap

See the proposal document for future enhancements:
[openspec/changes/implement-docker-cleanup-container/proposal.md](openspec/changes/implement-docker-cleanup-container/proposal.md)

[⬆️ Back to top](#-table-of-contents)

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 🌟 Support

If you find this project useful, please consider:

- ⭐ Starring the repository
- 🐛 Reporting issues
- 📝 Contributing improvements
- 📢 Sharing with others

---

Made with ❤️ for DevOps engineers tired of disk space alerts

[![GitHub](https://img.shields.io/badge/github-%23121011.svg?logo=github&logoColor=white)](https://github.com/rinzlerfr/docker-cleaner)
[![Docker Hub](https://img.shields.io/badge/docker%20hub-%230db7ed.svg?logo=docker&logoColor=white)](https://hub.docker.com/r/rinzlerfr/docker-cleaner)

[Report Bug](https://github.com/rinzlerfr/docker-cleaner/issues) ·
[Request Feature](https://github.com/rinzlerfr/docker-cleaner/issues) ·
[Contribute](CONTRIBUTING.md)
