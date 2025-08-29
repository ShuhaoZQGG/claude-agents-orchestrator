#!/bin/bash

check_output_quality() {
    local output="$1"
    local min_chars=${MIN_OUTPUT_CHARS:-100}
    local content_length
    content_length=$(echo "$output" | tr -d '[:space:]' | wc -c | tr -d ' ')
    if [ "$content_length" -lt "$min_chars" ]; then
        return 1
    fi
    return 0
}

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "Required command not found: $cmd"
        exit 1
    fi
}
