#!/bin/bash
# logger.sh - Logging system for docker-cleaner

# Get log level from environment or default to INFO
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FORMAT="${LOG_FORMAT:-text}"
QUIET="${QUIET:-false}"

# Get log level priority (compatible bash 3.2+)
get_log_level_priority() {
    case "$1" in
        DEBUG) echo 0 ;;
        INFO)  echo 1 ;;
        WARN)  echo 2 ;;
        ERROR) echo 3 ;;
        *)     echo 1 ;; # Default to INFO
    esac
}

# Get current log level priority
CURRENT_LEVEL_PRIORITY=$(get_log_level_priority "$LOG_LEVEL")

# Function: Get ISO 8601 timestamp
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Function: Log message with level filtering
log() {
    local level="$1"
    shift
    local message="$*"

    # Skip if quiet mode
    if [ "$QUIET" = "true" ]; then
        return 0
    fi

    # Check if this level should be logged
    local level_priority=$(get_log_level_priority "$level")
    if [ "$level_priority" -lt "$CURRENT_LEVEL_PRIORITY" ]; then
        return 0
    fi

    # Format output based on LOG_FORMAT
    if [ "$LOG_FORMAT" = "json" ]; then
        log_json "$level" "$message"
    else
        log_text "$level" "$message"
    fi
}

# Function: Log in text format
log_text() {
    local level="$1"
    local message="$2"
    local timestamp=$(get_timestamp)

    echo "[${timestamp}] [${level}] ${message}" >&2
}

# Function: Log in JSON format
log_json() {
    local level="$1"
    local message="$2"
    local timestamp=$(get_timestamp)

    # Escape quotes in message
    local escaped_message="${message//\"/\\\"}"

    echo "{\"timestamp\":\"${timestamp}\",\"level\":\"${level}\",\"message\":\"${escaped_message}\"}" >&2
}

# Function: Log operation result
log_operation() {
    local operation="$1"
    local status="$2"
    local count="$3"
    local space_freed="$4"

    if [ "$LOG_FORMAT" = "json" ]; then
        local timestamp=$(get_timestamp)
        echo "{\"timestamp\":\"${timestamp}\",\"level\":\"INFO\",\"operation\":\"${operation}\",\"status\":\"${status}\",\"count\":${count},\"space_freed\":\"${space_freed}\"}" >&2
    else
        log "INFO" "${operation}: ${status} (count: ${count}, space freed: ${space_freed})"
    fi
}

# Function: Log debug messages
debug() {
    log "DEBUG" "$@"
}

# Function: Log info messages
info() {
    log "INFO" "$@"
}

# Function: Log warning messages
warn() {
    log "WARN" "$@"
}

# Function: Log error messages
error() {
    log "ERROR" "$@"
}

# Export functions for use in other scripts
export -f log log_text log_json log_operation debug info warn error get_timestamp
