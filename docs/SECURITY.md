# Security Documentation

## Overview

Docker Cleanup Container requires access to the Docker daemon socket to perform cleanup operations. This document describes the security model, threat considerations, and best practices.

## Security Model

### Trust Boundary

```
┌─────────────────────────────────────────────────┐
│           Trusted Zone                          │
│  ┌──────────────────────────────────────────┐   │
│  │   Docker Cleanup Container               │   │
│  │   - Runs as non-root (UID 1000)          │   │
│  │   - Has Docker socket access             │   │
│  │   - Equivalent to root on host           │   │
│  └──────────────────────────────────────────┘   │
│                     │                            │
│                     ▼                            │
│  ┌──────────────────────────────────────────┐   │
│  │   Docker Daemon                          │   │
│  │   - Full control over host containers    │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

**Key Principle**: Access to `/var/run/docker.sock` = Root access to host

## Threat Model

### Primary Threats

#### T1: Container Escape
**Description**: Attacker exploits container to gain host access
**Likelihood**: Low (requires kernel vulnerability)
**Impact**: Critical (full host compromise)
**Mitigations**:
- Non-root user execution (UID 1000)
- No `--privileged` flag
- Read-only socket mount when possible
- Regular base image updates

#### T2: Malicious Container Execution
**Description**: Container starts privileged containers or mounts sensitive paths
**Likelihood**: Medium (if image is compromised)
**Impact**: Critical (full host compromise)
**Mitigations**:
- Use official/trusted images only
- Verify image signatures
- Run on controlled hosts only
- Monitor logs for suspicious activity

#### T3: Accidental Data Loss
**Description**: Container deletes critical volumes or containers
**Likelihood**: Medium (user error)
**Impact**: High (data loss)
**Mitigations**:
- Conservative defaults (PRUNE_VOLUMES=false)
- DRY_RUN mode for preview
- Label-based protection filters
- Comprehensive audit logging
- Running container protection (built-in)

#### T4: Log Tampering
**Description**: Attacker modifies logs to hide activity
**Likelihood**: Low (logs go to stdout)
**Impact**: Medium (loss of audit trail)
**Mitigations**:
- Immutable stdout/stderr logs
- Log to external SIEM systems
- JSON format for log integrity verification
- Timestamp all log entries (ISO 8601)

#### T5: Unauthorized Access
**Description**: Attacker gains access to Docker socket
**Likelihood**: Varies by deployment
**Impact**: Critical (full host compromise)
**Mitigations**:
- Docker socket permissions (root:docker 660)
- GID matching instead of --privileged
- SSH key authentication for remote contexts
- Network isolation when possible

### Attack Vectors

1. **Compromised Base Image**
   - Risk: Malicious code in docker:cli image
   - Mitigation: Use official Docker images, verify signatures

2. **Volume Mount Hijacking**
   - Risk: Mount sensitive host paths instead of socket
   - Mitigation: Strict volume mount validation in entrypoint

3. **Environment Variable Injection**
   - Risk: Malicious env vars execute arbitrary Docker commands
   - Mitigation: Input validation in config_validator.sh

4. **Resource Exhaustion**
   - Risk: Container consumes excessive CPU/memory
   - Mitigation: Resource limits in deployment (docker-compose)

## Security Controls

### Preventive Controls

#### PC1: Non-Root Execution
```dockerfile
# Create non-root user
RUN adduser -D -u 1000 -s /bin/bash cleanup-user

# Execute as non-root
exec gosu cleanup-user /app/cleanup.sh
```

**Rationale**: Reduces impact of container compromise

#### PC2: GID Matching
```bash
# Dynamic GID detection and matching
DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
groupadd -g "$DOCKER_GID" docker
usermod -aG docker cleanup-user
```

**Rationale**: Avoids `--privileged` flag while maintaining socket access

#### PC3: Input Validation
```bash
# Validate all environment variables
validate_boolean "PRUNE_ALL" "$PRUNE_ALL"
validate_duration "PRUNE_FILTER_UNTIL" "$PRUNE_FILTER_UNTIL"
```

**Rationale**: Prevents injection attacks and configuration errors

#### PC4: Resource Protection
- Running containers: Always protected (Docker default)
- Volumes in use: Always protected (Docker default)
- Volumes (all): Opt-in only (PRUNE_VOLUMES=false default)
- Images (all): Opt-in only (PRUNE_ALL=false default)
- Label filters: User-configurable protection

### Detective Controls

#### DC1: Comprehensive Audit Logging
```
[INFO] AUDIT: Removed stopped containers, space reclaimed: 1.2GB
[INFO] AUDIT: Removed dangling images, space reclaimed: 3.5GB
[WARN] AUDIT: DELETED 2 unused volumes, space reclaimed: 500MB
```

**All operations logged with**:
- Timestamp (ISO 8601)
- Operation type
- Resource count
- Space reclaimed
- Success/failure status

#### DC2: Security Warnings
```
[WARN] SECURITY: Container has access to Docker socket - equivalent to root access on host
[WARN] SECURITY: Only run this container on hosts you control with trusted images
[WARN] SECURITY: PRUNE_ALL enabled - removing ALL unused images
[WARN] SECURITY: Volume prune enabled - this will PERMANENTLY DELETE unused volumes
```

#### DC3: Resource Counting
- Pre-cleanup resource inventory
- Protected resource identification
- Post-cleanup verification

### Responsive Controls

#### RC1: Exit Codes
- `0`: Success - no action needed
- `1`: Partial failure - investigate logs
- `2`: Complete failure - check connectivity and permissions

#### RC2: Dry-Run Mode
```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e DRY_RUN=true \
  docker-cleaner
```

**Use before production runs to preview changes**

## Security Best Practices

### Deployment

#### ✅ DO

1. **Use Official Images**
   ```bash
   docker pull docker-cleaner:latest
   # Verify: docker inspect docker-cleaner:latest
   ```

2. **Run on Controlled Hosts**
   - Development environments
   - CI/CD runners you manage
   - Staging environments
   - Production (with caution and dry-run first)

3. **Use Docker Contexts for Remote Hosts**
   ```bash
   docker context create nas --docker "host=ssh://nas.local"
   docker context use nas
   docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker-cleaner
   ```

4. **Enable Audit Logging**
   ```bash
   docker run --rm \
     -v /var/run/docker.sock:/var/run/docker.sock \
     -e LOG_FORMAT=json \
     docker-cleaner | tee /var/log/docker-cleanup.log
   ```

5. **Use Label Protection**
   ```bash
   # Label critical resources
   docker run -d --label keep=true myapp

   # Protect labeled resources
   docker run --rm \
     -v /var/run/docker.sock:/var/run/docker.sock \
     -e PRUNE_FILTER_LABEL="keep!=true" \
     docker-cleaner
   ```

6. **Test with Dry-Run First**
   ```bash
   docker run --rm \
     -v /var/run/docker.sock:/var/run/docker.sock \
     -e DRY_RUN=true \
     -e PRUNE_ALL=true \
     docker-cleaner
   ```

#### ❌ DON'T

1. **Don't Run on Untrusted Hosts**
   - Public cloud instances you don't control
   - Shared hosting environments
   - Multi-tenant Kubernetes clusters

2. **Don't Use with Untrusted Images**
   ```bash
   # BAD
   docker pull random-user/docker-cleaner
   ```

3. **Don't Skip Security Warnings**
   - Read and understand all WARN messages
   - Investigate unexpected behavior
   - Monitor logs for anomalies

4. **Don't Use --privileged Flag**
   ```bash
   # NEVER DO THIS
   docker run --privileged ...
   ```

5. **Don't Ignore Exit Codes**
   ```bash
   # BAD
   docker run ... docker-cleaner || true

   # GOOD
   if ! docker run ... docker-cleaner; then
     echo "Cleanup failed, investigating..."
     exit 1
   fi
   ```

### Configuration

#### Conservative (Recommended)
```bash
PRUNE_ALL=false
PRUNE_VOLUMES=false
PRUNE_FILTER_UNTIL=720h  # 30 days
CLEANUP_BUILD_CACHE=false
LOG_LEVEL=INFO
```

#### Balanced
```bash
PRUNE_ALL=false
PRUNE_VOLUMES=false
PRUNE_FILTER_UNTIL=168h  # 7 days
CLEANUP_BUILD_CACHE=true
LOG_LEVEL=INFO
```

#### Aggressive (Use with Caution)
```bash
PRUNE_ALL=true
PRUNE_VOLUMES=true
PRUNE_FILTER_UNTIL=24h
CLEANUP_BUILD_CACHE=true
LOG_LEVEL=DEBUG
```

## Incident Response

### Suspected Compromise

1. **Immediate Actions**
   ```bash
   # Stop all cleanup containers
   docker stop $(docker ps -q --filter ancestor=docker-cleaner)

   # Check for suspicious containers
   docker ps -a

   # Review audit logs
   docker logs <container-id> | grep -E "(ERROR|SECURITY|AUDIT)"
   ```

2. **Investigation**
   - Review all recent cleanup operations
   - Check for unexpected container creations
   - Verify volume and network changes
   - Analyze log timestamps for anomalies

3. **Recovery**
   - Restore from backups if data loss occurred
   - Rotate Docker daemon credentials
   - Update base images
   - Review and tighten permissions

### Data Loss

1. **If volumes were accidentally deleted**
   - Stop cleanup operations immediately
   - Check backup systems
   - Attempt volume recovery (filesystem-dependent)
   - Document incident for post-mortem

2. **Prevention for future**
   - Always use DRY_RUN first
   - Implement label-based protection
   - Enable volume backups before cleanup
   - Use time-based filters (PRUNE_FILTER_UNTIL)

## Compliance Considerations

### Audit Requirements

For compliance-sensitive environments:

1. **Log Retention**
   ```bash
   docker run --rm \
     -v /var/run/docker.sock:/var/run/docker.sock \
     -e LOG_FORMAT=json \
     docker-cleaner | tee -a /var/log/docker-cleanup-$(date +%Y%m%d).log
   ```

2. **SIEM Integration**
   - Use JSON format for structured logs
   - Forward to centralized logging (ELK, Splunk, etc.)
   - Set up alerts for volume deletions
   - Monitor for unusual cleanup patterns

3. **Change Management**
   - Document cleanup schedules
   - Require approval for volume cleanup
   - Use tickets/approvals for production
   - Maintain cleanup history

### Data Protection

1. **GDPR/Privacy Considerations**
   - Volumes may contain personal data
   - Ensure proper data lifecycle management
   - Document retention policies
   - Log all deletion operations

2. **Backup Integration**
   ```bash
   # Backup before aggressive cleanup
   ./backup-volumes.sh
   docker run --rm \
     -v /var/run/docker.sock:/var/run/docker.sock \
     -e PRUNE_VOLUMES=true \
     docker-cleaner
   ```

## Security Checklist

Before deploying to production:

- [ ] Using official/trusted docker-cleaner image
- [ ] Tested with DRY_RUN mode first
- [ ] Conservative defaults configured
- [ ] Label protection implemented for critical resources
- [ ] Audit logging enabled (JSON format recommended)
- [ ] Logs forwarded to SIEM/centralized logging
- [ ] Backup procedures in place
- [ ] Incident response plan documented
- [ ] Cron job configured with proper error handling
- [ ] Exit codes monitored
- [ ] Security warnings reviewed and understood
- [ ] No --privileged flag in use
- [ ] Read-only socket mount where possible
- [ ] Resource limits configured (CPU/memory)

## Contact

For security issues or questions:
- Review logs with LOG_LEVEL=DEBUG
- Check GitHub issues
- Consult documentation at /docs/

---

**Last Updated**: 2025-10-23
**Version**: 1.0.0
