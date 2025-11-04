# Design Document: Docker Cleanup Container

## Architecture Overview

### Core Components

```
┌─────────────────────────────────────────────────┐
│         Docker Cleanup Container                │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │      Entrypoint Script                   │  │
│  │  - Detect docker.sock GID                │  │
│  │  - Create/reuse docker group             │  │
│  │  - Add user to group                     │  │
│  │  - Verify Docker access                  │  │
│  └──────────────────────────────────────────┘  │
│                     │                           │
│                     ▼                           │
│  ┌──────────────────────────────────────────┐  │
│  │      Cleanup Orchestrator                │  │
│  │  - Parse configuration                   │  │
│  │  - Execute cleanup sequence              │  │
│  │  - Log operations                        │  │
│  │  - Handle errors                         │  │
│  └──────────────────────────────────────────┘  │
│                     │                           │
│                     ▼                           │
│  ┌──────────────────────────────────────────┐  │
│  │      Docker Prune Executor               │  │
│  │  - container prune                       │  │
│  │  - image prune                           │  │
│  │  - volume prune                          │  │
│  │  - network prune                         │  │
│  │  - build cache prune                     │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
                     │
                     │ Unix Socket
                     │ /var/run/docker.sock
                     ▼
┌─────────────────────────────────────────────────┐
│         Local Docker Host                       │
│  - Docker daemon                                │
│  - docker.sock (GID: docker group)             │
└─────────────────────────────────────────────────┘
```

## Local Socket Access Strategy

### Docker Socket GID Matching Approach

**Why GID Matching?**
- Docker socket is owned by root:docker on most systems
- Socket has permissions 660 (rw-rw----)
- Non-root user needs to be member of docker group to access
- GID of docker group varies across hosts (often 999, 998, or other)
- Dynamic GID detection allows portability across different hosts

**Implementation Steps:**

1. **Startup Detection** (entrypoint.sh)
```bash
#!/bin/bash
set -euo pipefail

# Detect docker socket GID
DOCKER_SOCKET=/var/run/docker.sock
if [ ! -S "$DOCKER_SOCKET" ]; then
    echo "ERROR: Docker socket not found at $DOCKER_SOCKET"
    exit 2
fi

DOCKER_GID=$(stat -c '%g' "$DOCKER_SOCKET")
echo "INFO: Detected docker.sock GID: $DOCKER_GID"

# Check if group with this GID already exists
EXISTING_GROUP=$(getent group "$DOCKER_GID" | cut -d: -f1 || echo "")

if [ -n "$EXISTING_GROUP" ]; then
    echo "INFO: Group with GID $DOCKER_GID already exists: $EXISTING_GROUP"
    DOCKER_GROUP="$EXISTING_GROUP"
else
    echo "INFO: Creating docker group with GID $DOCKER_GID"
    groupadd -g "$DOCKER_GID" docker
    DOCKER_GROUP="docker"
fi

# Add cleanup user to docker group
echo "INFO: Adding user cleanup-user to group $DOCKER_GROUP"
usermod -aG "$DOCKER_GROUP" cleanup-user

# Verify Docker access
echo "INFO: Verifying Docker daemon connectivity"
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Cannot connect to Docker daemon"
    exit 2
fi

echo "INFO: Docker access verified, starting cleanup operations"
exec gosu cleanup-user /app/cleanup.sh "$@"
```

2. **Dockerfile Setup**
```dockerfile
FROM docker:cli-alpine

# Install required packages
RUN apk add --no-cache bash gosu shadow

# Create non-root user
RUN adduser -D -u 1000 -s /bin/bash cleanup-user

# Copy scripts
COPY entrypoint.sh /entrypoint.sh
COPY src/cleanup.sh /app/cleanup.sh
COPY src/logger.sh /app/logger.sh

# Set permissions
RUN chmod +x /entrypoint.sh /app/cleanup.sh

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD []
```

3. **Runtime Deployment**
```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e PRUNE_ALL=false \
  -e PRUNE_VOLUMES=false \
  docker-cleaner:latest
```

### Security Implications

**Risks:**
- Mounting docker.sock grants **equivalent root access** to the host
- Container can start new containers, including privileged ones
- Container can mount any host path
- Container can read/write all Docker resources

**Mitigations:**
1. **Least Privilege Execution**
   - Non-root user in container (UID 1000)
   - No --privileged flag required
   - Dropped capabilities (using default Docker security)

2. **Resource Protection**
   - Label-based filters to protect critical resources
   - Running container protection (Docker's default)
   - Volume-in-use protection (Docker's default)

3. **Audit Trail**
   - Comprehensive logging of all operations
   - Immutable logs (stdout/stderr)
   - Structured logging for SIEM integration

4. **Operational Controls**
   - Conservative defaults (no volumes, no all images)
   - Explicit opt-in for aggressive cleanup
   - Dry-run mode for preview

5. **Trust Model**
   - Container image must be from trusted source
   - Only run on hosts you control
   - Review logs regularly

**Acceptable Use:**
- Scheduled cleanup on development/staging hosts
- CI/CD pipeline cleanup after builds
- Manual cleanup on production (with caution and dry-run first)

## Understanding Docker Contexts and Multi-Host Management

### What are Docker Contexts?

Docker contexts allow your **local Docker client** to manage multiple Docker daemons (local and remote) without the container needing to know anything about it.

**Key Principle:** The container is "context-agnostic" - it always thinks it's running locally.

### How It Works

```
┌──────────────────────────────────────────────────────────────┐
│                    Your Mac (Client)                         │
│                                                              │
│  $ docker context list                                      │
│  NAME        DESCRIPTION                DOCKER ENDPOINT      │
│  default *   Current context           unix:///var/run/...  │
│  nas         NAS Docker                ssh://nas.local      │
│  dev         Dev server                ssh://dev-server     │
│                                                              │
│  $ docker context use nas                                   │
│  $ docker run --rm \                                        │
│      -v /var/run/docker.sock:/var/run/docker.sock \        │
│      docker-cleaner                                         │
│                                                              │
│  Docker Client routes command to NAS daemon via SSH ────┐   │
└──────────────────────────────────────────────────────────│───┘
                                                           │
                                          Command sent via SSH
                                                           │
                                                           ▼
┌──────────────────────────────────────────────────────────────┐
│                    NAS (Remote Host)                         │
│                                                              │
│  Docker Daemon receives command and executes locally        │
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │   docker-cleaner container                         │     │
│  │   (running on NAS, not on your Mac!)              │     │
│  │                                                    │     │
│  │   Mounts /var/run/docker.sock                     │     │
│  │   (which is NAS's local socket, not Mac's)        │     │
│  └────────────────────────────────────────────────────┘     │
│                          │                                   │
│                          ▼                                   │
│               /var/run/docker.sock (NAS's socket)           │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Container Perspective

From the **container's point of view**:
1. It starts up (doesn't know/care where it's running)
2. It mounts `/var/run/docker.sock` (always thinks it's local)
3. It detects the socket's GID
4. It adds its user to the docker group
5. It runs Docker prune commands
6. It exits

The container **never knows** it's cleaning a remote host. It always believes it's running locally.

### Client Perspective

From the **Docker client's point of view** (your Mac):
1. You switch context: `docker context use nas`
2. Client reads context config: "Connect to docker daemon at ssh://nas.local"
3. You run: `docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner`
4. Client translates to: "SSH to nas.local, send 'docker run ...' command"
5. NAS daemon receives command and starts container **on the NAS**
6. Volume mount `-v /var/run/docker.sock:...` is interpreted by **NAS daemon** as "mount my local socket"
7. Container executes on NAS and cleans NAS's Docker
8. Logs stream back to your Mac via SSH for display

### Why This Design is Superior

**Container Complexity:**
- ✅ Zero SSH configuration in container
- ✅ Zero TCP connection logic in container
- ✅ Zero authentication handling in container
- ✅ Zero multi-host awareness in container
- ✅ Simple: mount socket, clean, exit

**Security:**
- ✅ Uses Docker's native SSH authentication (your existing SSH keys)
- ✅ No SSH keys embedded in container image
- ✅ No exposed TCP ports
- ✅ Audit trail via SSH logs
- ✅ Standard Unix permissions

**Portability:**
- ✅ Same container works on Linux, macOS, Windows (Docker Desktop), NAS
- ✅ No platform-specific code
- ✅ No special builds or configurations

**Debugging:**
- ✅ Standard Docker logs
- ✅ Standard SSH troubleshooting if connection fails
- ✅ No custom networking or authentication to debug

### Multi-Host Management Example

```bash
#!/bin/bash
# cleanup-all-hosts.sh

HOSTS="default nas dev-server staging-server"
RESULTS=()

for ctx in $HOSTS; do
  echo "🧹 Cleaning $ctx..."
  docker context use "$ctx"

  if docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner; then
    RESULTS+=("✅ $ctx: Success")
  else
    RESULTS+=("❌ $ctx: Failed")
  fi
done

# Return to default
docker context use default

# Print summary
echo ""
echo "📊 Cleanup Summary:"
for result in "${RESULTS[@]}"; do
  echo "  $result"
done
```

Each iteration:
1. Switches context (changes target daemon)
2. Runs **same** container command
3. Container executes on **that** host
4. Cleans **that** host's Docker
5. Reports back to your Mac

### Alternative: Without Docker Contexts

If you don't want to use contexts, you can SSH manually:

```bash
# SSH to each host and run cleanup locally
ssh nas.local "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner"
ssh dev-server "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner"
```

This achieves the same result but requires manual SSH commands instead of leveraging Docker's built-in context switching.

### Important Clarification: Volume Mounts are Host-Relative

**Common Misconception:**
"If I run `docker run -v /var/run/docker.sock:...` on my Mac while targeting NAS context, won't it mount Mac's socket?"

**Reality:**
No! Volume mount paths are **always interpreted by the daemon where the container runs**, not the client.

- Client (Mac): `docker context use nas && docker run -v /path:...`
- Daemon (NAS): Receives command, interprets `/path` as path on **NAS filesystem**
- Container: Runs on NAS, sees NAS's `/path`

This is fundamental Docker behavior - volume mounts are relative to the **execution host**, not the **client host**.

## Configuration Design

### Environment Variables

**Core Configuration:**
```bash
# Docker Host (usually default)
DOCKER_HOST=unix:///var/run/docker.sock  # Default, can use tcp://host:port

# Cleanup Operations
PRUNE_ALL=false                 # Remove all unused images (not just dangling)
PRUNE_VOLUMES=false             # Include volumes in cleanup
PRUNE_FORCE=true                # Skip confirmation prompts

# Selective Operations
CLEANUP_CONTAINERS=true         # Prune containers
CLEANUP_IMAGES=true             # Prune images
CLEANUP_VOLUMES=false           # Prune volumes
CLEANUP_NETWORKS=true           # Prune networks
CLEANUP_BUILD_CACHE=true        # Prune build cache

# Filters
PRUNE_FILTER_UNTIL=24h          # Remove resources older than duration
PRUNE_FILTER_LABEL=keep!=true   # Filter by label

# Logging
LOG_LEVEL=INFO                  # DEBUG, INFO, WARN, ERROR
LOG_FORMAT=text                 # text or json
QUIET=false                     # Minimal output

# Dry-Run
DRY_RUN=false                   # Preview without deleting
```

### Docker Compose Example

```yaml
version: '3.8'

services:
  docker-cleaner:
    image: docker-cleaner:latest
    container_name: docker-cleaner
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - PRUNE_ALL=false
      - PRUNE_VOLUMES=false
      - PRUNE_FILTER_UNTIL=168h  # 7 days
      - LOG_LEVEL=INFO
    restart: "no"  # One-shot execution
```

## Cleanup Sequence

### Execution Order (Optimized for Dependencies)

The cleanup operations are executed in a specific order to handle dependencies correctly:

1. **Container Prune** - Remove stopped containers first
   - Freed resources: disk space from container filesystems
   - Dependencies: None

2. **Image Prune** - Remove dangling/unused images
   - Freed resources: image layers
   - Dependencies: Requires containers to be removed first

3. **Volume Prune** - Remove unused volumes
   - Freed resources: volume data
   - Dependencies: Volumes in use by containers are protected

4. **Network Prune** - Remove unused networks
   - Freed resources: network metadata (minimal)
   - Dependencies: Networks with connected containers are protected

5. **Build Cache Prune** - Remove build cache
   - Freed resources: intermediate build layers
   - Dependencies: None

### Error Handling Strategy

**Philosophy:** Fail gracefully, continue operations

```bash
# Pseudo-code
exit_code=0
operations_succeeded=0
operations_failed=0

for operation in containers images volumes networks build_cache; do
    if run_operation "$operation"; then
        operations_succeeded=$((operations_succeeded + 1))
    else
        log_error "Failed: $operation"
        operations_failed=$((operations_failed + 1))
        exit_code=1  # Partial failure
    fi
done

if [ $operations_succeeded -eq 0 ]; then
    exit_code=2  # Complete failure
fi

exit $exit_code
```

**Exit Codes:**
- `0`: Success (all operations succeeded)
- `1`: Partial failure (some operations failed, some succeeded)
- `2`: Complete failure (cannot connect to Docker or all operations failed)

## Logging and Observability

### Logging Architecture

**Log Levels:**
- `DEBUG`: Detailed operation traces, Docker command output
- `INFO`: Normal operations, space freed, summaries
- `WARN`: Protected resources skipped, non-fatal errors
- `ERROR`: Operation failures, connection errors

**Log Formats:**

**Text Format (Human-Readable):**
```
[2025-10-23T16:00:00Z] [INFO] [INIT] Starting Docker cleanup on localhost
[2025-10-23T16:00:01Z] [INFO] [CONTAINER] Removed 5 stopped containers (1.2 GB freed)
[2025-10-23T16:00:03Z] [INFO] [IMAGE] Removed 12 dangling images (3.5 GB freed)
[2025-10-23T16:00:05Z] [WARN] [VOLUME] Skipped volume xyz: in use by container abc
[2025-10-23T16:00:10Z] [INFO] [SUMMARY] Total space freed: 8.7 GB
```

**JSON Format (Machine-Parseable):**
```json
{"timestamp":"2025-10-23T16:00:00Z","level":"INFO","operation":"INIT","message":"Starting Docker cleanup","hostname":"localhost"}
{"timestamp":"2025-10-23T16:00:01Z","level":"INFO","operation":"CONTAINER","message":"Removed stopped containers","count":5,"space_freed_bytes":1288490188}
{"timestamp":"2025-10-23T16:00:03Z","level":"INFO","operation":"IMAGE","message":"Removed dangling images","count":12,"space_freed_bytes":3758096384}
```

### Metrics Tracked

Per Operation:
- Resources removed (count)
- Space freed (bytes)
- Execution duration (seconds)
- Success/failure status

Summary:
- Total resources removed (by type)
- Total space freed
- Total execution time
- Operations succeeded/failed count

## Entrypoint Script Design

### Detailed Flow

```bash
#!/bin/bash
# entrypoint.sh - Setup Docker socket access and run cleanup

set -euo pipefail

# Function: Log with timestamp
log() {
    local level="$1"
    shift
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [$level] $*"
}

# Function: Exit with error
die() {
    log "ERROR" "$@"
    exit 2
}

# Step 1: Validate Docker socket exists
DOCKER_SOCKET="${DOCKER_SOCKET:-/var/run/docker.sock}"
if [ ! -S "$DOCKER_SOCKET" ]; then
    die "Docker socket not found at $DOCKER_SOCKET. Ensure volume is mounted: -v /var/run/docker.sock:/var/run/docker.sock"
fi
log "INFO" "Docker socket found at $DOCKER_SOCKET"

# Step 2: Detect socket GID
DOCKER_GID=$(stat -c '%g' "$DOCKER_SOCKET")
log "INFO" "Detected docker.sock GID: $DOCKER_GID"

# Step 3: Handle group creation/reuse
EXISTING_GROUP=$(getent group "$DOCKER_GID" | cut -d: -f1 || echo "")
if [ -n "$EXISTING_GROUP" ]; then
    log "INFO" "Group with GID $DOCKER_GID already exists: $EXISTING_GROUP (reusing)"
    DOCKER_GROUP="$EXISTING_GROUP"
else
    log "INFO" "Creating docker group with GID $DOCKER_GID"
    if ! groupadd -g "$DOCKER_GID" docker 2>/dev/null; then
        die "Failed to create docker group with GID $DOCKER_GID"
    fi
    DOCKER_GROUP="docker"
fi

# Step 4: Add cleanup user to docker group
CLEANUP_USER="${CLEANUP_USER:-cleanup-user}"
log "INFO" "Adding user $CLEANUP_USER to group $DOCKER_GROUP"
if ! usermod -aG "$DOCKER_GROUP" "$CLEANUP_USER"; then
    die "Failed to add $CLEANUP_USER to $DOCKER_GROUP group"
fi

# Step 5: Verify group membership
if ! groups "$CLEANUP_USER" | grep -q "$DOCKER_GROUP"; then
    die "User $CLEANUP_USER is not in $DOCKER_GROUP group after usermod"
fi
log "INFO" "User $CLEANUP_USER successfully added to $DOCKER_GROUP group"

# Step 6: Verify Docker daemon connectivity (as cleanup user)
log "INFO" "Verifying Docker daemon connectivity"
if ! gosu "$CLEANUP_USER" docker info > /dev/null 2>&1; then
    die "Cannot connect to Docker daemon. Check socket permissions and Docker daemon status"
fi
log "INFO" "Docker daemon connectivity verified"

# Step 7: Execute cleanup script as non-root user
log "INFO" "Starting cleanup operations as $CLEANUP_USER"
exec gosu "$CLEANUP_USER" /app/cleanup.sh "$@"
```

### Error Scenarios and Handling

| Error | Detection | Response | Exit Code |
|-------|-----------|----------|-----------|
| Socket not found | `[ ! -S $DOCKER_SOCKET ]` | Log error, suggest volume mount | 2 |
| GID detection fails | `stat` returns error | Log error, cannot proceed | 2 |
| Group creation fails | `groupadd` returns error | Log error, GID conflict | 2 |
| usermod fails | `usermod` returns error | Log error, permission issue | 2 |
| Docker info fails | `docker info` returns error | Log error, daemon not accessible | 2 |

## Testing Architecture

### Docker-in-Docker Test Environment

For isolated integration testing:

```yaml
# docker-compose.test.yml
version: '3.8'

services:
  dind:
    image: docker:dind
    privileged: true
    environment:
      DOCKER_TLS_CERTDIR: ""
    networks:
      - test-network

  test-runner:
    image: docker-cleaner:test
    depends_on:
      - dind
    environment:
      DOCKER_HOST: tcp://dind:2375
      CLEANUP_CONTAINERS: "true"
      CLEANUP_IMAGES: "true"
    volumes:
      - ./tests:/tests
    command: /tests/run-integration-tests.sh
    networks:
      - test-network

networks:
  test-network:
```

### Test Resource Creation

**Container Creation:**
```bash
# Create running containers
docker run -d --name test-cleanup-container-running-1 --label test-cleanup=true alpine:latest sleep infinity
docker run -d --name test-cleanup-container-running-2 --label test-cleanup=true alpine:latest sleep infinity

# Create stopped containers
docker create --name test-cleanup-container-stopped-1 --label test-cleanup=true alpine:latest
docker create --name test-cleanup-container-stopped-2 --label test-cleanup=true alpine:latest
```

**Image Creation:**
```bash
# Tagged images
docker tag alpine:latest test-cleanup-image:v1
docker tag alpine:latest test-cleanup-image:v2

# Dangling images (build, retag to make original dangling)
docker build -t test-cleanup-temp:latest -f - . <<EOF
FROM alpine:latest
RUN echo "test layer 1" > /tmp/test1
EOF

docker build -t test-cleanup-temp:latest -f - . <<EOF
FROM alpine:latest
RUN echo "test layer 2" > /tmp/test2
EOF
# First build is now dangling
```

**Volume Creation:**
```bash
# Used volumes
docker volume create test-cleanup-volume-used-1
docker run -d --name vol-user-1 -v test-cleanup-volume-used-1:/data alpine:latest sleep infinity

# Unused volumes
docker volume create test-cleanup-volume-unused-1
docker volume create test-cleanup-volume-unused-2
```

**Network Creation:**
```bash
# Used networks
docker network create test-cleanup-network-used-1
docker run -d --name net-user-1 --network test-cleanup-network-used-1 alpine:latest sleep infinity

# Unused networks
docker network create test-cleanup-network-unused-1
docker network create test-cleanup-network-unused-2
```

## Technology Stack

### Base Image Decision

**Choice:** `docker:cli-alpine`

**Rationale:**
- Already includes Docker CLI
- Alpine Linux base (minimal size ~40MB)
- Official Docker image (trusted)
- Regular security updates

**Required Additional Packages:**
- `bash`: For scripting (Alpine ships with ash/sh only)
- `gosu`: For dropping privileges (better than su/sudo)
- `shadow`: For usermod/groupadd commands

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Docker Python SDK | Robust error handling | Requires Python runtime, larger image | Rejected |
| Docker Go client | Fast, compiled binary | Requires compilation, complexity | Rejected for v1 |
| Pure bash + Docker CLI | Simple, minimal dependencies | Limited error handling | **Accepted for v1** |

## Deployment Models

### Model 1: Cron Job on Host

```bash
# /etc/cron.daily/docker-cleanup
#!/bin/bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e PRUNE_FILTER_UNTIL=168h \
  -e LOG_LEVEL=INFO \
  docker-cleaner:latest
```

### Model 2: Docker Compose Service

```yaml
version: '3.8'

services:
  docker-cleaner:
    image: docker-cleaner:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - PRUNE_ALL=false
      - PRUNE_VOLUMES=false
    deploy:
      restart_policy:
        condition: none
```

Run with: `docker-compose up docker-cleaner`

### Model 3: Kubernetes CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: docker-cleaner
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
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
            env:
            - name: PRUNE_FILTER_UNTIL
              value: "168h"
          volumes:
          - name: docker-sock
            hostPath:
              path: /var/run/docker.sock
              type: Socket
          restartPolicy: OnFailure
```

### Model 4: CI/CD Pipeline Integration

**GitLab CI:**
```yaml
cleanup:
  stage: post-build
  image: docker-cleaner:latest
  variables:
    DOCKER_HOST: unix:///var/run/docker.sock
    PRUNE_ALL: "true"
    CLEANUP_BUILD_CACHE: "true"
  script:
    - /app/cleanup.sh
  only:
    - schedules
```

**GitHub Actions:**
```yaml
name: Docker Cleanup

on:
  schedule:
    - cron: '0 2 * * *'
  workflow_dispatch:

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Run Docker Cleanup
        run: |
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -e PRUNE_FILTER_UNTIL=168h \
            docker-cleaner:latest
```

## Trade-offs and Decisions

### GID Matching vs Pre-Configuration

| Aspect | GID Matching (Dynamic) | Pre-Configuration (Static) |
|--------|------------------------|----------------------------|
| Portability | ✓ Works on any host | ✗ Requires host-specific setup |
| Complexity | Medium (entrypoint script) | Low (just run with --user) |
| Security | Same (both non-root) | Same |
| Error Handling | Automatic fallback | Manual troubleshooting |
| **Decision** | **Primary approach** | Alternative documented |

### Privileged Mode Decision

**Question:** Should we require --privileged flag?

**Analysis:**
- Privileged mode grants full host access
- Privileged mode disables all security features
- GID matching achieves same Docker access without privileged
- Industry best practice: avoid privileged unless absolutely necessary

**Decision:** --privileged is NOT required and is strongly discouraged

### Script Language: Bash vs Python vs Go

| Language | LOC | Complexity | Dependencies | Performance |
|----------|-----|------------|--------------|-------------|
| Bash | ~300 | Low | bash, docker CLI | Fast enough |
| Python | ~500 | Medium | Python, docker SDK | Slower startup |
| Go | ~800 | High | None (compiled) | Fastest |

**Decision:** Bash for v1 (simplicity, minimal dependencies)
**Future:** Consider Python or Go for v2 if error handling needs improvement

## Performance Characteristics

### Expected Execution Times

| Resource Count | Containers | Images | Volumes | Networks | Total Time |
|----------------|------------|--------|---------|----------|------------|
| Small (<50) | <5s | <10s | <5s | <5s | ~30s |
| Medium (50-200) | <15s | <30s | <10s | <10s | ~1min |
| Large (200-1000) | <30s | <60s | <20s | <15s | ~2min |
| Very Large (>1000) | <60s | <120s | <30s | <20s | ~4min |

**Note:** Times vary significantly based on:
- Storage driver (overlay2 vs aufs)
- Disk I/O performance
- Docker daemon load
- Network latency (if using TCP DOCKER_HOST)

### Memory Requirements

- **Container:** ~20MB RSS
- **Docker CLI:** ~10MB per operation
- **Peak:** ~50MB during image prune
- **Recommended:** 128MB memory limit

### Disk I/O Impact

- Read operations: Minimal (metadata queries)
- Write operations: Metadata updates only
- Freed space: Varies by resource count
- **Best Practice:** Run during off-peak hours

## Future Enhancements

### v2.0 Planned Features

1. **Multi-Host Support**
   - Sequential cleanup across multiple Docker hosts
   - Aggregated reporting
   - Per-host configuration

2. **Scheduled Execution**
   - Built-in cron for recurring cleanup
   - Configurable schedule

3. **Webhook Notifications**
   - Slack integration
   - Email notifications
   - Custom webhooks

4. **Prometheus Metrics**
   - Cleanup duration
   - Resources removed
   - Space freed

5. **Web UI**
   - Configuration management
   - Execution history
   - Real-time logs

### v3.0 Advanced Features

1. **Smart Cleanup**
   - ML-based prediction of safe-to-delete resources
   - Usage pattern analysis
   - Recommendations engine

2. **Multi-Platform Support**
   - Kubernetes integration
   - Docker Swarm mode
   - Nomad integration

3. **Advanced Filtering**
   - Cost-based cleanup (remove most expensive first)
   - Tag-based retention policies
   - Age-based automatic cleanup

## Security Hardening Checklist

- [ ] Non-root user (UID > 1000)
- [ ] No --privileged flag
- [ ] Read-only root filesystem (where possible)
- [ ] Dropped capabilities
- [ ] GID matching for socket access
- [ ] Comprehensive audit logging
- [ ] Label-based resource protection
- [ ] Conservative defaults (no volumes)
- [ ] Dry-run mode available
- [ ] Input validation on all env vars
- [ ] No secrets in logs
- [ ] Container image signed
- [ ] Vulnerability scanning in CI
- [ ] Regular base image updates
