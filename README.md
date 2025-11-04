# Docker Cleanup Container

Automated Docker cleanup container that reclaims disk space by removing unused containers, images, volumes, networks, and build cache. Designed for one-shot execution with secure, non-privileged access to Docker daemon.

## Features

- **Automated Cleanup**: Execute comprehensive Docker prune operations at startup
- **One-Shot Execution**: Container runs cleanup and exits automatically, perfect for cron scheduling
- **Local Execution**: Mounts local `/var/run/docker.sock` and cleans the Docker daemon of the host where it executes
- **Security First**: Docker socket GID matching for non-root access without `--privileged` mode
- **Highly Configurable**: Environment variables for all operations, filters, and logging
- **Multi-Host Support**: Use Docker contexts to manage cleanup across multiple hosts
- **Safe Defaults**: Conservative settings protect critical resources

## Quick Start

### Basic Usage

```bash
# Build the image
docker build -t docker-cleaner .

# 1. COMPLETE CLEANUP - Cleans EVERYTHING (recommended)
# Removes: stopped containers, unused images, unused volumes, networks, cache
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -e PRUNE_ALL=true \
  -e PRUNE_VOLUMES=true \
  -e CLEANUP_VOLUMES=true \
  docker-cleaner

# 2. Preview with DRY-RUN mode (test before cleaning)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -e PRUNE_ALL=true \
  -e PRUNE_VOLUMES=true \
  -e CLEANUP_VOLUMES=true \
  -e DRY_RUN=true \
  docker-cleaner

# 3. Conservative cleanup (default - volumes protected)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner
```

### Using Docker Compose

```bash
# FULL CLEANUP - Cleans EVERYTHING (recommended)
docker-compose --profile full up docker-cleaner-full

# Default cleanup (conservative - volumes protected)
docker-compose up docker-cleaner

# Dry-run mode (preview without deletion)
docker-compose --profile dryrun up docker-cleaner-dryrun

# Conservative cleanup
docker-compose --profile conservative up docker-cleaner-conservative

# Aggressive cleanup (use with caution)
docker-compose --profile aggressive up docker-cleaner-aggressive
```

### Shell Scripts

#### Complete cleanup (1 pass)

```bash
# Complete cleanup in one pass
./examples/cleanup-all.sh

# Test with dry-run
DRY_RUN=true ./examples/cleanup-all.sh
```

#### Complete guaranteed cleanup (2 passes)

To remove ALL unused resources, including orphaned images:

```bash
# Cleanup in 2 passes (recommended for maximum cleanup)
./examples/cleanup-complete.sh

# Test with dry-run
DRY_RUN=true ./examples/cleanup-complete.sh
```

The first pass removes containers, volumes, networks, and build cache. The second pass removes images that became orphaned after container deletion.

## Cleanup Levels

### 🔥 FULL CLEANUP (Recommended)

Cleans **EVERYTHING** except running containers and volumes in use:

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -e PRUNE_ALL=true \
  -e PRUNE_VOLUMES=true \
  -e CLEANUP_VOLUMES=true \
  docker-cleaner
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

⚠️ **Important note**: Docker checks image usage AT THE TIME of pruning. If you have stopped containers that are removed by cleanup, their base images remain because they were referenced at the time of verification. To remove these orphaned images, simply run docker-cleaner a second time.

### 🛡️ Conservative (Default)

Conservative cleanup that protects volumes:

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner
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

## Configuration

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
| `PRUNE_FILTER_UNTIL` | _(none)_ | Remove resources older than duration (e.g., `24h`, `168h`) |
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

## Use Cases

### Use Case 1: Local Mac Cleanup

```bash
# One-time cleanup
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner

# Weekly cron job
0 2 * * 0 docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner
```

### Use Case 2: Remote NAS Cleanup

```bash
# Switch to NAS context
docker context use nas

# Run cleanup (executes on NAS, cleans NAS Docker)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner

# Switch back
docker context use default
```

### Use Case 3: CI/CD Pipeline Cleanup

#### GitLab CI

```yaml
cleanup:
  stage: post-build
  script:
    - docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner
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
            docker-cleaner
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
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner
done
docker context use default
```

## How It Works

### Local Execution Principle

⚠️ **IMPORTANT**: The container **always runs on the host to be cleaned** - it never connects to remote hosts.

When you use Docker contexts (e.g., `docker context use nas`), the Docker client on your machine sends the `docker run` command to the remote daemon, which then executes the container locally on that host. The volume mount `/var/run/docker.sock:/var/run/docker.sock` is interpreted by the execution host's daemon, not your client machine.

**In other words**: If you run this container while in NAS context, the container runs ON the NAS and mounts the NAS's socket, cleaning the NAS's Docker resources. Your client machine only displays the output.

### Docker Socket GID Matching

Instead of requiring `--privileged` mode, the container uses dynamic GID matching:

1. Detect GID of `/var/run/docker.sock` at startup
2. Create or reuse group with matching GID
3. Add non-root user to this group
4. Execute cleanup operations as non-root user with Docker access

This provides secure, non-root access to the Docker daemon without privileged mode.

## Exit Codes

- `0`: Success (all operations succeeded)
- `1`: Partial failure (some operations failed, some succeeded)
- `2`: Complete failure (cannot connect to Docker or all operations failed)

## Examples

### Conservative Cleanup (Safe)

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -e PRUNE_ALL=false \
  -e PRUNE_VOLUMES=false \
  -e PRUNE_FILTER_UNTIL=720h \
  docker-cleaner
```

### Aggressive Cleanup (Use with Caution)

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -e PRUNE_ALL=true \
  -e PRUNE_VOLUMES=true \
  -e PRUNE_FILTER_UNTIL=24h \
  docker-cleaner
```

### Cleanup with Label Protection

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -e PRUNE_FILTER_LABEL="keep!=true" \
  docker-cleaner
```

### JSON Logging for SIEM Integration

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -e LOG_FORMAT=json \
  docker-cleaner
```

### Debug Mode

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -e LOG_LEVEL=DEBUG \
  docker-cleaner
```

## Security Considerations

### Risks

⚠️ **WARNING**: Mounting `docker.sock` grants **equivalent root access** to the host.

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

✅ Scheduled cleanup on development/staging hosts
✅ CI/CD pipeline cleanup after builds
✅ Manual cleanup on production (with caution and dry-run first)
❌ Untrusted hosts
❌ Multi-tenant environments without isolation

## Troubleshooting

### Socket Not Found

```
ERROR: Docker socket not found at /var/run/docker.sock
```

**Solution**: Ensure volume is mounted: `-v /var/run/docker.sock:/var/run/docker.sock`

### Cannot Connect to Docker Daemon

```
ERROR: Cannot connect to Docker daemon
```

**Solutions**:
1. Verify Docker daemon is running: `docker info`
2. Check socket permissions: `ls -l /var/run/docker.sock`
3. Verify GID matching succeeded (check logs)

### All Operations Disabled

```
ERROR: All cleanup operations are disabled - nothing to do
```

**Solution**: Enable at least one cleanup operation via environment variables

## Performance Characteristics

Expected execution times vary based on resource count:

| Resource Count | Estimated Time |
|----------------|----------------|
| Small (<50) | ~30 seconds |
| Medium (50-200) | ~1 minute |
| Large (200-1000) | ~2 minutes |
| Very Large (>1000) | ~4 minutes |

Memory usage: ~50MB peak

## Docker Hub

The docker-cleaner image is automatically published to Docker Hub with each release:

```bash
# Pull latest version
docker pull <your-dockerhub-username>/docker-cleaner:latest

# Pull specific version
docker pull <your-dockerhub-username>/docker-cleaner:v1.0.0

# Run from Docker Hub
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  <your-dockerhub-username>/docker-cleaner:latest
```

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

### Required Docker Hub Setup

Before the first automated release, you must:

1. **Create the Docker Hub repository** (one-time setup):
   - Go to https://hub.docker.com/
   - Click "Create Repository"
   - Name: `docker-cleaner`
   - Visibility: Public (or Private if you have a paid plan)
   - Click "Create"

2. **Add GitHub Secrets** to your repository (Settings > Secrets and variables > Actions):
   - `DOCKERHUB_USERNAME`: Your Docker Hub username
   - `DOCKERHUB_TOKEN`: Docker Hub access token (generate at hub.docker.com/settings/security)

   Note: The token needs write permissions to push images.

## Development

### Building

```bash
docker build -t docker-cleaner .
```

### Testing

docker-cleaner includes a comprehensive testing framework that validates cleanup operations across different execution contexts:

- **Local Script Testing**: Test cleanup script directly in terminal
- **Container Testing**: Test docker-cleaner Docker image on local host
- **Remote Context Testing**: Test docker-cleaner on remote Docker hosts via contexts

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

For detailed testing documentation, see [docs/testing-guide.md](docs/testing-guide.md).

**Note**: All test resources are labeled with `test-cleanup=true` to ensure production resources are never affected.

## License

MIT License - see LICENSE file for details

## Contributing

Contributions welcome! Please read CONTRIBUTING.md for guidelines.

## Support

For issues and questions:
- Open an issue on GitHub
- Check existing issues for solutions
- Review logs with `LOG_LEVEL=DEBUG`

## Roadmap

See [openspec/changes/implement-docker-cleanup-container/proposal.md](openspec/changes/implement-docker-cleanup-container/proposal.md) for future enhancements.

---

**Made with ❤️ for DevOps engineers tired of disk space alerts**
