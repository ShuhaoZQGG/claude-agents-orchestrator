#!/bin/bash

# Base directories and files
PROJECT_DIR=${PROJECT_DIR:-$(pwd)}
WORK_DIR=${WORK_DIR:-"$PROJECT_DIR/.agent_work"}
STATE_FILE=${STATE_FILE:-"$WORK_DIR/state.txt"}
CONTEXT_FILE=${CONTEXT_FILE:-"$WORK_DIR/context.md"}
LOG_FILE=${LOG_FILE:-"$WORK_DIR/orchestrator.log"}
ORCHESTRATION_STATE_FILE=${ORCHESTRATION_STATE_FILE:-"$WORK_DIR/orchestration_state.json"}

# Behavior knobs
MAX_RETRIES=${MAX_RETRIES:-3}
MIN_OUTPUT_CHARS=${MIN_OUTPUT_CHARS:-100}

# External commands (customizable)
CLAUDE_CMD=${CLAUDE_CMD:-"claude --dangerously-skip-permissions --print --verbose"}
GH_CMD=${GH_CMD:-"gh"}

# Ensure work dir exists
mkdir -p "$WORK_DIR"
