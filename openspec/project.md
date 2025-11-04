# Project Context: Docker Cleanup Container

## Purpose
Automated Docker cleanup container that reclaims disk space by removing unused containers, images, volumes, networks, and build cache. Designed for local execution on each Docker host, using Docker socket GID matching for secure non-root access. Deployable via Docker contexts for managing multiple hosts.

## Tech Stack
- **Base Image**: docker:cli-alpine (minimal Docker CLI image)
- **Runtime**: Bash scripting for orchestration
- **Communication**: Local Docker socket (`/var/run/docker.sock`)
- **Authentication**: Docker socket GID matching (dynamic group membership)
- **Deployment**: Docker container (one-shot execution pattern)
- **Testing**: bats (Bash Automated Testing System), Docker-in-Docker
- **CI/CD**: GitHub Actions or GitLab CI with Trivy security scanning

## Project Conventions

### Code Style
- Bash scripts follow Google Shell Style Guide
- Functions use lowercase with underscores (snake_case)
- Constants use UPPERCASE
- 2-space indentation
- Use shellcheck for linting
- Comments explain "why" not "what"
- Error handling: use `set -euo pipefail` in all scripts

### Architecture Patterns
- **One-Shot Container**: Execute task and exit immediately
- **Orchestrator Pattern**: Main script coordinates sub-operations
- **Fail-Safe**: Continue on individual operation failure, aggregate results
- **Least Privilege**: Non-root container user, Docker socket GID matching, no --privileged
- **Local Execution**: Container runs on target host and cleans that host's Docker

### Testing Strategy
- **Unit Tests**: Test individual bash functions with bats
- **Integration Tests**: End-to-end cleanup scenarios in Docker-in-Docker
- **Resource Creation**: Automated creation of test containers, images, volumes, networks
- **Security Tests**: Validate GID matching, permission model, protection mechanisms
- **Manual Testing**: Real-world validation on Linux, macOS, NAS devices
- **Coverage Target**: >80% for critical paths

### Git Workflow
- **Branching**: feature/* branches for new capabilities
- **Commits**: Conventional Commits format (feat:, fix:, docs:, test:, refactor:)
- **PR Process**: All changes via pull request with CI validation
- **Tagging**: Semantic versioning (vMAJOR.MINOR.PATCH)

## Domain Context

### Docker Resource Types
- **Containers**: Running or stopped processes
- **Images**: Templates for containers (can be tagged or dangling)
- **Volumes**: Persistent data storage
- **Networks**: Communication channels between containers
- **Build Cache**: Intermediate layers from image builds

### Docker Prune Commands
- `docker container prune`: Remove stopped containers
- `docker image prune`: Remove dangling images (or all unused with --all)
- `docker volume prune`: Remove unused volumes
- `docker network prune`: Remove unused networks
- `docker builder prune`: Remove build cache
- `docker system prune`: Comprehensive cleanup (optionally includes volumes)

### Docker Socket GID Matching
- Docker socket is owned by `root:docker` on most systems
- Socket permissions are typically `660` (rw-rw----)
- GID of docker group varies across hosts (commonly 999, 998, 102, etc.)
- Dynamic GID detection at runtime ensures portability
- Non-root user added to docker group via `usermod -aG`
- No --privileged flag required (more secure than privileged mode)

## Important Constraints

### Security Constraints
- MUST NOT run as root in container
- MUST NOT require --privileged flag
- MUST use Docker socket GID matching for access
- MUST protect critical resources from accidental deletion
- MUST provide audit trail for all operations
- MUST document Docker socket mounting risks

### Local Execution Constraints
- Container MUST mount `/var/run/docker.sock` from host
- Container MUST execute on the host to be cleaned
- Docker daemon MUST be running on target host
- Docker socket MUST be accessible and have appropriate permissions

### Operational Constraints
- Container MUST exit after cleanup completion (no persistent processes)
- Container MUST exit with appropriate codes: 0 (success), 1 (partial), 2 (failure)
- Operations MUST be idempotent (safe to re-run)
- Protected resources MUST NOT be removed (running containers, labeled resources)

### Performance Constraints
- Execution time depends on resource count (typically <5 minutes)
- Image size must be minimal (<50MB)
- Memory usage should be reasonable (<128MB)

## External Dependencies

### Required on Target Host
- **Docker Daemon**: Must be running and accessible
- **Docker Socket**: Must exist at `/var/run/docker.sock` (or configured path)
- **Docker Socket Permissions**: Must allow GID-based access (typically 660)

### Optional Dependencies
- **Docker Contexts**: For managing multiple remote Docker hosts
- **Monitoring Systems**: For log aggregation (JSON format support)
- **Orchestration**: Kubernetes CronJobs, Docker Compose, or plain Docker for deployment

## Risk Mitigation

### Data Loss Risks
- **Risk**: Accidental deletion of important volumes or images
- **Mitigation**: Conservative defaults (volumes not pruned by default), label-based protection, dry-run mode, explicit opt-in for aggressive cleanup

### Security Risks
- **Risk**: Docker socket access grants equivalent root privileges on host
- **Mitigation**:
  - Non-root user in container (UID 1000)
  - No --privileged flag required
  - Comprehensive audit logging
  - Resource protection mechanisms
  - Documentation of risks and trust model
  - Trusted container images only

### Operational Risks
- **Risk**: Cleanup interferes with running workloads
- **Mitigation**: Protected resource detection, running container safety checks, dry-run preview mode

### Portability Risks
- **Risk**: GID varies across different Linux distributions
- **Mitigation**: Dynamic GID detection and matching at runtime

## Use Case Patterns

### Pattern 1: Local Workstation Cleanup
```bash
# One-time cleanup
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner

# Scheduled via cron
0 2 * * 0 docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner
```

### Pattern 2: Multi-Host Management via Docker Contexts
```bash
# Define contexts
docker context create nas --docker "host=ssh://nas.local"
docker context create dev --docker "host=ssh://dev-server"

# Cleanup each host
for ctx in default nas dev; do
  docker context use $ctx
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner
done
docker context use default
```

### Pattern 3: CI/CD Integration
```yaml
# GitLab CI
cleanup:
  stage: post-build
  script:
    - docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner
```

### Pattern 4: Kubernetes CronJob
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: docker-cleaner
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: docker-cleaner
            image: docker-cleaner:latest
            volumeMounts:
            - name: docker-sock
              mountPath: /var/run/docker.sock
          volumes:
          - name: docker-sock
            hostPath:
              path: /var/run/docker.sock
          restartPolicy: OnFailure
```

## Configuration Philosophy

### Environment-Based Configuration
All configuration via environment variables (no config files in v1):
- Simple deployment (12-factor app principles)
- Docker-native configuration method
- No volume mounts for config required
- Easy integration with orchestration platforms

### Safe Defaults
- Volumes NOT pruned by default (`PRUNE_VOLUMES=false`)
- Only dangling images removed (`PRUNE_ALL=false`)
- Running containers always protected
- Force mode enabled for non-interactive use (`PRUNE_FORCE=true`)

### Explicit Opt-In for Aggressive Operations
Users must explicitly enable:
- Volume pruning (`PRUNE_VOLUMES=true`)
- All unused image pruning (`PRUNE_ALL=true`)
- Stopping containers before removal (future feature)

## Development Workflow

### Local Development Setup
```bash
# Clone repository
git clone https://github.com/user/docker-cleaner.git
cd docker-cleaner

# Build image
docker build -t docker-cleaner:dev .

# Test locally
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -e DRY_RUN=true docker-cleaner:dev

# Run tests
docker run --rm docker-cleaner:dev bats tests/
```

### Testing Workflow
1. Unit tests run on every commit
2. Integration tests run in Docker-in-Docker environment
3. Security scans run before merge
4. Manual testing on target platforms before release

## Documentation Standards

### Required Documentation
- README.md: Project overview, quick start, examples
- docs/deployment-guide.md: Detailed deployment scenarios
- docs/security.md: Threat model, mitigations, best practices
- docs/configuration.md: All environment variables documented
- docs/architecture.md: System design and rationale

### Documentation Principles
- Examples over abstract explanations
- Security warnings prominently displayed
- Platform-specific notes (Linux, macOS, NAS)
- Troubleshooting guides for common issues

## Success Criteria

### Functional Requirements
- ✅ Cleans all Docker resource types
- ✅ One-shot execution (starts, cleans, exits)
- ✅ Works without --privileged flag
- ✅ Configurable via environment variables
- ✅ Dry-run mode for preview

### Non-Functional Requirements
- ✅ Image size < 50MB
- ✅ Execution time < 5 minutes (typical workloads)
- ✅ Memory usage < 128MB
- ✅ Works on Linux, macOS, NAS devices
- ✅ No HIGH/CRITICAL vulnerabilities

### Quality Requirements
- ✅ >80% test coverage
- ✅ All automated tests pass
- ✅ Comprehensive documentation
- ✅ Security reviewed and documented

## Future Vision

### v2.0 Enhancements
- Built-in scheduling (internal cron)
- Webhook notifications (Slack, email)
- Prometheus metrics export
- Multi-host parallel cleanup
- Python rewrite for better error handling

### v3.0 Advanced Features
- Web UI for management
- Smart cleanup (ML-based predictions)
- Cost-based cleanup strategies
- Advanced filtering and retention policies
- Multi-platform support (Kubernetes operators, Nomad)
