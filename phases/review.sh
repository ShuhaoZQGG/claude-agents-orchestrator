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
    
    # Check if GitHub issues are in handoff
    local github_context=""
    if [ -f "$CYCLE_HANDOFF_FILE" ] && grep -q "## GitHub Issues" "$CYCLE_HANDOFF_FILE"; then
        github_context="

NOTE: GitHub issues were incorporated into this cycle. When reviewing:
- Check if the implementation addresses the issues identified
- Verify that issue requirements have been met
- Consider whether issues can be closed after this cycle"
    fi
    
    local prompt="AGENT-TO-AGENT COMMUNICATION: Cycle $cycle_num Review Phase

Project Vision: '$vision'$github_context

CRITICAL MERGE COORDINATION:
- YOU MUST MERGE APPROVED PRs TO MAIN BEFORE NEXT DEVELOPER STARTS
- This prevents conflicts between multiple developers working in parallel
- Never leave PRs unmerged when moving to next cycle

Tasks:
1. Review the cycle PR: ${cycle_pr:-'Check .agent_work/cycle_pr.txt'}
2. Verify PR targets main branch (reject if targeting feature branch)
3. Review local files: PLAN.md, DESIGN.md, IMPLEMENTATION.md
4. Evaluate:
   - Code quality, security, tests
   - Adherence to plan and design
   - Completeness of implementation
5. Make decision and add ALL these markers:
   Decision: <!-- CYCLE_DECISION: APPROVED|NEEDS_REVISION|NEEDS_ARCHITECTURE_CHANGE -->
   Architecture: <!-- ARCHITECTURE_NEEDED: YES|NO -->
   Design: <!-- DESIGN_NEEDED: YES|NO -->
   Breaking: <!-- BREAKING_CHANGES: YES|NO -->
6. MANDATORY IF APPROVED: Immediately merge PR to main using GitHub CLI:
   - Use 'gh pr merge --squash --delete-branch PR_NUMBER'
   - DO NOT SKIP THIS STEP - merge must happen before next developer
   - Verify merge succeeded before completing review
7. After merge: ensure next cycle starts from fresh main branch
8. Update NEXT_CYCLE_TASKS.md with any deferred items${handoff_context}

**IMPORTANT: Use github-personal MCP for GitHub operations.**

MERGE STRATEGY (MANDATORY):
- If APPROVED: MUST merge to main immediately (no exceptions)
- Merge method: squash and delete branch
- After merge: next developer starts fresh from updated main
- NEVER leave approved PRs unmerged
- Each cycle must complete its merge before next begins

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
