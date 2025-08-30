#!/bin/bash

run_planning_phase() {
    local vision="$1"
    echo "" >> "$LOG_FILE"
    echo "=== PROJECT-ARCHITECT PHASE - $(date) ===" >> "$LOG_FILE"
    
    # Load cycle management functions
    source "$SCRIPT_DIR/lib/cycle.sh"

    local existing_docs=""
    [ -f "$WORK_DIR/DESIGN.md" ] && existing_docs+=$'\n\nPlease also read the existing DESIGN.md file to understand current design decisions.'
    [ -f "$WORK_DIR/IMPLEMENTATION.md" ] && existing_docs+=$'\n\nPlease also read the existing IMPLEMENTATION.md file to understand what was previously implemented.'
    [ -f "$WORK_DIR/TEST_REPORT.md" ] && existing_docs+=$'\n\nPlease also read the existing TEST_REPORT.md file to understand testing feedback and any issues found.'
    [ -f "$WORK_DIR/REVIEW.md" ] && existing_docs+=$'\n\nPlease also read the existing REVIEW.md file to understand reviewer feedback and requested changes.'

    # Check if we need to create a new cycle branch or use existing
    local cycle_num=$(get_current_cycle)
    
    # Check if intention changed - if so, force new branch
    if [ "$(branch_intention_changed "$vision")" = "true" ]; then
        log "🔄 Intention changed - creating new branch"
        set_cycle_branch ""  # Clear to force new branch
        set_cycle_pr_url ""  # Clear old PR
    fi
    
    local branch_name=$(get_cycle_branch)
    local existing_pr=$(check_existing_pr)
    
    local git_instructions=""
    if [ -z "$existing_pr" ]; then
        git_instructions="
Git Tasks (FIRST TIME IN CYCLE $cycle_num):
1. Create and checkout branch: '$branch_name'
2. Commit PLAN.md with message: 'feat(cycle-$cycle_num): architectural planning and requirements analysis'
3. Push branch and create PR titled: 'Cycle $cycle_num: Development Pipeline'
4. Save PR URL to .agent_work/cycle_pr.txt"
    else
        git_instructions="
Git Tasks (CONTINUING CYCLE $cycle_num):
1. Checkout existing branch: '$branch_name'
2. Commit PLAN.md with message: 'feat(cycle-$cycle_num): update architectural planning'
3. Push to existing PR: $existing_pr"
    fi
    
    # Check for handoff notes and next cycle tasks
    local handoff_context=""
    if [ -f "$CYCLE_HANDOFF_FILE" ]; then
        handoff_context="

PLEASE READ CYCLE_HANDOFF.md for context from previous phases."
    fi
    if [ -f "$NEXT_CYCLE_TASKS_FILE" ] && [ "$cycle_num" -gt 1 ]; then
        handoff_context="$handoff_context
PLEASE READ NEXT_CYCLE_TASKS.md for accumulated tasks from previous cycles."
    fi
    
    # Fetch GitHub issues if repository is configured
    local github_issues=""
    local github_context=""
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        local issue_list=$(gh issue list --state open --limit 20 --json number,title,body,labels 2>/dev/null || echo "")
        if [ -n "$issue_list" ] && [ "$issue_list" != "[]" ]; then
            # Store raw issues for handoff
            github_issues="$issue_list"
            
            # Format issues for architect prompt
            github_context="

ADDITIONAL CONTEXT - GITHUB ISSUES:
The following open GitHub issues exist in this repository and should be incorporated into your planning:

$issue_list

When creating PLAN.md, please:
1. Add a 'GitHub Issues Analysis' section that lists and categorizes these issues
2. Map each issue to specific architectural components and development phases
3. Incorporate issue requirements into your task breakdown
4. Prioritize issues based on their impact and dependencies"
        fi
    fi
    
    local prompt="AGENT-TO-AGENT COMMUNICATION: Cycle $cycle_num Planning Phase

Project Vision: '$vision'$github_context

Tasks:
1. Analyze vision and create comprehensive project plan
2. Output requirements, architecture, tech stack, phases, risks to PLAN.md$git_instructions${existing_docs}${handoff_context}

<!-- HANDOFF_START -->
Update CYCLE_HANDOFF.md with:
- Completed: Planning phase with key architectural decisions
- Pending: Any unresolved questions for design phase
- Technical: Major technology choices made
<!-- HANDOFF_END -->

Output directly to PLAN.md. Be concise."

    local output
    # Ensure git is initialized
    if [ ! -d ".git" ]; then
        git init >> "$LOG_FILE" 2>&1
    fi
    
    output=$(echo "$prompt" | eval "$CLAUDE_CMD" 2>&1 | tee -a "$LOG_FILE")
    if [ $? -eq 0 ] && check_output_quality "$output"; then
        echo "$output" > "$WORK_DIR/PLAN.md"
        
        # Update cycle handoff
        update_handoff_completed "Planning" "Created architectural plan and requirements"
        
        # If GitHub issues were found, store them for downstream phases
        if [ -n "$github_issues" ]; then
            echo "" >> "$CYCLE_HANDOFF_FILE"
            echo "## GitHub Issues (Raw Data)" >> "$CYCLE_HANDOFF_FILE"
            echo '```json' >> "$CYCLE_HANDOFF_FILE"
            echo "$github_issues" >> "$CYCLE_HANDOFF_FILE"
            echo '```' >> "$CYCLE_HANDOFF_FILE"
            echo "" >> "$CYCLE_HANDOFF_FILE"
            echo "Note: These issues have been analyzed and mapped in PLAN.md" >> "$CYCLE_HANDOFF_FILE"
        fi
        
        # Check and save PR URL if created
        if [ -f "$WORK_DIR/cycle_pr.txt" ]; then
            local pr_url=$(cat "$WORK_DIR/cycle_pr.txt")
            set_cycle_pr_url "$pr_url"
        fi
        
        return 0
    else
        return 1
    fi
}
