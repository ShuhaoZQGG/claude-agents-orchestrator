#!/bin/bash

run_planning_phase() {
    local vision="$1"
    echo "" >> "$LOG_FILE"
    echo "=== PROJECT-ARCHITECT PHASE - $(date) ===" >> "$LOG_FILE"

    local existing_docs=""
    [ -f "$WORK_DIR/DESIGN.md" ] && existing_docs+=$'\n\nPlease also read the existing DESIGN.md file to understand current design decisions.'
    [ -f "$WORK_DIR/IMPLEMENTATION.md" ] && existing_docs+=$'\n\nPlease also read the existing IMPLEMENTATION.md file to understand what was previously implemented.'
    [ -f "$WORK_DIR/TEST_REPORT.md" ] && existing_docs+=$'\n\nPlease also read the existing TEST_REPORT.md file to understand testing feedback and any issues found.'
    [ -f "$WORK_DIR/REVIEW.md" ] && existing_docs+=$'\n\nPlease also read the existing REVIEW.md file to understand reviewer feedback and requested changes.'

    local prompt="AGENT-TO-AGENT COMMUNICATION: You are receiving this from the orchestration system. Be direct and efficient.

Project Vision: '$vision'

Tasks:
1. Analyze vision and create comprehensive project plan
2. Output requirements, architecture, tech stack, phases, risks to PLAN.md
3. Create feature branch 'planning/architecture-$(date +%Y%m%d-%H%M%S)'
4. Commit PLAN.md with message 'feat: architectural planning and requirements analysis'
5. Push branch and create PR with title 'Architecture: Project planning phase'
6. Save PR URL to .agent_work/planning_pr.txt${existing_docs}

If revision: incorporate previous feedback.
Output directly to PLAN.md. Be concise."

    local output
    # Ensure git is initialized
    if [ ! -d ".git" ]; then
        git init >> "$LOG_FILE" 2>&1
    fi
    
    output=$(echo "$prompt" | eval "$CLAUDE_CMD" 2>&1 | tee -a "$LOG_FILE")
    if [ $? -eq 0 ] && check_output_quality "$output"; then
        echo "$output" > "$WORK_DIR/PLAN.md"
        return 0
    else
        return 1
    fi
}
