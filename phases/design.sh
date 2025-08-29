#!/bin/bash

run_design_phase() {
    local vision="$1"
    echo "" >> "$LOG_FILE"
    echo "=== UI-FEATURE-DESIGNER PHASE - $(date) ===" >> "$LOG_FILE"

    local prompt="AGENT-TO-AGENT COMMUNICATION: You are receiving this from the orchestration system. Be direct and efficient.

Project Vision: '$vision'

Tasks:
1. Read PLAN.md and design UI/UX
2. Output user journeys, mockups, responsive design, accessibility specs to DESIGN.md
3. Create feature branch 'design/ui-ux-$(date +%Y%m%d-%H%M%S)'
4. Commit DESIGN.md with message 'feat: UI/UX design specifications'
5. Push branch and create PR with title 'Design: UI/UX specifications phase'
6. Save PR URL to .agent_work/design_pr.txt

Output directly to DESIGN.md. Be concise."

    local output
    # Ensure git is initialized
    if [ ! -d ".git" ]; then
        git init >> "$LOG_FILE" 2>&1
    fi
    
    output=$(echo "$prompt" | eval "$CLAUDE_CMD" 2>&1 | tee -a "$LOG_FILE")
    if [ $? -eq 0 ] && check_output_quality "$output"; then
        echo "$output" > "$WORK_DIR/DESIGN.md"
        return 0
    else
        return 1
    fi
}
