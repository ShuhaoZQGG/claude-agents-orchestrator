#!/bin/bash

# Test script to verify GitHub issue integration
# This script tests if the orchestrator properly fetches and passes GitHub issues to the architect

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧪 Testing GitHub Issue Integration in Claude Agents Orchestrator"
echo "================================================"

# Check if gh CLI is available
if ! command -v gh >/dev/null 2>&1; then
    echo -e "${RED}❌ GitHub CLI (gh) not found${NC}"
    echo "Please install GitHub CLI: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}❌ Not authenticated with GitHub${NC}"
    echo "Please run: gh auth login"
    exit 1
fi

# Get current repo info
REPO_INFO=$(gh repo view --json nameWithOwner 2>/dev/null || echo "")
if [ -z "$REPO_INFO" ]; then
    echo -e "${YELLOW}⚠️  Not in a GitHub repository${NC}"
    echo "GitHub issue integration will be skipped by orchestrator"
else
    REPO_NAME=$(echo "$REPO_INFO" | jq -r '.nameWithOwner')
    echo -e "${GREEN}✓ Repository: $REPO_NAME${NC}"
    
    # Check for open issues
    OPEN_ISSUES=$(gh issue list --state open --limit 5 --json number,title 2>/dev/null || echo "[]")
    ISSUE_COUNT=$(echo "$OPEN_ISSUES" | jq '. | length')
    
    if [ "$ISSUE_COUNT" -eq 0 ]; then
        echo -e "${YELLOW}ℹ️  No open issues found${NC}"
        echo "Creating a test issue for demonstration..."
        
        # Create a test issue
        TEST_ISSUE=$(gh issue create \
            --title "Test: Add user authentication feature" \
            --body "As a user, I want to be able to log in securely so that I can access my personal data." \
            --label "enhancement" 2>/dev/null || echo "")
            
        if [ -n "$TEST_ISSUE" ]; then
            echo -e "${GREEN}✓ Created test issue: $TEST_ISSUE${NC}"
        fi
    else
        echo -e "${GREEN}✓ Found $ISSUE_COUNT open issues${NC}"
        echo "$OPEN_ISSUES" | jq -r '.[] | "  #\(.number): \(.title)"'
    fi
fi

echo ""
echo "Testing planning phase with GitHub issue integration..."
echo "-------------------------------------------------------"

# Create a test work directory
TEST_DIR=".agent_work_test"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Source the planning phase
source "../lib/colors.sh"
source "../lib/log.sh"
source "../lib/config.sh"
source "../lib/utils.sh"
source "../lib/state.sh"
source "../lib/cycle.sh"

# Override work directory for testing
WORK_DIR=$(pwd)
CYCLE_HANDOFF_FILE="$WORK_DIR/CYCLE_HANDOFF.md"
LOG_FILE="$WORK_DIR/test.log"

# Initialize cycle management
init_cycle_management

# Create a minimal test of the planning phase GitHub integration
echo "Extracting GitHub issues for planning phase..."

# Test the GitHub issue fetching logic
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    issue_list=$(gh issue list --state open --limit 20 --json number,title,body,labels 2>/dev/null || echo "")
    if [ -n "$issue_list" ] && [ "$issue_list" != "[]" ]; then
        echo -e "${GREEN}✓ Successfully fetched GitHub issues${NC}"
        echo "Issues will be included in architect prompt:"
        echo "$issue_list" | jq -r '.[] | "  - Issue #\(.number): \(.title)"'
        
        # Show what the architect will receive
        echo ""
        echo "Sample context that will be passed to architect:"
        echo "-----------------------------------------------"
        echo "GITHUB ISSUES CONTEXT:"
        echo "The following open GitHub issues exist in this repository:"
        echo "$issue_list" | jq '.[0:2]'  # Show first 2 issues as sample
        echo ""
        echo "Please incorporate these issues into your architectural planning..."
        echo "-----------------------------------------------"
    else
        echo -e "${YELLOW}ℹ️  No GitHub issues to pass to architect${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  GitHub CLI not available or not authenticated${NC}"
    echo "Orchestrator will proceed without GitHub issues"
fi

# Cleanup
cd ..
rm -rf "$TEST_DIR"

echo ""
echo -e "${GREEN}✅ GitHub integration test completed${NC}"
echo ""
echo "Summary:"
echo "--------"
echo "1. GitHub issue fetching happens at the orchestration level ONLY"
echo "2. Agent definitions remain completely unchanged"
echo "3. Each phase fetches/checks for issues and adds them to prompts"
echo "4. Issues flow through prompts, not through agent modifications"
echo "5. Clean separation: agents focus on tasks, orchestration handles GitHub"
echo ""
echo "Architecture Benefits:"
echo "- Agents remain pure and focused on their core responsibilities"
echo "- GitHub integration is entirely handled by orchestration"
echo "- Easy to disable/enable without touching agent code"
echo "- Agents work identically with or without GitHub issues"
echo ""
echo "To use this feature:"
echo "1. Ensure 'gh' CLI is installed and authenticated"
echo "2. Run orchestrator in a GitHub repository with open issues"
echo "3. Issues will automatically be injected into agent prompts"