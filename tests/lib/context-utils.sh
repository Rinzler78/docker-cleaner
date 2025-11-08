#!/bin/bash
# context-utils.sh - Docker context utility functions for tests

# Check if a Docker context is active and reachable
is_context_active() {
    local context_name="$1"

    # Try to ping the Docker daemon on this context
    if docker --context "$context_name" info >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get list of all available contexts
get_available_contexts() {
    docker context ls --format "{{.Name}}" 2>/dev/null || echo ""
}

# Find first active context from a list or all contexts
find_active_context() {
    local preferred_context="$1"

    # If a specific context was requested, check if it's active
    if [ -n "$preferred_context" ]; then
        if is_context_active "$preferred_context"; then
            echo "$preferred_context"
            return 0
        else
            echo "WARNING: Requested context '$preferred_context' is not active" >&2
        fi
    fi

    # Get all available contexts
    local contexts
    contexts=$(get_available_contexts)

    if [ -z "$contexts" ]; then
        echo "ERROR: No Docker contexts available" >&2
        return 1
    fi

    # Try each context until we find an active one
    while IFS= read -r ctx; do
        # Skip empty lines
        [ -z "$ctx" ] && continue

        # Skip default local contexts if looking for remote
        if [ "$ctx" = "default" ] || [ "$ctx" = "desktop-linux" ]; then
            continue
        fi

        if is_context_active "$ctx"; then
            echo "$ctx"
            return 0
        fi
    done <<< "$contexts"

    # If no remote context found, try local contexts
    while IFS= read -r ctx; do
        # Skip empty lines
        [ -z "$ctx" ] && continue

        if is_context_active "$ctx"; then
            echo "$ctx"
            return 0
        fi
    done <<< "$contexts"

    echo "ERROR: No active Docker contexts found" >&2
    return 1
}

# Find all active contexts (excluding local defaults)
find_all_active_contexts() {
    local contexts
    contexts=$(get_available_contexts)

    if [ -z "$contexts" ]; then
        echo "ERROR: No Docker contexts available" >&2
        return 1
    fi

    local active_contexts=""
    local found_any=false

    # Try each context
    while IFS= read -r ctx; do
        # Skip empty lines
        [ -z "$ctx" ] && continue

        # Skip default local contexts
        if [ "$ctx" = "default" ] || [ "$ctx" = "desktop-linux" ]; then
            continue
        fi

        if is_context_active "$ctx"; then
            if [ -n "$active_contexts" ]; then
                active_contexts="${active_contexts}
${ctx}"
            else
                active_contexts="$ctx"
            fi
            found_any=true
        fi
    done <<< "$contexts"

    if [ "$found_any" = false ]; then
        echo "ERROR: No active remote Docker contexts found" >&2
        return 1
    fi

    echo "$active_contexts"
    return 0
}

# Select context with user feedback
select_test_context() {
    local preferred_context="$1"
    local require_remote="${2:-false}"

    local selected_context

    if [ "$require_remote" = "true" ]; then
        echo "Searching for active remote Docker context..." >&2
    else
        echo "Searching for active Docker context..." >&2
    fi

    selected_context=$(find_active_context "$preferred_context")
    local result=$?

    if [ $result -eq 0 ] && [ -n "$selected_context" ]; then
        echo "Selected active context: $selected_context" >&2
        echo "$selected_context"
        return 0
    else
        echo "ERROR: Could not find an active Docker context" >&2
        echo "" >&2
        echo "Available contexts:" >&2
        docker context ls >&2
        echo "" >&2
        echo "To test if a context is active, run:" >&2
        echo "  docker --context <name> info" >&2
        return 1
    fi
}

# Export functions for use in other scripts
export -f is_context_active
export -f get_available_contexts
export -f find_active_context
export -f find_all_active_contexts
export -f select_test_context
