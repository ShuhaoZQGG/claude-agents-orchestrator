#!/bin/bash

run_development_phase() {
    local vision="$1"
    local attempt="$2"
    echo "" >> "$LOG_FILE"
    echo "=== DEVELOPER-AGENT PHASE - $(date) (Attempt $attempt) ===" >> "$LOG_FILE"
    
    # Load cycle management functions
    source "$SCRIPT_DIR/lib/cycle.sh"

    # Use existing cycle branch
    local cycle_num=$(get_current_cycle)
    local branch_name=$(get_cycle_branch)
    local existing_pr=$(get_cycle_pr_url)
    
    local git_instructions="
Git Tasks (CONTINUING CYCLE $cycle_num, Attempt $attempt):
1. IMPORTANT: First ensure you're on latest main branch (git checkout main && git pull)
2. Create/checkout branch: '$branch_name' (branch from main, not from other branches)
3. Implement features using TDD approach
4. Commit code with message: 'feat(cycle-$cycle_num): implement core features (attempt $attempt)'
5. Push to branch and create PR targeting MAIN branch (not any feature branch)
6. CRITICAL: PR must target 'main' or 'master' branch, never target other feature branches"
    
    # Check for handoff notes and review feedback
    local handoff_context=""
    if [ -f "$CYCLE_HANDOFF_FILE" ]; then
        handoff_context="

PLEASE READ CYCLE_HANDOFF.md for context from design phase."
    fi
    if [ -f "$WORK_DIR/REVIEW.md" ] && [ $attempt -gt 1 ]; then
        handoff_context="$handoff_context
IMPORTANT: Read REVIEW.md for feedback from previous attempt."
    fi
    
    # Check if GitHub issues are in handoff
    local github_context=""
    if [ -f "$CYCLE_HANDOFF_FILE" ] && grep -q "## GitHub Issues" "$CYCLE_HANDOFF_FILE"; then
        github_context="

NOTE: GitHub issues have been mapped in PLAN.md. When implementing:
- Focus on addressing the specific issues identified
- Reference issue numbers in your commits when fixing them
- Ensure your implementation solves the problems described
- Test that your code addresses the issue requirements"
    fi
    
    local prompt="AGENT-TO-AGENT COMMUNICATION: Cycle $cycle_num Development Phase (Attempt $attempt)

Project Vision: '$vision'$github_context

CRITICAL PR COORDINATION RULES:
- ALWAYS pull latest main before creating branch
- NEVER create PR targeting another feature branch
- ALL PRs must target 'main' or 'master' branch
- Wait for previous PR to be merged before starting new work
- If there's an existing unmerged PR, DO NOT create another one

Tasks:
1. Check for any existing unmerged PRs and ensure they're reviewed/merged first
2. Read PLAN.md and DESIGN.md for requirements
3. Pull latest main branch before starting work
4. Implement features using TDD approach
5. Write tests first, then implementation$git_instructions${handoff_context}

**IMPORTANT: Use github-personal MCP for GitHub operations.**

If GitHub repo doesn't exist:
- Create repository matching current directory name
- Set up SSH remote

PR CREATION RULES:
- Base branch: main (always)
- Target branch: main (always)
- Never stack PRs on top of each other

<!-- HANDOFF_START -->
Update CYCLE_HANDOFF.md with:
- Completed: Development tasks implemented
- Pending: Any incomplete features or known issues
- Technical: Implementation decisions and trade-offs
<!-- HANDOFF_END -->

<!-- MARKERS_START -->
Add status marker to your output:
- If ALL planned features are complete: <!-- FEATURES_STATUS: ALL_COMPLETE -->
- If some features remain: <!-- FEATURES_STATUS: PARTIAL_COMPLETE -->
- If need new requirements: <!-- FEATURES_STATUS: NEEDS_PLANNING -->
<!-- MARKERS_END -->

Output summary to IMPLEMENTATION.md. Be concise."

    local output
    output=$(echo "$prompt" | eval "$CLAUDE_CMD" 2>&1 | tee -a "$LOG_FILE")
    if [ $? -eq 0 ] && check_output_quality "$output"; then
        echo "$output" > "$WORK_DIR/IMPLEMENTATION.md"
        
        # Update cycle handoff
        update_handoff_completed "Development" "Implemented features with TDD (attempt $attempt)"
        
        return 0
    else
        return 1
    fi
}
