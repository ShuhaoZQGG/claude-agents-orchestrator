#!/bin/bash

# Cycle Management Library
# Handles cycle history, handoffs, and cross-cycle context

CYCLE_HISTORY_FILE="$WORK_DIR/CYCLE_HISTORY.md"
CYCLE_HANDOFF_FILE="$WORK_DIR/CYCLE_HANDOFF.md"
NEXT_CYCLE_TASKS_FILE="$WORK_DIR/NEXT_CYCLE_TASKS.md"

# Initialize cycle history if it doesn't exist
init_cycle_history() {
    if [ ! -f "$CYCLE_HISTORY_FILE" ]; then
        cat > "$CYCLE_HISTORY_FILE" << 'EOF'
# Cycle History

This document tracks the history of all development cycles for continuous improvement.

## Cycle Summary

| Cycle | Start Date | End Date | Status | Branch | PR URL | Key Decisions |
|-------|------------|----------|--------|--------|--------|---------------|

## Detailed History

EOF
        log "📝 Initialized cycle history tracking"
    fi
}

# Initialize cycle handoff document
init_cycle_handoff() {
    local cycle_num="${1:-1}"
    cat > "$CYCLE_HANDOFF_FILE" << EOF
# Cycle $cycle_num Handoff Document

Generated: $(date)

## Current State
- Cycle Number: $cycle_num
- Branch: $(get_cycle_branch)
- Phase: $(cat "$STATE_FILE" 2>/dev/null || echo "unknown")

## Completed Work
<!-- Updated by each agent as they complete their phase -->

## Pending Items
<!-- Items that need attention in the next phase or cycle -->

## Technical Decisions
<!-- Important technical decisions made during this cycle -->

## Known Issues
<!-- Issues discovered but not yet resolved -->

## Next Steps
<!-- Clear action items for the next agent/cycle -->

EOF
    log "📋 Initialized cycle handoff document"
}

# Initialize next cycle tasks document
init_next_cycle_tasks() {
    if [ ! -f "$NEXT_CYCLE_TASKS_FILE" ]; then
        cat > "$NEXT_CYCLE_TASKS_FILE" << 'EOF'
# Tasks for Next Cycle

This document accumulates tasks that should be addressed in the next development cycle.

## Priority Tasks
<!-- High priority items that must be addressed -->

## Technical Debt
<!-- Code improvements and refactoring needs -->

## Feature Enhancements
<!-- Additional features or improvements identified -->

## Bug Fixes
<!-- Known bugs to be fixed -->

## Documentation Needs
<!-- Documentation that needs to be created or updated -->

EOF
        log "📋 Initialized next cycle tasks document"
    fi
}

# Get or create cycle branch name
get_cycle_branch() {
    local cycle_num=$(get_current_cycle)
    local branch_name=$(python3 -c "
import json, sys
try:
    with open('$ORCHESTRATION_STATE_FILE', 'r') as f:
        state = json.load(f)
        print(state.get('current_branch', ''))
except:
    print('')
" 2>/dev/null)
    
    if [ -z "$branch_name" ]; then
        # IMPORTANT: Always ensure we're on main before creating new branch
        log "📌 Ensuring new branch will be created from main"
        
        # Use intelligent branch naming if available
        if command -v generate_smart_branch_name >/dev/null 2>&1; then
            branch_name=$(generate_smart_branch_name "$cycle_num" "development" "${VISION:-development}")
        else
            branch_name="cycle-${cycle_num}-$(date +%Y%m%d-%H%M%S)"
        fi
        set_cycle_branch "$branch_name"
    fi
    
    echo "$branch_name"
}

# Set cycle branch name in state
set_cycle_branch() {
    local branch_name="$1"
    python3 -c "
import json, sys
try:
    with open('$ORCHESTRATION_STATE_FILE', 'r') as f:
        state = json.load(f)
except:
    state = {}

state['current_branch'] = '$branch_name'

with open('$ORCHESTRATION_STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
" 2>/dev/null
}

# Get cycle PR URL
get_cycle_pr_url() {
    python3 -c "
import json, sys
try:
    with open('$ORCHESTRATION_STATE_FILE', 'r') as f:
        state = json.load(f)
        print(state.get('current_pr_url', ''))
except:
    print('')
" 2>/dev/null
}

# Set cycle PR URL
set_cycle_pr_url() {
    local pr_url="$1"
    python3 -c "
import json, sys
try:
    with open('$ORCHESTRATION_STATE_FILE', 'r') as f:
        state = json.load(f)
except:
    state = {}

state['current_pr_url'] = '$pr_url'

with open('$ORCHESTRATION_STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
" 2>/dev/null
}

# Record cycle completion
record_cycle_completion() {
    local cycle_num="$1"
    local status="$2"
    local decision="$3"
    local branch=$(get_cycle_branch)
    local pr_url=$(get_cycle_pr_url)
    local start_date=$(python3 -c "
import json, sys
try:
    with open('$ORCHESTRATION_STATE_FILE', 'r') as f:
        state = json.load(f)
        cycles = state.get('cycles', {})
        cycle = cycles.get('$cycle_num', {})
        print(cycle.get('started_at', ''))
except:
    print('')
" 2>/dev/null)
    
    # Append to cycle history
    echo "" >> "$CYCLE_HISTORY_FILE"
    echo "### Cycle $cycle_num" >> "$CYCLE_HISTORY_FILE"
    echo "- Started: $start_date" >> "$CYCLE_HISTORY_FILE"
    echo "- Completed: $(date)" >> "$CYCLE_HISTORY_FILE"
    echo "- Status: $status" >> "$CYCLE_HISTORY_FILE"
    echo "- Decision: $decision" >> "$CYCLE_HISTORY_FILE"
    echo "- Branch: $branch" >> "$CYCLE_HISTORY_FILE"
    [ -n "$pr_url" ] && echo "- PR: $pr_url" >> "$CYCLE_HISTORY_FILE"
    echo "" >> "$CYCLE_HISTORY_FILE"
    
    # Copy handoff content to history
    if [ -f "$CYCLE_HANDOFF_FILE" ]; then
        echo "#### Handoff Notes" >> "$CYCLE_HISTORY_FILE"
        grep -A 100 "## Completed Work" "$CYCLE_HANDOFF_FILE" >> "$CYCLE_HISTORY_FILE" 2>/dev/null
    fi
    
    log "📊 Recorded cycle $cycle_num completion with status: $status"
}

# Update handoff document with phase completion
update_handoff_completed() {
    local phase="$1"
    local summary="$2"
    
    # Add to completed work section
    python3 -c "
import sys

phase = '$phase'
summary = '''$summary'''

with open('$CYCLE_HANDOFF_FILE', 'r') as f:
    lines = f.readlines()

# Find the Completed Work section
for i, line in enumerate(lines):
    if '## Completed Work' in line:
        # Insert after the section header
        lines.insert(i + 2, f'- **{phase}**: {summary}\\n')
        break

with open('$CYCLE_HANDOFF_FILE', 'w') as f:
    f.writelines(lines)
" 2>/dev/null
}

# Update handoff document with pending items
update_handoff_pending() {
    local item="$1"
    
    python3 -c "
import sys

item = '''$item'''

with open('$CYCLE_HANDOFF_FILE', 'r') as f:
    lines = f.readlines()

# Find the Pending Items section
for i, line in enumerate(lines):
    if '## Pending Items' in line:
        lines.insert(i + 2, f'- {item}\\n')
        break

with open('$CYCLE_HANDOFF_FILE', 'w') as f:
    f.writelines(lines)
" 2>/dev/null
}

# Add task for next cycle
add_next_cycle_task() {
    local category="$1"  # Priority Tasks, Technical Debt, Feature Enhancements, Bug Fixes, Documentation Needs
    local task="$2"
    
    python3 -c "
import sys

category = '$category'
task = '''$task'''

with open('$NEXT_CYCLE_TASKS_FILE', 'r') as f:
    lines = f.readlines()

# Find the appropriate section
for i, line in enumerate(lines):
    if f'## {category}' in line:
        lines.insert(i + 2, f'- {task}\\n')
        break

with open('$NEXT_CYCLE_TASKS_FILE', 'w') as f:
    f.writelines(lines)
" 2>/dev/null
}

# Extract review decision from REVIEW.md
extract_review_decision() {
    local decision=""
    
    # First check for structured markers
    if [ -f "$WORK_DIR/REVIEW.md" ]; then
        decision=$(grep -o "<!-- CYCLE_DECISION: [A-Z_]* -->" "$WORK_DIR/REVIEW.md" 2>/dev/null | sed 's/<!-- CYCLE_DECISION: \(.*\) -->/\1/')
    fi
    
    # Fallback to text analysis if no structured marker
    if [ -z "$decision" ] && [ -f "$WORK_DIR/REVIEW.md" ]; then
        if grep -qi "approv\|accept\|good\|pass\|looks good\|well done\|complete" "$WORK_DIR/REVIEW.md"; then
            decision="APPROVED"
        elif grep -qi "architect\|fundamental\|design flaw\|technology\|framework\|major change\|rethink" "$WORK_DIR/REVIEW.md"; then
            decision="NEEDS_ARCHITECTURE_CHANGE"
        else
            decision="NEEDS_REVISION"
        fi
    fi
    
    echo "$decision"
}

# Check for existing cycle PR
check_existing_pr() {
    local pr_url=$(get_cycle_pr_url)
    if [ -n "$pr_url" ]; then
        echo "$pr_url"
        return 0
    fi
    
    # Check for PR URL files from agents
    for pr_file in "$WORK_DIR/planning_pr.txt" "$WORK_DIR/design_pr.txt" "$WORK_DIR/dev_pr.txt" "$WORK_DIR/pr_url.txt"; do
        if [ -f "$pr_file" ]; then
            pr_url=$(cat "$pr_file" 2>/dev/null)
            if [ -n "$pr_url" ]; then
                set_cycle_pr_url "$pr_url"
                echo "$pr_url"
                return 0
            fi
        fi
    done
    
    return 1
}

# Cleanup old PRs and branches
cleanup_old_cycles() {
    local current_cycle=$(get_current_cycle)
    local keep_cycles=3  # Keep last 3 cycles
    
    log "🧹 Starting cleanup of old cycles (keeping last $keep_cycles)"
    
    # This would need GitHub CLI integration to:
    # 1. List all branches matching pattern "cycle-*"
    # 2. Close PRs older than N cycles
    # 3. Delete merged branches
    # For now, just log the intent
    
    log "🧹 Cleanup would remove branches older than cycle $((current_cycle - keep_cycles))"
}

# Initialize cycle management
init_cycle_management() {
    init_cycle_history
    init_next_cycle_tasks
    init_cycle_handoff "$(get_current_cycle)"
}