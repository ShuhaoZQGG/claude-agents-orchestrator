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

    local prompt="I need the project-architect agent to analyze this vision and create a comprehensive project plan.

Project Vision: '$vision'

Please analyze this vision and create a comprehensive project plan with:
- Requirements analysis
- System architecture 
- Technology stack selection
- Project phases and deliverables
- Risk assessment${existing_docs}

If this is a revision based on existing work, please:
- Incorporate lessons learned from previous implementation attempts
- Address any issues identified in testing or code review
- Refine the architecture based on real-world constraints discovered

Provide a complete PLAN.md file content."

    local output
    output=$(echo "$prompt" | eval "$CLAUDE_CMD" 2>&1 | tee -a "$LOG_FILE")
    if [ $? -eq 0 ] && check_output_quality "$output"; then
        echo "$output" > "$WORK_DIR/PLAN.md"
        return 0
    else
        return 1
    fi
}
