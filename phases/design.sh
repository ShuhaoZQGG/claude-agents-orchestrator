#!/bin/bash

run_design_phase() {
    local vision="$1"
    echo "" >> "$LOG_FILE"
    echo "=== UI-FEATURE-DESIGNER PHASE - $(date) ===" >> "$LOG_FILE"

    local prompt="I need the ui-feature-designer agent to design the user interface and experience.

Project Vision: '$vision'

Please read the PLAN.md file and design the user interface and experience. Create complete DESIGN.md content with:
- User journey maps
- Interface mockups
- Responsive design considerations  
- Accessibility requirements
- Interactive element specifications"

    local output
    output=$(echo "$prompt" | eval "$CLAUDE_CMD" 2>&1 | tee -a "$LOG_FILE")
    if [ $? -eq 0 ] && check_output_quality "$output"; then
        echo "$output" > "$WORK_DIR/DESIGN.md"
        return 0
    else
        return 1
    fi
}
