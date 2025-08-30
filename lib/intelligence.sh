#!/bin/bash

# Intelligent Orchestration Library
# Uses AI signals from agents to make smart decisions about cycle flow

# Check if all planned features are implemented
check_features_complete() {
    local marker=""
    
    # Look for completion marker in IMPLEMENTATION.md
    if [ -f "$WORK_DIR/IMPLEMENTATION.md" ]; then
        marker=$(grep -o "<!-- FEATURES_STATUS: [A-Z_]* -->" "$WORK_DIR/IMPLEMENTATION.md" 2>/dev/null | head -1 | sed 's/<!-- FEATURES_STATUS: \(.*\) -->/\1/')
    fi
    
    if [ "$marker" = "ALL_COMPLETE" ]; then
        echo "true"
    elif [ "$marker" = "PARTIAL_COMPLETE" ]; then
        echo "false"
    else
        # Fallback: check if implementation mentions "all features"
        if grep -qi "all features.*implement\|implement.*all features\|completed all\|finished all" "$WORK_DIR/IMPLEMENTATION.md" 2>/dev/null; then
            echo "true"
        else
            echo "false"
        fi
    fi
}

# Check if architecture needs update
needs_architecture_update() {
    local marker=""
    
    # Look for architecture need marker in REVIEW.md
    if [ -f "$WORK_DIR/REVIEW.md" ]; then
        marker=$(grep -o "<!-- ARCHITECTURE_NEEDED: [A-Z_]* -->" "$WORK_DIR/REVIEW.md" 2>/dev/null | head -1 | sed 's/<!-- ARCHITECTURE_NEEDED: \(.*\) -->/\1/')
    fi
    
    if [ "$marker" = "YES" ]; then
        echo "true"
    elif [ "$marker" = "NO" ]; then
        echo "false"
    else
        # Fallback: check review feedback
        if grep -qi "architect\|fundamental\|design flaw\|technology\|framework\|major change\|rethink\|new feature\|additional requirement" "$WORK_DIR/REVIEW.md" 2>/dev/null; then
            echo "true"
        else
            echo "false"
        fi
    fi
}

# Check if design needs update
needs_design_update() {
    local marker=""
    
    # Look for design need marker
    if [ -f "$WORK_DIR/REVIEW.md" ]; then
        marker=$(grep -o "<!-- DESIGN_NEEDED: [A-Z_]* -->" "$WORK_DIR/REVIEW.md" 2>/dev/null | head -1 | sed 's/<!-- DESIGN_NEEDED: \(.*\) -->/\1/')
    fi
    
    if [ "$marker" = "YES" ]; then
        echo "true"
    elif [ "$marker" = "NO" ]; then
        echo "false"
    else
        # Fallback: check for UI/UX mentions
        if grep -qi "ui\|ux\|user interface\|user experience\|design\|layout\|mockup\|workflow" "$WORK_DIR/REVIEW.md" 2>/dev/null; then
            echo "true"
        else
            echo "false"
        fi
    fi
}

# Determine if we should skip planning phase
should_skip_planning() {
    local features_complete=$(check_features_complete)
    local needs_architecture=$(needs_architecture_update)
    
    if [ "$features_complete" = "false" ] && [ "$needs_architecture" = "false" ]; then
        log "🎯 Skipping planning - continuing with remaining features"
        echo "true"
    else
        echo "false"
    fi
}

# Determine if we should skip design phase
should_skip_design() {
    local needs_design=$(needs_design_update)
    
    if [ "$needs_design" = "false" ]; then
        log "🎨 Skipping design - no UI/UX changes needed"
        echo "true"
    else
        echo "false"
    fi
}

# Check if branch intention has changed significantly
branch_intention_changed() {
    local current_branch=$(git branch --show-current 2>/dev/null)
    local vision="$1"
    
    # Extract key words from vision
    local vision_keywords=$(echo "$vision" | tr '[:upper:]' '[:lower:]' | grep -o '\b[a-z]\{4,\}\b' | sort -u | head -5 | tr '\n' '-')
    
    # Check if current branch matches vision keywords
    if [ -n "$current_branch" ] && [ "$current_branch" != "main" ] && [ "$current_branch" != "master" ]; then
        # If branch doesn't contain any vision keywords, intention has changed
        for keyword in $(echo "$vision_keywords" | tr '-' ' '); do
            if echo "$current_branch" | grep -qi "$keyword"; then
                echo "false"
                return
            fi
        done
        echo "true"
    else
        echo "false"
    fi
}

# Generate appropriate branch name based on current work
generate_smart_branch_name() {
    local cycle_num="$1"
    local phase="$2"
    local vision="$3"
    
    # Extract main feature from vision or current work
    local feature_name=""
    
    if [ -f "$WORK_DIR/IMPLEMENTATION.md" ]; then
        # Try to extract from implementation focus
        feature_name=$(grep -m1 -i "implementing\|feature\|functionality" "$WORK_DIR/IMPLEMENTATION.md" | sed 's/.*implementing\|.*feature\|.*functionality//i' | tr -d '[:punct:]' | tr '[:upper:]' '[:lower:]' | awk '{print $1"-"$2}' | sed 's/-$//')
    fi
    
    if [ -z "$feature_name" ]; then
        # Fallback to vision keywords
        feature_name=$(echo "$vision" | tr '[:upper:]' '[:lower:]' | grep -o '\b[a-z]\{4,\}\b' | head -2 | tr '\n' '-' | sed 's/-$//')
    fi
    
    if [ -z "$feature_name" ]; then
        feature_name="development"
    fi
    
    echo "cycle-${cycle_num}-${feature_name}-$(date +%Y%m%d-%H%M%S)"
}

# Check if PR should be merged to main
should_merge_to_main() {
    local decision="$1"
    local pr_url="$2"
    
    if [ "$decision" = "APPROVED" ] && [ -n "$pr_url" ]; then
        # Check if there are no breaking changes mentioned
        if [ -f "$WORK_DIR/REVIEW.md" ]; then
            if ! grep -qi "breaking change\|backward.*incompatible\|migration.*required\|major.*version" "$WORK_DIR/REVIEW.md"; then
                echo "true"
            else
                log "⚠️ Breaking changes detected - manual merge required"
                echo "false"
            fi
        else
            echo "true"
        fi
    else
        echo "false"
    fi
}

# Extract PR number from URL
extract_pr_number() {
    local pr_url="$1"
    echo "$pr_url" | grep -o '/pull/[0-9]*' | cut -d'/' -f3
}

# Extract repo info from PR URL
extract_repo_info() {
    local pr_url="$1"
    # Extract owner/repo from URL like https://github.com/owner/repo/pull/123
    echo "$pr_url" | sed -n 's|.*github.com/\([^/]*/[^/]*\)/pull/.*|\1|p'
}