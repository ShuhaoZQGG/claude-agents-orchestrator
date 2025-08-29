#!/bin/bash

# Simple Autonomous Agent Orchestrator (modularized)
# Usage: ./orchestrate.sh "Build a task management app with user auth and real-time updates"

set -e

VISION=${1:-}
if [ -z "${VISION}" ]; then
    echo "Usage: $0 \"Your product vision\" [--force-reset]"
    echo "  --force-reset: Reset stuck cycles and start fresh"
    exit 1
fi

# Check for force reset flag
FORCE_RESET=false
if [ "${2:-}" = "--force-reset" ] || [ "${1:-}" = "--force-reset" ]; then
    FORCE_RESET=true
    if [ "${1:-}" = "--force-reset" ]; then
        VISION="${2:-}"
        if [ -z "${VISION}" ]; then
            echo "Error: Vision required even with --force-reset"
            exit 1
        fi
    fi
fi

# Source libs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/state.sh"
source "$SCRIPT_DIR/lib/cycle.sh"

# Soft-check for python3 like original (state updates will warn/fallback if missing)
if ! command -v python3 >/dev/null 2>&1; then
    warn "python3 not found; orchestration state updates may be limited"
fi

##### Smart state resumption logic using orchestration state (unchanged behavior) #####
determine_starting_state() {
    # Handle force reset
    if [ "$FORCE_RESET" = true ]; then
        log "🔄 Force reset requested - starting fresh" >&2
        if [ -f "$ORCHESTRATION_STATE_FILE" ]; then
            local old_cycle=$(get_current_cycle)
            record_cycle_completion "$old_cycle" "force_reset" "USER_REQUESTED_RESET"
            add_next_cycle_task "Priority Tasks" "Review and incorporate work from force-reset cycle $old_cycle"
        fi
        init_orchestration_state
        init_cycle_management
        echo "planning"
        return
    fi
    
    # Initialize orchestration state if it doesn't exist
    if [ ! -f "$ORCHESTRATION_STATE_FILE" ]; then
        log "🆕 No orchestration state found, initializing fresh" >&2
        init_orchestration_state
        echo "planning"
        return
    fi
    
    log "📋 Found existing orchestration state, analyzing..." >&2
    
    # Get current cycle and phase statuses
    local current_cycle=$(get_current_cycle)
    local planning_status=$(get_phase_status "planning")
    local design_status=$(get_phase_status "design")
    local development_status=$(get_phase_status "development")
    local review_status=$(get_phase_status "review")
    
    log "📊 Current cycle: $current_cycle" >&2
    log "📊 Phase status: planning=$planning_status, design=$design_status, development=$development_status, review=$review_status" >&2
    
    # Check which phases are completed in current cycle
    local planning_done_current=$(is_phase_completed_in_current_cycle "planning")
    local design_done_current=$(is_phase_completed_in_current_cycle "design")
    local development_done_current=$(is_phase_completed_in_current_cycle "development")
    local review_done_current=$(is_phase_completed_in_current_cycle "review")
    
    log "🔄 Cycle $current_cycle completion: planning=$planning_done_current, design=$design_done_current, development=$development_done_current, review=$review_done_current" >&2
    
    # Determine next phase based on current cycle completion status
    if [ "$review_done_current" = "true" ]; then
        # Check review decision using structured markers
        local decision=$(extract_review_decision)
        
        case "$decision" in
            "APPROVED")
                log "✅ Review completed and approved in cycle $current_cycle, starting new cycle" >&2
                increment_cycle
                init_cycle_management  # Initialize new cycle documents
                echo "planning"
                ;;
            "NEEDS_ARCHITECTURE_CHANGE")
                log "🏗️  Review identified architectural issues, restarting from planning" >&2
                echo "planning"
                ;;
            "NEEDS_REVISION"|*)
                log "🔧 Review requested changes, resuming from development" >&2
                echo "development"
                ;;
        esac
    elif [ "$review_status" = "running" ]; then
        log "🔍 Review phase was interrupted, retrying review" >&2
        echo "review"
    elif [ "$development_done_current" = "true" ]; then
        log "💻 Development completed in cycle $current_cycle, proceeding to review" >&2
        echo "review"
    elif [ "$development_status" = "running" ]; then
        local dev_attempts=$(get_phase_attempts "development")
        
        # Check if development has exceeded max retries
        if [ $dev_attempts -ge $MAX_RETRIES ]; then
            log "⚠️  Development stuck with $dev_attempts attempts (max: $MAX_RETRIES)" >&2
            log "🔄 Starting new cycle to recover" >&2
            increment_cycle
            echo "planning"
        else
            log "👨‍💻 Development phase was interrupted (attempt $dev_attempts), retrying" >&2
            echo "development"
        fi
    elif [ "$design_done_current" = "true" ]; then
        log "🎨 Design completed in cycle $current_cycle, proceeding to development" >&2
        echo "development"
    elif [ "$design_status" = "running" ]; then
        log "🎨 Design phase was interrupted, retrying design" >&2
        echo "design"
    elif [ "$planning_done_current" = "true" ]; then
        log "🏗️  Planning completed in cycle $current_cycle, proceeding to design" >&2
        echo "design"
    elif [ "$planning_status" = "running" ]; then
        log "🏗️  Planning phase was interrupted, retrying planning" >&2
        echo "planning"
    else
        log "🆕 Starting fresh from planning" >&2
        echo "planning"
    fi
    
}

# Determine and set the starting state
INITIAL_STATE=$(determine_starting_state)
echo "$INITIAL_STATE" > "$STATE_FILE"
log "🚀 Starting/resuming from state: $INITIAL_STATE"

# Counter for infinite loop protection is provided by config.sh (MAX_RETRIES)

# Get development retry count from orchestration state
if [ "$INITIAL_STATE" = "development" ]; then
    DEVELOPMENT_RETRIES=$(get_phase_attempts "development")
    
    # Check if we've already exceeded max retries
    if [ $DEVELOPMENT_RETRIES -ge $MAX_RETRIES ]; then
        log "⚠️  Development already attempted $DEVELOPMENT_RETRIES times (max: $MAX_RETRIES)"
        log "🔄 Moving to next cycle to recover from stuck state"
        
        # Record the stuck cycle and move to next
        record_cycle_completion "$(get_current_cycle)" "stuck" "MAX_RETRIES_EXCEEDED_ON_RESUME"
        add_next_cycle_task "Priority Tasks" "Complete unfinished development work from cycle $(get_current_cycle)"
        increment_cycle
        init_cycle_management
        
        # Start fresh from planning
        INITIAL_STATE="planning"
        echo "planning" > "$STATE_FILE"
        DEVELOPMENT_RETRIES=0
    else
        log "📊 Resuming development with attempt count: $DEVELOPMENT_RETRIES/$MAX_RETRIES"
    fi
else
    DEVELOPMENT_RETRIES=0
fi

# Initialize cycle management
init_cycle_management

# Create initial context
cat > "$CONTEXT_FILE" << EOF
# Project Vision
$VISION

# Current Cycle: $(get_current_cycle)
# Branch: $(get_cycle_branch)

# Agent Chain Progress
- [ ] Architecture Planning
- [ ] UI/UX Design  
- [ ] Implementation
- [ ] Code Review

# Agent Handoffs
Each agent will update this file with their outputs and findings.
See CYCLE_HANDOFF.md for detailed phase-to-phase handoffs.
See NEXT_CYCLE_TASKS.md for accumulated tasks.
EOF

log "🚀 Starting autonomous development for: $VISION"
log "📁 Work directory: $WORK_DIR"
log "📝 Logs will be saved to: $LOG_FILE"

# Show what files we found during state determination
if [ "$INITIAL_STATE" != "planning" ]; then
    log "📋 Resuming from existing work:"
    [ -f "$WORK_DIR/PLAN.md" ] && log "  ✓ PLAN.md found"
    [ -f "$WORK_DIR/DESIGN.md" ] && log "  ✓ DESIGN.md found" 
    [ -f "$WORK_DIR/IMPLEMENTATION.md" ] && log "  ✓ IMPLEMENTATION.md found"
    [ -f "$WORK_DIR/REVIEW.md" ] && log "  ✓ REVIEW.md found"
    if [ "$INITIAL_STATE" = "development" ] && [ $DEVELOPMENT_RETRIES -gt 0 ]; then
        log "  📊 Development retry count: $DEVELOPMENT_RETRIES/$MAX_RETRIES"
    fi
fi

# Initialize log file
echo "=== Claude Agents Orchestrator Log ===" > "$LOG_FILE"
echo "Vision: $VISION" >> "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "======================================" >> "$LOG_FILE"

# Main orchestration loop
while true; do
    STATE=$(cat "$STATE_FILE")
    log "📍 Current state: $STATE"
    
    case $STATE in
        "planning")
            log "🏗️  Running project-architect..."
            mark_phase_started "planning"
            update_phase_cycle "planning"
            source "$SCRIPT_DIR/phases/planning.sh"
            if run_planning_phase "$VISION"; then
                mark_phase_completed "planning"
                echo "design" > "$STATE_FILE"
                echo "RESULT: Architecture planning completed successfully" >> "$LOG_FILE"
                success "Architecture planning completed"
            else
                echo "ERROR: Architecture planning failed or produced insufficient output" >> "$LOG_FILE"
                error "Architecture planning failed - check that project-architect agent is properly configured"
                exit 1
            fi
            ;;
            
        "design")
            log "🎨 Running ui-feature-designer..."
            mark_phase_started "design"
            update_phase_cycle "design"
            source "$SCRIPT_DIR/phases/design.sh"
            if run_design_phase "$VISION"; then
                mark_phase_completed "design"
                echo "development" > "$STATE_FILE"
                DEVELOPMENT_RETRIES=0  # Reset retry counter
                echo "RESULT: UI/UX design completed successfully" >> "$LOG_FILE"
                success "UI/UX design completed"
            else
                echo "ERROR: UI/UX design failed or produced insufficient output" >> "$LOG_FILE"
                error "UI/UX design failed - check that ui-feature-designer agent is properly configured"
                exit 1
            fi
            ;;
            
        "development")
            DEVELOPMENT_RETRIES=$((DEVELOPMENT_RETRIES + 1))
            if [ $DEVELOPMENT_RETRIES -gt $MAX_RETRIES ]; then
                echo "ERROR: Maximum development retries ($MAX_RETRIES) exceeded" >> "$LOG_FILE"
                error "Development failed after $MAX_RETRIES attempts - manual intervention required"
                exit 1
            fi
            
            log "👨‍💻 Running developer-agent (attempt $DEVELOPMENT_RETRIES/$MAX_RETRIES)..."
            mark_phase_started "development"
            update_phase_cycle "development"
            source "$SCRIPT_DIR/phases/development.sh"
            if run_development_phase "$VISION" "$DEVELOPMENT_RETRIES"; then
                mark_phase_completed "development"
                echo "testing" > "$STATE_FILE"
                echo "RESULT: Development completed successfully" >> "$LOG_FILE"
                success "Development completed"
            else
                echo "ERROR: Development failed or produced insufficient output" >> "$LOG_FILE"
                error "Development failed - check that developer-agent is properly configured"
                exit 1
            fi
            ;;
            
        "testing")
            # Skip testing phase - go directly to review
            echo "review" > "$STATE_FILE"
            echo "RESULT: Skipping testing phase - going directly to review" >> "$LOG_FILE"
            success "Skipping testing - proceeding to review"
            ;;
            
        "review")
            log "🔍 Running pr-reviewer..."
            mark_phase_started "review"
            update_phase_cycle "review"
            source "$SCRIPT_DIR/phases/review.sh"
            if run_review_phase "$VISION"; then
                mark_phase_completed "review"
                # Extract structured decision from review
                local decision=$(extract_review_decision)
                
                case "$decision" in
                    "APPROVED")
                        record_cycle_completion "$(get_current_cycle)" "completed" "APPROVED"
                        increment_cycle
                        init_cycle_management  # Prepare for next cycle
                        echo "planning" > "$STATE_FILE"
                        echo "RESULT: Cycle $(get_current_cycle) completed - APPROVED, starting new cycle" >> "$LOG_FILE"
                        success "Cycle completed - APPROVED, starting new cycle"
                        ;;
                    "NEEDS_ARCHITECTURE_CHANGE")
                        echo "planning" > "$STATE_FILE"
                        DEVELOPMENT_RETRIES=0
                        add_next_cycle_task "Priority Tasks" "Address architectural issues identified in review"
                        echo "RESULT: Review identified architectural issues - restarting from planning" >> "$LOG_FILE"
                        warn "Review identified architectural issues - restarting from planning phase"
                        ;;
                    "NEEDS_REVISION"|*)
                        if [ ${DEVELOPMENT_RETRIES:-0} -ge $MAX_RETRIES ]; then
                            # Force move to next cycle after max retries
                            record_cycle_completion "$(get_current_cycle)" "partial" "MAX_RETRIES_REACHED"
                            add_next_cycle_task "Priority Tasks" "Complete unfinished work from cycle $(get_current_cycle)"
                            increment_cycle
                            init_cycle_management
                            echo "planning" > "$STATE_FILE"
                            echo "RESULT: Max retries reached - moving to next cycle" >> "$LOG_FILE"
                            warn "Max development attempts reached - starting fresh cycle"
                        else
                            echo "development" > "$STATE_FILE"
                            echo "RESULT: Review requested changes - retrying development" >> "$LOG_FILE"
                            warn "Review requested changes - retrying development"
                        fi
                        ;;
                esac
            else
                echo "ERROR: Code review failed or produced insufficient output" >> "$LOG_FILE"
                error "Code review failed - check that pr-reviewer agent is properly configured"
                exit 1
            fi
            ;;
            
        "complete")
            echo "" >> "$LOG_FILE"
            echo "=== ORCHESTRATION COMPLETED - $(date) ===" >> "$LOG_FILE"
            echo "All cycles completed successfully!" >> "$LOG_FILE"
            
            # Perform final cleanup of old PRs/branches if needed
            cleanup_old_cycles
            
            success "🎉 Autonomous development completed!"
            log "📋 Final results in: $WORK_DIR"
            log "📄 Cycle history: cat $CYCLE_HISTORY_FILE"
            log "📝 Full logs: cat $LOG_FILE"
            
            # Check if we should continue with another cycle
            if [ -f "$NEXT_CYCLE_TASKS_FILE" ] && grep -q "^- " "$NEXT_CYCLE_TASKS_FILE"; then
                log "📌 Tasks pending for next cycle - consider running again"
            fi
            
            break
            ;;
            
        *)
            error "Unknown state: $STATE"
            exit 1
            ;;
    esac
    
    # Small delay between agents
    sleep 2
done

log "🏁 Process finished. Check $WORK_DIR for all outputs."