#!/bin/bash

run_design_phase() {
    local vision="$1"
    echo "" >> "$LOG_FILE"
    echo "=== UI-FEATURE-DESIGNER PHASE - $(date) ===" >> "$LOG_FILE"
    
    # Load cycle management functions
    source "$SCRIPT_DIR/lib/cycle.sh"

    # Use existing cycle branch
    local cycle_num=$(get_current_cycle)
    local branch_name=$(get_cycle_branch)
    local existing_pr=$(get_cycle_pr_url)
    
    local git_instructions="
Git Tasks (CONTINUING CYCLE $cycle_num):
1. Checkout existing branch: '$branch_name'
2. Commit DESIGN.md with message: 'feat(cycle-$cycle_num): UI/UX design specifications'
3. Push to existing PR: ${existing_pr:-'(create if not exists)'}"
    
    # Check for handoff notes
    local handoff_context=""
    if [ -f "$CYCLE_HANDOFF_FILE" ]; then
        handoff_context="

PLEASE READ CYCLE_HANDOFF.md for context from planning phase."
    fi
    
    local prompt="AGENT-TO-AGENT COMMUNICATION: Cycle $cycle_num Design Phase

Project Vision: '$vision'

Tasks:
1. Read PLAN.md and design UI/UX
2. Output user journeys, mockups, responsive design, accessibility specs to DESIGN.md$git_instructions${handoff_context}

<!-- HANDOFF_START -->
Update CYCLE_HANDOFF.md with:
- Completed: Design phase with UI/UX specifications
- Pending: Any design constraints for development
- Technical: Frontend framework recommendations
<!-- HANDOFF_END -->

Output directly to DESIGN.md. Be concise."

    local output
    # Ensure git is initialized
    if [ ! -d ".git" ]; then
        git init >> "$LOG_FILE" 2>&1
    fi
    
    output=$(echo "$prompt" | eval "$CLAUDE_CMD" 2>&1 | tee -a "$LOG_FILE")
    if [ $? -eq 0 ] && check_output_quality "$output"; then
        echo "$output" > "$WORK_DIR/DESIGN.md"
        
        # Update cycle handoff
        update_handoff_completed "Design" "Created UI/UX specifications and mockups"
        
        return 0
    else
        return 1
    fi
}
