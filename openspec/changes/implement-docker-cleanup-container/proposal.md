# Implement Docker Cleanup Container

## Problem
Docker hosts accumulate unused containers, images, build cache, volumes, and networks over time, consuming significant disk space. Manual cleanup is error-prone, time-consuming, and often neglected, leading to disk space exhaustion on development machines, CI/CD runners, and staging environments.

## Proposed Solution
Create an automated Docker cleanup container that:
- Executes comprehensive cleanup operations at startup
- Terminates automatically after cleanup completion (one-shot execution pattern)
- Runs locally on each Docker host to be cleaned
- Implements security best practices with least-privilege access via Docker socket GID matching
- Supports deployment via Docker contexts for managing multiple hosts

## Key Requirements
1. **Automated Cleanup**: Execute Docker prune commands for all resource types (containers, images, volumes, networks, build cache)
2. **One-Shot Execution**: Container runs cleanup and exits automatically, enabling easy cron scheduling
3. **Local Execution**: Container mounts local `/var/run/docker.sock` and cleans the Docker daemon of the host where it executes
4. **Security**: Implement Docker socket GID matching for non-root access without --privileged mode
5. **Configurability**: Allow customization of cleanup filters, protection labels, and operation selection via environment variables
6. **Testing**: Comprehensive unit, integration, and E2E tests with test resource creation/validation

## Benefits
- **Automated disk space reclamation**: No more manual cleanup or disk space alerts
- **Reduced operational overhead**: Set-and-forget cron jobs or CI/CD integration
- **Safe defaults**: Conservative settings protect critical resources (running containers, labeled resources, volumes)
- **Portability**: Works on any Linux host with Docker (Mac, NAS, cloud VMs, CI runners)
- **Audit trail**: Comprehensive logging of all cleanup operations for compliance
- **Multi-host management**: Use Docker contexts to deploy to multiple hosts easily

## Scope
This change introduces:
- **Docker cleanup automation capability** - Automated execution of Docker prune commands
- **Docker socket GID matching capability** - Secure non-root access to Docker daemon
- **Security and permissions management capability** - Least-privilege execution without --privileged
- **Configuration and customization capability** - Environment-based configuration
- **Testing and validation capability** - Comprehensive test suite with Docker-in-Docker

## Use Cases

> **⚠️ IMPORTANT: Local Execution Principle**
>
> The container **always runs on the host to be cleaned** - it never connects to remote hosts. When you use Docker contexts (e.g., `docker context use nas`), the Docker client on your machine sends the `docker run` command to the remote daemon, which then executes the container locally on that host. The volume mount `/var/run/docker.sock:/var/run/docker.sock` is interpreted by the execution host's daemon, not your client machine.
>
> **In other words**: If you run this container while in NAS context, the container runs ON the NAS and mounts the NAS's socket, cleaning the NAS's Docker resources. Your client machine only displays the output.

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
```yaml
# GitLab CI
after_script:
  - docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner
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

## Frequently Asked Questions

### How does the container know which host to clean?
**It doesn't!** The container is designed to be "context-agnostic" - it always cleans the Docker daemon of the host where it physically executes. The container simply mounts `/var/run/docker.sock` and assumes it's the local socket.

The **Docker client** (on your local machine) decides where the container runs via Docker contexts. When you execute `docker context use nas && docker run ...`, the Docker client sends the `run` command to the NAS daemon, the container executes on the NAS, and mounts the NAS's socket.

### Do I need to configure anything in the container for multi-host management?
**No!** Multi-host management is handled entirely by Docker contexts on your client machine. The container code remains simple and portable - it doesn't need SSH configuration, TCP connection logic, or awareness of multiple hosts.

Example workflow:
1. Your Mac's Docker client reads the active context
2. `docker run` command is sent to the appropriate daemon (local or remote via SSH)
3. Container starts on that host and mounts `/var/run/docker.sock` from that host
4. Container cleans that host's Docker resources
5. Logs are streamed back to your Mac for display

### Does the container handle SSH connections or Docker contexts?
**No!** The container has zero knowledge of contexts or remote connections. This complexity is handled by:
- **Docker client**: Manages contexts and routing commands to correct daemons
- **Docker daemon**: Executes containers and manages volumes

The container's job is simple: mount local socket, clean local Docker, exit.

### What about Windows hosts?
- **Docker Desktop on Windows (WSL2/Hyper-V)**: ✅ Works perfectly - Docker Desktop provides Unix socket compatibility
- **Windows Server with Docker Engine**: ⚠️ Requires TCP API exposure (`DOCKER_HOST=tcp://host:2375`) instead of socket mount
- **Windows with named pipes only**: ❌ Not supported in v1 (would require Windows container image)

### Why not make the container connect remotely via SSH/TCP?
This would make the container much more complex and less secure:
- ❌ Would need SSH key management and TCP certificate handling in container
- ❌ Would need custom connection logic instead of simple socket mount
- ❌ Would break the "runs locally" design principle
- ❌ Would make debugging harder (connection issues, auth problems, firewalls)
- ✅ Docker contexts already solve this problem natively and securely

The current design leverages Docker's native remote execution capabilities instead of reinventing them.

## Out of Scope (Future Enhancements)
- Real-time monitoring dashboard
- Built-in scheduled execution (use cron/systemd timers instead)
- Integration with orchestration platforms (Kubernetes operators, Docker Swarm services)
- Multi-host parallel cleanup from single container
- Web UI for configuration and history

## Technical Approach

### Docker Socket GID Matching
Instead of requiring --privileged mode, the container uses dynamic GID matching:
1. Detect GID of `/var/run/docker.sock` at startup
2. Create or reuse group with matching GID
3. Add non-root user to this group
4. Execute cleanup operations as non-root user with Docker access

### One-Shot Container Pattern
- Container executes cleanup sequence
- Logs summary to stdout
- Exits with appropriate code (0=success, 1=partial, 2=failure)
- `--rm` flag ensures automatic cleanup

### Configuration
All configuration via environment variables for Docker-native deployment:
- `PRUNE_ALL`, `PRUNE_VOLUMES`, `PRUNE_FORCE`
- `CLEANUP_CONTAINERS`, `CLEANUP_IMAGES`, etc.
- `PRUNE_FILTER_UNTIL`, `PRUNE_FILTER_LABEL`
- `LOG_LEVEL`, `LOG_FORMAT`, `DRY_RUN`

## Success Criteria
1. Container successfully cleans Docker daemon on multiple Linux distributions
2. No --privileged flag required
3. All tests pass (unit, integration, E2E)
4. Documentation covers all use cases with examples
5. Security scan shows no HIGH or CRITICAL vulnerabilities
6. Container size < 50MB
7. Execution time < 5 minutes for typical workloads
