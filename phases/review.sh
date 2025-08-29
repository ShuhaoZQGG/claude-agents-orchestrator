#!/bin/bash

run_review_phase() {
    local vision="$1"
    echo "" >> "$LOG_FILE"
    echo "=== PR-REVIEWER PHASE - $(date) ===" >> "$LOG_FILE"

    local prompt="I need the pr-reviewer agent to review all the completed work and handle GitHub PR review.

Project Vision: '$vision'

GitHub PR Review Tasks:
1. First, check if there's a PR URL in .agent_work/pr_url.txt
2. If PR URL exists:
   - Use GitHub CLI (gh) to review the pull request
   - Leave detailed review comments on any issues found
   - If issues are found, try to resolve them by:
     * Checking out the PR branch locally using SSH
     * Creating commits to fix the issues with descriptive commit messages
     * Pushing fixes to the PR branch using SSH (git push origin branch-name)
     * Re-reviewing the updated PR
   - If no issues or all issues are resolved: approve and merge the PR using GitHub CLI
   - If unable to resolve critical issues: leave detailed comments and request changes
3. If no PR URL found or GitHub operations fail:
   - Document the error in .agent_work/github_error.txt
   - Continue with standard file-based review below

Standard Review Tasks:
Please review all the work completed so far by reading PLAN.md, DESIGN.md, IMPLEMENTATION.md, and TEST_REPORT.md.
- Review code quality, security, and best practices
- Verify test coverage and documentation
- Check adherence to project standards
- Assess performance implications

Error Handling:
- If unable to find the GitHub repository or PR, document this in your review
- If GitHub operations fail, continue with local file review
- Save any GitHub-related errors to .agent_work/github_error.txt

For this autonomous orchestration, please be reasonably lenient and approve if the work meets basic requirements. Provide complete REVIEW.md content with approval decision and GitHub operation status."

    local output
    output=$(echo "$prompt" | eval "$CLAUDE_CMD" 2>&1 | tee -a "$LOG_FILE")
    if [ $? -eq 0 ] && check_output_quality "$output"; then
        echo "$output" > "$WORK_DIR/REVIEW.md"
        return 0
    else
        return 1
    fi
}
