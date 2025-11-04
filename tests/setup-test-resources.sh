#!/bin/bash
# setup-test-resources.sh - Create Docker resources for testing cleanup operations

set -euo pipefail

# Parse command line arguments
TARGET_CONTEXT=""
ORIGINAL_CONTEXT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --context)
            TARGET_CONTEXT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--context <name>]"
            exit 1
            ;;
    esac
done

# Context management
setup_context() {
    if [ -n "$TARGET_CONTEXT" ]; then
        # Store original context
        ORIGINAL_CONTEXT=$(docker context show)
        echo "Switching from context '$ORIGINAL_CONTEXT' to '$TARGET_CONTEXT'..."

        # Validate target context exists
        if ! docker context ls --format "{{.Name}}" | grep -q "^${TARGET_CONTEXT}$"; then
            echo "Error: Context '$TARGET_CONTEXT' does not exist"
            echo "Available contexts:"
            docker context ls
            exit 1
        fi

        # Switch to target context
        docker context use "$TARGET_CONTEXT" >/dev/null 2>&1
        echo "✓ Switched to context: $TARGET_CONTEXT"
        echo ""
    fi
}

# Restore context on exit
restore_context() {
    if [ -n "$ORIGINAL_CONTEXT" ] && [ "$ORIGINAL_CONTEXT" != "$(docker context show)" ]; then
        echo ""
        echo "Restoring original context: $ORIGINAL_CONTEXT"
        docker context use "$ORIGINAL_CONTEXT" >/dev/null 2>&1
    fi
}

# Set trap for context restoration
trap restore_context EXIT

echo "=== Docker Cleanup Container - Test Resource Setup ==="
echo ""

# Setup context if specified
setup_context

# Cleanup function
cleanup_existing() {
    echo "Cleaning up any existing test resources..."
    docker rm -f $(docker ps -aq --filter label=test-cleanup=true) 2>/dev/null || true
    docker rmi $(docker images -q --filter label=test-cleanup=true) 2>/dev/null || true
    docker volume rm $(docker volume ls -q --filter label=test-cleanup=true) 2>/dev/null || true
    docker network rm $(docker network ls -q --filter label=test-cleanup=true) 2>/dev/null || true
    echo "✓ Existing test resources cleaned up"
    echo ""
}

# Create running containers
create_running_containers() {
    echo "Creating running containers..."
    docker run -d \
        --name test-cleanup-container-running-1 \
        --label test-cleanup=true \
        --label keep=true \
        alpine:latest sleep 3600

    docker run -d \
        --name test-cleanup-container-running-2 \
        --label test-cleanup=true \
        alpine:latest sleep 3600

    echo "✓ Created 2 running containers"
}

# Create stopped containers
create_stopped_containers() {
    echo "Creating stopped containers..."
    docker create \
        --name test-cleanup-container-stopped-1 \
        --label test-cleanup=true \
        alpine:latest echo "test"

    docker create \
        --name test-cleanup-container-stopped-2 \
        --label test-cleanup=true \
        alpine:latest echo "test"

    docker run \
        --name test-cleanup-container-exited-1 \
        --label test-cleanup=true \
        alpine:latest echo "test"

    echo "✓ Created 3 stopped/exited containers"
}

# Create tagged images
create_tagged_images() {
    echo "Creating tagged images..."
    docker tag alpine:latest test-cleanup-image:v1
    docker image inspect test-cleanup-image:v1 > /dev/null 2>&1 \
        && docker image tag test-cleanup-image:v1 test-cleanup-image:labeled \
        && docker image inspect test-cleanup-image:labeled > /dev/null 2>&1

    echo "✓ Created tagged test images"
}

# Create dangling images
create_dangling_images() {
    echo "Creating dangling images..."

    # Create a temporary Dockerfile
    cat > /tmp/test-cleanup-dockerfile-1 <<EOF
FROM alpine:latest
RUN echo "test layer 1" > /tmp/test1
LABEL test-cleanup=true
EOF

    docker build -t test-cleanup-temp:latest -f /tmp/test-cleanup-dockerfile-1 . >/dev/null 2>&1

    # Create another build with same tag to make previous one dangling
    cat > /tmp/test-cleanup-dockerfile-2 <<EOF
FROM alpine:latest
RUN echo "test layer 2" > /tmp/test2
LABEL test-cleanup=true
EOF

    docker build -t test-cleanup-temp:latest -f /tmp/test-cleanup-dockerfile-2 . >/dev/null 2>&1

    rm -f /tmp/test-cleanup-dockerfile-*

    echo "✓ Created dangling images"
}

# Create volumes (used)
create_used_volumes() {
    echo "Creating volumes in use..."
    docker volume create --label test-cleanup=true test-cleanup-volume-used-1
    docker volume create --label test-cleanup=true --label keep=true test-cleanup-volume-used-2

    # Attach volumes to running containers
    docker run -d \
        --name test-cleanup-vol-user-1 \
        --label test-cleanup=true \
        -v test-cleanup-volume-used-1:/data \
        alpine:latest sleep 3600

    docker run -d \
        --name test-cleanup-vol-user-2 \
        --label test-cleanup=true \
        -v test-cleanup-volume-used-2:/data \
        alpine:latest sleep 3600

    echo "✓ Created 2 volumes in use"
}

# Create volumes (unused)
create_unused_volumes() {
    echo "Creating unused volumes..."
    docker volume create --label test-cleanup=true test-cleanup-volume-unused-1
    docker volume create --label test-cleanup=true test-cleanup-volume-unused-2
    docker volume create --label test-cleanup=true test-cleanup-volume-unused-3

    echo "✓ Created 3 unused volumes"
}

# Create networks (used)
create_used_networks() {
    echo "Creating networks in use..."
    docker network create --label test-cleanup=true test-cleanup-network-used-1
    docker network create --label test-cleanup=true --label keep=true test-cleanup-network-used-2

    # Attach networks to running containers
    docker run -d \
        --name test-cleanup-net-user-1 \
        --label test-cleanup=true \
        --network test-cleanup-network-used-1 \
        alpine:latest sleep 3600

    docker run -d \
        --name test-cleanup-net-user-2 \
        --label test-cleanup=true \
        --network test-cleanup-network-used-2 \
        alpine:latest sleep 3600

    echo "✓ Created 2 networks in use"
}

# Create networks (unused)
create_unused_networks() {
    echo "Creating unused networks..."
    docker network create --label test-cleanup=true test-cleanup-network-unused-1
    docker network create --label test-cleanup=true test-cleanup-network-unused-2

    echo "✓ Created 2 unused networks"
}

# Generate build cache
generate_build_cache() {
    echo "Generating build cache..."

    cat > /tmp/test-cleanup-cache-dockerfile <<EOF
FROM alpine:latest
RUN apk add --no-cache curl
RUN echo "cache layer 1" > /tmp/cache1
RUN echo "cache layer 2" > /tmp/cache2
EOF

    docker build -t test-cleanup-cache:latest -f /tmp/test-cleanup-cache-dockerfile . >/dev/null 2>&1
    docker rmi test-cleanup-cache:latest 2>/dev/null || true

    rm -f /tmp/test-cleanup-cache-dockerfile

    echo "✓ Generated build cache"
}

# Print summary
print_summary() {
    echo ""
    echo "=== Test Resources Summary ==="

    local current_context=$(docker context show)
    echo "Docker Context: $current_context"
    echo ""

    local running_count=$(docker ps -q --filter label=test-cleanup=true | wc -l | tr -d ' ')
    local stopped_count=$(docker ps -aq -f status=exited -f status=created --filter label=test-cleanup=true | wc -l | tr -d ' ')
    local image_count=$(docker images -q --filter label=test-cleanup=true | wc -l | tr -d ' ')
    local dangling_count=$(docker images -f dangling=true -q | wc -l | tr -d ' ')
    local volume_count=$(docker volume ls -q --filter label=test-cleanup=true | wc -l | tr -d ' ')
    local network_count=$(docker network ls -q --filter label=test-cleanup=true | wc -l | tr -d ' ')

    echo "Containers (running): $running_count"
    echo "Containers (stopped): $stopped_count"
    echo "Images (labeled): $image_count"
    echo "Images (dangling): $dangling_count"
    echo "Volumes: $volume_count"
    echo "Networks: $network_count"
    echo ""
    echo "All resources are labeled with: test-cleanup=true"
    echo "Protected resources are labeled with: keep=true"
    echo ""
    if [ -n "$TARGET_CONTEXT" ]; then
        echo "To clean up: ./tests/cleanup-test-resources.sh --context $TARGET_CONTEXT"
    else
        echo "To clean up: ./tests/cleanup-test-resources.sh"
    fi
    echo "To test cleanup: docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -e DRY_RUN=true docker-cleaner"
}

# Main execution
main() {
    cleanup_existing

    echo "Creating test resources..."
    echo ""

    create_running_containers
    create_stopped_containers
    create_tagged_images
    create_dangling_images
    create_used_volumes
    create_unused_volumes
    create_used_networks
    create_unused_networks
    generate_build_cache

    print_summary
}

# Run
main "$@"
