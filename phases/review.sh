#!/bin/bash

run_review_phase() {
    local vision="$1"
    echo "" >> "$LOG_FILE"
    echo "=== PR-REVIEWER PHASE - $(date) ===" >> "$LOG_FILE"

    local prompt="AGENT-TO-AGENT COMMUNICATION: You are receiving this from the orchestration system. Be direct and efficient.

Project Vision: '$vision'

Tasks:
1. Review ALL existing PRs in the repository using GitHub CLI
2. For each open PR:
   - Review code quality, security, tests
   - If acceptable: approve and merge using squash merge
   - If issues: attempt fixes directly on PR branch, then merge
   - Close stale/duplicate PRs
3. Check PR URLs in:
   - .agent_work/planning_pr.txt
   - .agent_work/design_pr.txt  
   - .agent_work/dev_pr.txt
4. Review local files: PLAN.md, DESIGN.md, IMPLEMENTATION.md
5. Output review summary to REVIEW.md with:
   - PRs reviewed and merged
   - Issues found and resolved
   - Final approval decision

**IMPORTANT: Use github-personal MCP for GitHub operations.**

Be lenient - approve if work meets basic requirements.
Output directly to REVIEW.md. Be concise."

    local output
    output=$(echo "$prompt" | eval "$CLAUDE_CMD" 2>&1 | tee -a "$LOG_FILE")
    if [ $? -eq 0 ] && check_output_quality "$output"; then
        echo "$output" > "$WORK_DIR/REVIEW.md"
        return 0
    else
        return 1
    fi
}
