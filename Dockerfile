FROM docker:cli

# Install required packages
RUN apk add --no-cache bash gosu shadow

# Create non-root user
RUN adduser -D -u 1000 -s /bin/bash cleanup-user && \
    mkdir -p /app /app/logs && \
    chown -R cleanup-user:cleanup-user /app

# Copy scripts
COPY src/entrypoint.sh /entrypoint.sh
COPY src/cleanup.sh /app/cleanup.sh

# Set permissions
RUN chmod +x /entrypoint.sh /app/cleanup.sh

# Default environment variables
ENV DOCKER_SOCKET=/var/run/docker.sock \
    CLEANUP_USER=cleanup-user \
    PRUNE_ALL=false \
    PRUNE_VOLUMES=false \
    PRUNE_FORCE=true \
    CLEANUP_CONTAINERS=true \
    CLEANUP_IMAGES=true \
    CLEANUP_VOLUMES=false \
    CLEANUP_NETWORKS=true \
    CLEANUP_BUILD_CACHE=true \
    LOG_LEVEL=INFO \
    LOG_FORMAT=text \
    QUIET=false \
    DRY_RUN=false

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD []
