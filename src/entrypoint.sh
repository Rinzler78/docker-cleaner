#!/bin/bash
# entrypoint.sh - Setup Docker socket access and run cleanup
set -euo pipefail

# Source logger if available for consistent logging
if [ -f /app/logger.sh ]; then
    source /app/logger.sh
else
    # Fallback logging functions
    log() {
        local level="$1"
        shift
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [$level] $*" >&2
    }
fi

# Function: Exit with error
die() {
    log "ERROR" "$@"
    exit 2
}

# Step 1: Validate Docker socket exists
DOCKER_SOCKET="${DOCKER_SOCKET:-/var/run/docker.sock}"
log "INFO" "Checking for Docker socket at $DOCKER_SOCKET"

if [ ! -S "$DOCKER_SOCKET" ]; then
    die "Docker socket not found at $DOCKER_SOCKET. Ensure volume is mounted: -v /var/run/docker.sock:/var/run/docker.sock"
fi
log "INFO" "Docker socket found at $DOCKER_SOCKET"

# Step 2: Detect socket GID
DOCKER_GID=$(stat -c '%g' "$DOCKER_SOCKET" 2>/dev/null || stat -f '%g' "$DOCKER_SOCKET" 2>/dev/null)
if [ -z "$DOCKER_GID" ]; then
    die "Failed to detect GID of docker socket"
fi
log "INFO" "Detected docker.sock GID: $DOCKER_GID"

# Step 3: Handle group creation/reuse
EXISTING_GROUP=$(getent group "$DOCKER_GID" | cut -d: -f1 || echo "")
if [ -n "$EXISTING_GROUP" ]; then
    log "INFO" "Group with GID $DOCKER_GID already exists: $EXISTING_GROUP (reusing)"
    DOCKER_GROUP="$EXISTING_GROUP"
else
    # Check if 'docker' group exists with a different GID
    if getent group docker >/dev/null 2>&1; then
        log "INFO" "Docker group exists with different GID, modifying to GID $DOCKER_GID"
        if ! groupmod -g "$DOCKER_GID" docker 2>/dev/null; then
            die "Failed to modify docker group to GID $DOCKER_GID"
        fi
        DOCKER_GROUP="docker"
    else
        log "INFO" "Creating docker group with GID $DOCKER_GID"
        if ! groupadd -g "$DOCKER_GID" docker 2>/dev/null; then
            die "Failed to create docker group with GID $DOCKER_GID"
        fi
        DOCKER_GROUP="docker"
    fi
fi

# Step 4: Add cleanup user to docker group
CLEANUP_USER="${CLEANUP_USER:-cleanup-user}"
log "INFO" "Adding user $CLEANUP_USER to group $DOCKER_GROUP"
if ! usermod -aG "$DOCKER_GROUP" "$CLEANUP_USER" 2>/dev/null; then
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

# Step 7: Log security warning about socket sharing
log "WARN" "SECURITY: Container has access to Docker socket - equivalent to root access on host"
log "WARN" "SECURITY: Only run this container on hosts you control with trusted images"

# Step 8: Execute cleanup script as non-root user
log "INFO" "Starting cleanup operations as $CLEANUP_USER"
exec gosu "$CLEANUP_USER" /app/cleanup.sh "$@"
