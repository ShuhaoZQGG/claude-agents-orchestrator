#!/bin/bash

run_review_phase() {
    local vision="$1"
    echo "" >> "$LOG_FILE"
    echo "=== PR-REVIEWER PHASE - $(date) ===" >> "$LOG_FILE"
    
    # Load cycle management functions
    source "$SCRIPT_DIR/lib/cycle.sh"

    # Get cycle information
    local cycle_num=$(get_current_cycle)
    local branch_name=$(get_cycle_branch)
    local cycle_pr=$(get_cycle_pr_url)
    
    # Check for handoff notes
    local handoff_context=""
    if [ -f "$CYCLE_HANDOFF_FILE" ]; then
        handoff_context="

PLEASE READ CYCLE_HANDOFF.md for full cycle context."
    fi
    
    local prompt="AGENT-TO-AGENT COMMUNICATION: Cycle $cycle_num Review Phase

Project Vision: '$vision'

Tasks:
1. Review the cycle PR: ${cycle_pr:-'Check .agent_work/cycle_pr.txt'}
2. Review local files: PLAN.md, DESIGN.md, IMPLEMENTATION.md
3. Evaluate:
   - Code quality, security, tests
   - Adherence to plan and design
   - Completeness of implementation
4. Make decision and add ALL these markers:
   Decision: <!-- CYCLE_DECISION: APPROVED|NEEDS_REVISION|NEEDS_ARCHITECTURE_CHANGE -->
   Architecture: <!-- ARCHITECTURE_NEEDED: YES|NO -->
   Design: <!-- DESIGN_NEEDED: YES|NO -->
   Breaking: <!-- BREAKING_CHANGES: YES|NO -->
5. If APPROVED and no breaking changes: merge PR to main using GitHub CLI:
   - Use 'gh pr merge --squash --delete-branch PR_NUMBER'
   - Create new branch for next cycle if work continues
6. Update NEXT_CYCLE_TASKS.md with any deferred items${handoff_context}

**IMPORTANT: Use github-personal MCP for GitHub operations.**

MERGE STRATEGY:
- If approved with no breaking changes: MERGE TO MAIN immediately
- After merge: create NEW branch for next cycle (don't reuse old branch)
- Each cycle should have its own branch and PR for clean history

<!-- HANDOFF_START -->
Update CYCLE_HANDOFF.md with:
- Completed: Review findings and decision
- Pending: Required changes or improvements
- Technical: Critical issues found
<!-- HANDOFF_END -->

For NEXT_CYCLE_TASKS.md add:
- Any technical debt identified
- Feature enhancements discovered
- Documentation needs

Output review to REVIEW.md with decision marker. Be concise but thorough."

    local output
    output=$(echo "$prompt" | eval "$CLAUDE_CMD" 2>&1 | tee -a "$LOG_FILE")
    if [ $? -eq 0 ] && check_output_quality "$output"; then
        echo "$output" > "$WORK_DIR/REVIEW.md"
        
        # Extract and record decision
        local decision=$(extract_review_decision)
        update_handoff_completed "Review" "Completed with decision: $decision"
        
        # Record cycle completion if approved
        if [ "$decision" = "APPROVED" ]; then
            record_cycle_completion "$cycle_num" "completed" "$decision"
        fi
        
        return 0
    else
        return 1
    fi
}
