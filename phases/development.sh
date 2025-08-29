#!/bin/bash

run_development_phase() {
    local vision="$1"
    local attempt="$2"
    echo "" >> "$LOG_FILE"
    echo "=== DEVELOPER-AGENT PHASE - $(date) (Attempt $attempt) ===" >> "$LOG_FILE"

    local prompt="I need the developer-agent to implement the features using test-driven development.

**IMPORTANT: Use github-personal MCP server for all GitHub operations (not github-work MCP). This includes repository creation, branch management, pull requests, and all other GitHub interactions.**

Project Vision: '$vision'

Please read PLAN.md and DESIGN.md files and implement the features using test-driven development. 

GitHub Integration Tasks:
1. If this is the first run (no .git directory exists):
   - Initialize a git repository 
   - Create a GitHub repository with the current directory name using SSH
   - Set up SSH remote origin (git remote add origin git@github.com:username/repo.git)
   - Push initial commit
2. Always create a new feature branch and pull request for the implementation:
   - Create a descriptive feature branch (e.g., 'feature/implement-user-auth-$(date +%Y%m%d)', 'feature/add-realtime-updates-$(date +%Y%m%d)')
   - Implement the features following TDD
   - Commit changes to the feature branch with meaningful commit messages
   - Push the branch using SSH and create a pull request with:
     * Title: 'feat: [Brief description of main features implemented]'
     * Body: Detailed description of what was implemented, testing approach, and any architectural decisions
   - Save the PR URL to .agent_work/pr_url.txt for the reviewer

Implementation Tasks:
- Write tests first, then implement features
- Follow coding standards and best practices
- Create all necessary code files
- Provide implementation summary

Error Handling:
- If GitHub operations fail, document the issue in your report and continue with local implementation
- If PR creation fails, save the error details to .agent_work/github_error.txt

Provide a complete implementation report including GitHub operation status."

    local output
    output=$(echo "$prompt" | eval "$CLAUDE_CMD" 2>&1 | tee -a "$LOG_FILE")
    if [ $? -eq 0 ] && check_output_quality "$output"; then
        echo "$output" > "$WORK_DIR/IMPLEMENTATION.md"
        return 0
    else
        return 1
    fi
}
