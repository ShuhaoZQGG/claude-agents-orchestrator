#!/bin/bash

# Simple Autonomous Agent Orchestrator
# Usage: ./orchestrate.sh "Build a task management app with user auth and real-time updates"

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

error() {
    echo -e "${RED}✗ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

VISION="$1"
PROJECT_DIR=$(pwd)
WORK_DIR="$PROJECT_DIR/.agent_work"
STATE_FILE="$WORK_DIR/state.txt"
CONTEXT_FILE="$WORK_DIR/context.md"
LOG_FILE="$WORK_DIR/orchestrator.log"
ORCHESTRATION_STATE_FILE="$WORK_DIR/orchestration_state.json"

if [ -z "$VISION" ]; then
    echo "Usage: $0 \"Your product vision\""
    exit 1
fi

# Initialize work directory
mkdir -p "$WORK_DIR"

# Orchestration state management functions
init_orchestration_state() {
    cat > "$ORCHESTRATION_STATE_FILE" << EOF
{
  "current_phase": "planning",
  "current_cycle": 1,
  "last_updated": "$(date -Iseconds)",
  "phases": {
    "planning": {"status": "pending", "started": null, "completed": null, "attempts": 0, "cycle": 1},
    "design": {"status": "pending", "started": null, "completed": null, "attempts": 0, "cycle": 0},
    "development": {"status": "pending", "started": null, "completed": null, "attempts": 0, "cycle": 0},
    "review": {"status": "pending", "started": null, "completed": null, "attempts": 0, "cycle": 0}
  },
  "overall_status": "in_progress",
  "handoffs": {
    "planning_to_design": [],
    "design_to_development": [],
    "development_to_review": [],
    "review_to_planning": [],
    "planning_to_planning": [],
    "design_to_design": [],
    "development_to_development": [],
    "review_to_review": []
  },
  "cycle_history": {
    "1": {"phases_completed": [], "issues_found": [], "lessons_learned": []}
  }
}
EOF
}

mark_phase_started() {
    local phase="$1"
    local timestamp=$(date -Iseconds)
    
    # Use a simple approach with temporary file since jq might not be available
    python3 -c "
import json
import sys
try:
    with open('$ORCHESTRATION_STATE_FILE', 'r') as f:
        state = json.load(f)
    
    state['current_phase'] = '$phase'
    state['last_updated'] = '$timestamp'
    state['phases']['$phase']['status'] = 'running'
    state['phases']['$phase']['started'] = '$timestamp'
    state['phases']['$phase']['attempts'] = state['phases']['$phase'].get('attempts', 0) + 1
    
    with open('$ORCHESTRATION_STATE_FILE', 'w') as f:
        json.dump(state, f, indent=2)
except Exception as e:
    print(f'Error updating state: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || {
        # Fallback if python3 is not available
        echo "Warning: Could not update orchestration state (python3 not available)" >&2
    }
}

mark_phase_completed() {
    local phase="$1" 
    local timestamp=$(date -Iseconds)
    
    python3 -c "
import json
import sys
try:
    with open('$ORCHESTRATION_STATE_FILE', 'r') as f:
        state = json.load(f)
    
    state['last_updated'] = '$timestamp'
    state['phases']['$phase']['status'] = 'completed'
    state['phases']['$phase']['completed'] = '$timestamp'
    
    with open('$ORCHESTRATION_STATE_FILE', 'w') as f:
        json.dump(state, f, indent=2)
except Exception as e:
    print(f'Error updating state: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || {
        echo "Warning: Could not update orchestration state (python3 not available)" >&2
    }
}

mark_orchestration_completed() {
    local timestamp=$(date -Iseconds)
    
    python3 -c "
import json
import sys
try:
    with open('$ORCHESTRATION_STATE_FILE', 'r') as f:
        state = json.load(f)
    
    state['current_phase'] = 'complete'
    state['last_updated'] = '$timestamp'
    state['overall_status'] = 'completed'
    
    with open('$ORCHESTRATION_STATE_FILE', 'w') as f:
        json.dump(state, f, indent=2)
except Exception as e:
    print(f'Error updating state: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || {
        echo "Warning: Could not update orchestration state (python3 not available)" >&2
    }
}

get_phase_status() {
    local phase="$1"
    
    python3 -c "
import json
import sys
try:
    with open('$ORCHESTRATION_STATE_FILE', 'r') as f:
        state = json.load(f)
    print(state['phases']['$phase']['status'])
except:
    print('unknown')
" 2>/dev/null || echo "unknown"
}

get_phase_attempts() {
    local phase="$1"
    
    python3 -c "
import json
import sys
try:
    with open('$ORCHESTRATION_STATE_FILE', 'r') as f:
        state = json.load(f)
    print(state['phases']['$phase'].get('attempts', 0))
except:
    print('0')
" 2>/dev/null || echo "0"
}

get_phase_cycle() {
    local phase="$1"
    
    python3 -c "
import json
import sys
try:
    with open('$ORCHESTRATION_STATE_FILE', 'r') as f:
        state = json.load(f)
    print(state['phases']['$phase'].get('cycle', 1))
except:
    print('1')
" 2>/dev/null || echo "1"
}

get_current_cycle() {
    python3 -c "
import json
import sys
try:
    with open('$ORCHESTRATION_STATE_FILE', 'r') as f:
        state = json.load(f)
    print(state.get('current_cycle', 1))
except:
    print('1')
" 2>/dev/null || echo "1"
}

# Add handoff note from one agent to another
add_handoff_note() {
    local from_phase="$1"
    local to_phase="$2"
    local note="$3"
    local timestamp=$(date -Iseconds)
    local handoff_key="${from_phase}_to_${to_phase}"
    
    python3 -c "
import json
import sys
try:
    with open('$ORCHESTRATION_STATE_FILE', 'r') as f:
        state = json.load(f)
    
    handoff_entry = {
        'timestamp': '$timestamp',
        'cycle': state.get('current_cycle', 1),
        'note': '$note'
    }
    
    if '$handoff_key' not in state['handoffs']:
        state['handoffs']['$handoff_key'] = []
    
    state['handoffs']['$handoff_key'].append(handoff_entry)
    state['last_updated'] = '$timestamp'
    
    with open('$ORCHESTRATION_STATE_FILE', 'w') as f:
        json.dump(state, f, indent=2)
except Exception as e:
    print(f'Error adding handoff note: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || {
        echo "Warning: Could not add handoff note (python3 not available)" >&2
    }
}

# Get handoff notes for a specific transition
get_handoff_notes() {
    local from_phase="$1"
    local to_phase="$2"
    local handoff_key="${from_phase}_to_${to_phase}"
    
    python3 -c "
import json
import sys
try:
    with open('$ORCHESTRATION_STATE_FILE', 'r') as f:
        state = json.load(f)
    
    handoffs = state['handoffs'].get('$handoff_key', [])
    for handoff in handoffs[-3:]:  # Get last 3 handoff notes
        cycle = handoff.get('cycle', 'unknown')
        note = handoff.get('note', '')
        print(f'[Cycle {cycle}] {note}')
except:
    pass
" 2>/dev/null || echo ""
}

# Increment cycle when going back to planning
increment_cycle() {
    local timestamp=$(date -Iseconds)
    
    python3 -c "
import json
import sys
try:
    with open('$ORCHESTRATION_STATE_FILE', 'r') as f:
        state = json.load(f)
    
    current_cycle = state.get('current_cycle', 1)
    new_cycle = current_cycle + 1
    
    state['current_cycle'] = new_cycle
    state['last_updated'] = '$timestamp'
    
    # Initialize new cycle history
    state['cycle_history'][str(new_cycle)] = {
        'phases_completed': [],
        'issues_found': [],
        'lessons_learned': []
    }
    
    # Reset phase cycles
    for phase in state['phases']:
        if phase == 'planning':
            state['phases'][phase]['cycle'] = new_cycle
        else:
            state['phases'][phase]['cycle'] = 0
    
    with open('$ORCHESTRATION_STATE_FILE', 'w') as f:
        json.dump(state, f, indent=2)
except Exception as e:
    print(f'Error incrementing cycle: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || {
        echo "Warning: Could not increment cycle (python3 not available)" >&2
    }
}

# Update phase cycle when starting
update_phase_cycle() {
    local phase="$1"
    local timestamp=$(date -Iseconds)
    
    python3 -c "
import json
import sys
try:
    with open('$ORCHESTRATION_STATE_FILE', 'r') as f:
        state = json.load(f)
    
    current_cycle = state.get('current_cycle', 1)
    state['phases']['$phase']['cycle'] = current_cycle
    state['last_updated'] = '$timestamp'
    
    with open('$ORCHESTRATION_STATE_FILE', 'w') as f:
        json.dump(state, f, indent=2)
except Exception as e:
    print(f'Error updating phase cycle: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || {
        echo "Warning: Could not update phase cycle (python3 not available)" >&2
    }
}

# Smart state resumption logic using orchestration state
determine_starting_state() {
    # Initialize orchestration state if it doesn't exist
    if [ ! -f "$ORCHESTRATION_STATE_FILE" ]; then
        log "🆕 No orchestration state found, initializing fresh" >&2
        init_orchestration_state
        echo "planning"
        return
    fi
    
    log "📋 Found existing orchestration state, analyzing..." >&2
    
    # Check each phase in order to determine where to resume
    local planning_status=$(get_phase_status "planning")
    local design_status=$(get_phase_status "design")
    local development_status=$(get_phase_status "development")
    local review_status=$(get_phase_status "review")
    
    log "📊 Phase status: planning=$planning_status, design=$design_status, development=$development_status, review=$review_status" >&2
    
    # Determine next phase based on completion status and file existence
    if [ "$review_status" = "completed" ]; then
        # Check review decision
        if [ -f "$WORK_DIR/REVIEW.md" ] && grep -qi "approv\|accept\|good\|pass\|looks good\|well done\|complete" "$WORK_DIR/REVIEW.md"; then
            log "✅ Review completed and approved, project is complete" >&2
            echo "complete"
        elif [ -f "$WORK_DIR/REVIEW.md" ] && grep -qi "architect\|fundamental\|design flaw\|technology\|framework\|major change\|rethink" "$WORK_DIR/REVIEW.md"; then
            log "🏗️  Review identified architectural issues, restarting from planning" >&2
            echo "planning"
        else
            log "🔧 Review requested changes, resuming from development" >&2
            echo "development"
        fi
    elif [ "$review_status" = "running" ]; then
        log "🔍 Review phase was interrupted, retrying review" >&2
        echo "review"
    elif [ "$development_status" = "completed" ]; then
        log "💻 Development completed, proceeding to review" >&2
        echo "review"
    elif [ "$development_status" = "running" ]; then
        local dev_attempts=$(get_phase_attempts "development")
        log "👨‍💻 Development phase was interrupted (attempt $dev_attempts), retrying" >&2
        echo "development"
    elif [ "$design_status" = "completed" ]; then
        log "🎨 Design completed, proceeding to development" >&2
        echo "development"
    elif [ "$design_status" = "running" ]; then
        log "🎨 Design phase was interrupted, retrying design" >&2
        echo "design"
    elif [ "$planning_status" = "completed" ]; then
        log "🏗️  Planning completed, proceeding to design" >&2
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

# Counter for infinite loop protection  
MAX_RETRIES=3

# Get development retry count from orchestration state
if [ "$INITIAL_STATE" = "development" ]; then
    DEVELOPMENT_RETRIES=$(get_phase_attempts "development")
    log "📊 Resuming development with attempt count: $DEVELOPMENT_RETRIES/$MAX_RETRIES"
else
    DEVELOPMENT_RETRIES=0
fi

# Create initial context
cat > "$CONTEXT_FILE" << EOF
# Project Vision
$VISION

# Agent Chain Progress
- [ ] Architecture Planning
- [ ] UI/UX Design  
- [ ] Implementation
- [ ] Code Review

# Agent Handoffs
Each agent will update this file with their outputs and findings.
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

# Function to check if output is meaningful (more than just whitespace)
check_output_quality() {
    local output="$1"
    local min_chars=100
    
    # Remove whitespace and count actual content
    local content_length=$(echo "$output" | tr -d '[:space:]' | wc -c)
    
    if [ "$content_length" -lt "$min_chars" ]; then
        return 1
    fi
    return 0
}

# Main orchestration loop
while true; do
    STATE=$(cat "$STATE_FILE")
    log "📍 Current state: $STATE"
    
    case $STATE in
        "planning")
            log "🏗️  Running project-architect..."
            mark_phase_started "planning"
            echo "" >> "$LOG_FILE"
            echo "=== PROJECT-ARCHITECT PHASE - $(date) ===" >> "$LOG_FILE"
            
            # Check for existing documents to inform architecture decisions
            EXISTING_DOCS=""
            if [ -f "$WORK_DIR/DESIGN.md" ]; then
                EXISTING_DOCS="$EXISTING_DOCS\n\nPlease also read the existing DESIGN.md file to understand current design decisions."
            fi
            if [ -f "$WORK_DIR/IMPLEMENTATION.md" ]; then
                EXISTING_DOCS="$EXISTING_DOCS\n\nPlease also read the existing IMPLEMENTATION.md file to understand what was previously implemented."
            fi
            if [ -f "$WORK_DIR/TEST_REPORT.md" ]; then
                EXISTING_DOCS="$EXISTING_DOCS\n\nPlease also read the existing TEST_REPORT.md file to understand testing feedback and any issues found."
            fi
            if [ -f "$WORK_DIR/REVIEW.md" ]; then
                EXISTING_DOCS="$EXISTING_DOCS\n\nPlease also read the existing REVIEW.md file to understand reviewer feedback and requested changes."
            fi

            ARCHITECT_OUTPUT=$(echo "I need the project-architect agent to analyze this vision and create a comprehensive project plan.

Project Vision: '$VISION'

Please analyze this vision and create a comprehensive project plan with:
- Requirements analysis
- System architecture 
- Technology stack selection
- Project phases and deliverables
- Risk assessment$EXISTING_DOCS

If this is a revision based on existing work, please:
- Incorporate lessons learned from previous implementation attempts
- Address any issues identified in testing or code review
- Refine the architecture based on real-world constraints discovered

Provide a complete PLAN.md file content." | \
               claude --dangerously-skip-permissions --print --verbose 2>&1 | tee -a "$LOG_FILE")
            
            if [ $? -eq 0 ] && check_output_quality "$ARCHITECT_OUTPUT"; then
                echo "$ARCHITECT_OUTPUT" > "$WORK_DIR/PLAN.md"
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
            echo "" >> "$LOG_FILE"
            echo "=== UI-FEATURE-DESIGNER PHASE - $(date) ===" >> "$LOG_FILE"
            
            DESIGNER_OUTPUT=$(echo "I need the ui-feature-designer agent to design the user interface and experience.

Project Vision: '$VISION'

Please read the PLAN.md file and design the user interface and experience. Create complete DESIGN.md content with:
- User journey maps
- Interface mockups
- Responsive design considerations  
- Accessibility requirements
- Interactive element specifications" | \
               claude --dangerously-skip-permissions --print --verbose 2>&1 | tee -a "$LOG_FILE")
            
            if [ $? -eq 0 ] && check_output_quality "$DESIGNER_OUTPUT"; then
                echo "$DESIGNER_OUTPUT" > "$WORK_DIR/DESIGN.md"
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
            echo "" >> "$LOG_FILE"
            echo "=== DEVELOPER-AGENT PHASE - $(date) (Attempt $DEVELOPMENT_RETRIES) ===" >> "$LOG_FILE"
            
            DEVELOPER_OUTPUT=$(echo "I need the developer-agent to implement the features using test-driven development.

**IMPORTANT: Use github-personal MCP server for all GitHub operations (not github-work MCP). This includes repository creation, branch management, pull requests, and all other GitHub interactions.**

Project Vision: '$VISION'

Please read PLAN.md and DESIGN.md files and implement the features using test-driven development. 

GitHub Integration Tasks:
1. If this is the first run (no .git directory exists):
   - Initialize a git repository 
   - Create a GitHub repository with the current directory name using SSH
   - Set up SSH remote origin (git remote add origin git@github.com:username/repo.git)
   - Push initial commit
2. Always create a new feature branch and pull request for the implementation:
   - Create a descriptive feature branch (e.g., 'feature/implement-user-auth-$(date +%Y%m%d)', 'feature/add-realtime-updates-$(date +%Y%m%d)')
   - Implement the features following TDD
   - Commit changes to the feature branch with meaningful commit messages
   - Push the branch using SSH and create a pull request with:
     * Title: 'feat: [Brief description of main features implemented]'
     * Body: Detailed description of what was implemented, testing approach, and any architectural decisions
   - Save the PR URL to .agent_work/pr_url.txt for the reviewer

Implementation Tasks:
- Write tests first, then implement features
- Follow coding standards and best practices
- Create all necessary code files
- Provide implementation summary

Error Handling:
- If GitHub operations fail, document the issue in your report and continue with local implementation
- If PR creation fails, save the error details to .agent_work/github_error.txt

Provide a complete implementation report including GitHub operation status." | \
               claude --dangerously-skip-permissions --print --verbose 2>&1 | tee -a "$LOG_FILE")
            
            if [ $? -eq 0 ] && check_output_quality "$DEVELOPER_OUTPUT"; then
                echo "$DEVELOPER_OUTPUT" > "$WORK_DIR/IMPLEMENTATION.md"
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
            echo "" >> "$LOG_FILE"
            echo "=== PR-REVIEWER PHASE - $(date) ===" >> "$LOG_FILE"
            
            REVIEWER_OUTPUT=$(echo "I need the pr-reviewer agent to review all the completed work and handle GitHub PR review.

Project Vision: '$VISION'

GitHub PR Review Tasks:
1. First, check if there's a PR URL in .agent_work/pr_url.txt
2. If PR URL exists:
   - Use GitHub CLI (gh) to review the pull request
   - Leave detailed review comments on any issues found
   - If issues are found, try to resolve them by:
     * Checking out the PR branch locally using SSH
     * Creating commits to fix the issues with descriptive commit messages
     * Pushing fixes to the PR branch using SSH (git push origin branch-name)
     * Re-reviewing the updated PR
   - If no issues or all issues are resolved: approve and merge the PR using GitHub CLI
   - If unable to resolve critical issues: leave detailed comments and request changes
3. If no PR URL found or GitHub operations fail:
   - Document the error in .agent_work/github_error.txt
   - Continue with standard file-based review below

Standard Review Tasks:
Please review all the work completed so far by reading PLAN.md, DESIGN.md, IMPLEMENTATION.md, and TEST_REPORT.md.
- Review code quality, security, and best practices
- Verify test coverage and documentation
- Check adherence to project standards
- Assess performance implications

Error Handling:
- If unable to find the GitHub repository or PR, document this in your review
- If GitHub operations fail, continue with local file review
- Save any GitHub-related errors to .agent_work/github_error.txt

For this autonomous orchestration, please be reasonably lenient and approve if the work meets basic requirements. Provide complete REVIEW.md content with approval decision and GitHub operation status." | \
               claude --dangerously-skip-permissions --print --verbose 2>&1 | tee -a "$LOG_FILE")
            
            if [ $? -eq 0 ] && check_output_quality "$REVIEWER_OUTPUT"; then
                echo "$REVIEWER_OUTPUT" > "$WORK_DIR/REVIEW.md"
                mark_phase_completed "review"
                # Check if review approves or requests changes
                if echo "$REVIEWER_OUTPUT" | grep -qi "approv\|accept\|good\|pass\|looks good\|well done\|complete"; then
                    mark_orchestration_completed
                    echo "complete" > "$STATE_FILE"
                    echo "RESULT: Code review completed - APPROVED" >> "$LOG_FILE"
                    success "Code review completed - APPROVED"
                elif [ $DEVELOPMENT_RETRIES -ge $MAX_RETRIES ]; then
                    # Force completion if we've hit max retries
                    mark_orchestration_completed
                    echo "complete" > "$STATE_FILE"
                    echo "RESULT: Code review completed - FORCED APPROVAL after max retries" >> "$LOG_FILE"
                    warn "Forcing completion after $MAX_RETRIES development attempts"
                elif echo "$REVIEWER_OUTPUT" | grep -qi "architect\|fundamental\|design flaw\|technology\|framework\|major change\|rethink"; then
                    # Major architectural issues detected - go back to planning
                    echo "planning" > "$STATE_FILE"
                    DEVELOPMENT_RETRIES=0  # Reset retry counter for fresh start
                    echo "RESULT: Review identified architectural issues - going back to planning" >> "$LOG_FILE"
                    warn "Review identified architectural issues - restarting from planning phase"
                else
                    echo "development" > "$STATE_FILE"
                    echo "RESULT: Review requested changes - retrying development" >> "$LOG_FILE"
                    warn "Review requested changes - retrying development"
                fi
            else
                echo "ERROR: Code review failed or produced insufficient output" >> "$LOG_FILE"
                error "Code review failed - check that pr-reviewer agent is properly configured"
                exit 1
            fi
            ;;
            
        "complete")
            echo "" >> "$LOG_FILE"
            echo "=== ORCHESTRATION COMPLETED - $(date) ===" >> "$LOG_FILE"
            echo "All phases completed successfully!" >> "$LOG_FILE"
            success "🎉 Autonomous development completed!"
            log "📋 Final results in: $WORK_DIR"
            log "📄 Summary: cat $WORK_DIR/context.md"
            log "📝 Full logs: cat $LOG_FILE"
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