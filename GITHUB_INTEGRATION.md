# GitHub Issue Integration

## Overview

The Claude Agents Orchestrator now supports automatic GitHub issue integration. When running in a GitHub repository with open issues, the orchestrator will:

1. **Fetch open issues** at the orchestration level (not within agents)
2. **Pass issues to agents** through their prompts as additional context
3. **Map issues to architectural components** during planning phase
4. **Communicate issue context** to all phases via prompts and CYCLE_HANDOFF.md

## How It Works

### 1. Issue Fetching (Orchestration Level)

The planning phase (`phases/planning.sh`) now includes logic to fetch GitHub issues:

```bash
# Fetch GitHub issues if repository is configured
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    issue_list=$(gh issue list --state open --limit 20 --json number,title,body,labels)
    # Issues are included in the architect's prompt
fi
```

### 2. Context Injection

Each phase receives GitHub issue context through its prompt:
- **Planning Phase**: Full issue list with instructions to map to architecture
- **Design Phase**: Reminder to consider issue requirements in UI/UX
- **Development Phase**: Instructions to address and reference issues in commits
- **Review Phase**: Validation that issues have been addressed

### 3. Agent Independence

- **Agents remain unchanged** - they don't know about GitHub integration
- **Orchestration handles everything** - fetches issues and injects context
- **Clean separation** - agents focus on their core responsibilities
- **No dependencies** - agents work the same with or without GitHub issues

## Prerequisites

### Required Tools

1. **GitHub CLI (`gh`)**: Install from https://cli.github.com/
2. **Authentication**: Run `gh auth login` to authenticate

### Repository Setup

- Must be a GitHub repository
- Should have open issues for the architect to analyze
- Issues should have descriptive titles and bodies

## Usage

### Basic Usage

```bash
# Run orchestrator normally - it will automatically detect and use GitHub issues
./orchestrate.sh "Build a task management application"
```

### Testing Integration

```bash
# Run the test script to verify GitHub integration
./test-github-integration.sh
```

## Architecture Changes

### Modified Files (Orchestration Only)

1. **phases/planning.sh**
   - Fetches GitHub issues using `gh` CLI
   - Injects issues into architect's prompt
   - Stores issues in CYCLE_HANDOFF.md for downstream phases

2. **phases/design.sh**
   - Checks for GitHub issues in CYCLE_HANDOFF.md
   - Adds context to designer's prompt if issues exist

3. **phases/development.sh**
   - Checks for GitHub issues in CYCLE_HANDOFF.md
   - Adds implementation guidance to developer's prompt

4. **phases/review.sh**
   - Checks for GitHub issues in CYCLE_HANDOFF.md
   - Adds validation criteria to reviewer's prompt

### Unchanged Files

**All agent definitions remain unchanged:**
- `agents/project-architect.md` - No modifications
- `agents/ui-feature-designer.md` - No modifications
- `agents/developer-agent.md` - No modifications
- `agents/pr-reviewer.md` - No modifications

## Example Output

When GitHub issues are present, PLAN.md will include:

```markdown
## GitHub Issues Analysis

### Open Issues
- #1: Add user authentication (enhancement)
- #2: Fix database connection timeout (bug)
- #3: Implement real-time notifications (feature)

### Issue Mapping

#### Authentication Component
- Issue #1: User authentication system
  - Phase: Sprint 1
  - Tasks: OAuth integration, session management

#### Infrastructure
- Issue #2: Database connection pooling
  - Phase: Sprint 0 (Foundation)
  - Tasks: Connection retry logic, timeout configuration
```

## Benefits

1. **Automatic Requirements Gathering**: Open issues are automatically incorporated into planning
2. **Traceability**: Clear mapping from issues to implementation
3. **Coordination**: All agents are aware of GitHub issues through handoff mechanism
4. **No Breaking Changes**: Feature is optional and doesn't affect existing workflows

## Limitations

- Requires GitHub CLI and authentication
- Fetches up to 20 most recent open issues
- Only works with GitHub repositories (not GitLab, Bitbucket, etc.)
- Issues must be well-described for effective planning

## Future Enhancements

Potential improvements:
- Support for issue priorities and milestones
- Automatic issue updates when tasks complete
- Support for other issue tracking systems
- Integration with GitHub Projects
- Automatic PR linking to issues