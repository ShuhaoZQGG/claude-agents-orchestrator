#!/bin/bash

run_development_phase() {
    local vision="$1"
    local attempt="$2"
    echo "" >> "$LOG_FILE"
    echo "=== DEVELOPER-AGENT PHASE - $(date) (Attempt $attempt) ===" >> "$LOG_FILE"

    local prompt="AGENT-TO-AGENT COMMUNICATION: You are receiving this from the orchestration system. Be direct and efficient.

Project Vision: '$vision'
Attempt: $attempt

Tasks:
1. Read PLAN.md and DESIGN.md
2. Implement features using TDD approach
3. Create feature branch 'development/implementation-$(date +%Y%m%d-%H%M%S)'
4. Write tests first, then implementation
5. Commit all code with descriptive messages
6. Push branch and create PR with title 'Implementation: Core features development'
7. Save PR URL to .agent_work/dev_pr.txt
8. Output summary to IMPLEMENTATION.md

**IMPORTANT: Use github-personal MCP for GitHub operations.**

If GitHub repo doesn't exist:
- Create repository matching current directory name
- Set up SSH remote
- Push initial commit

Output directly to IMPLEMENTATION.md. Be concise."

    local output
    output=$(echo "$prompt" | eval "$CLAUDE_CMD" 2>&1 | tee -a "$LOG_FILE")
    if [ $? -eq 0 ] && check_output_quality "$output"; then
        echo "$output" > "$WORK_DIR/IMPLEMENTATION.md"
        return 0
    else
        return 1
    fi
}
