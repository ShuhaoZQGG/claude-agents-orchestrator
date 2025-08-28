# Simple Agent Orchestrator

A lightweight system for autonomous software development using Claude agents in sequence.

## How It Works

1. **You provide a vision**: `./orchestrate.sh "Build a task management app"`
2. **Agents run autonomously**: Each agent reads previous outputs and continues the chain
3. **No keyboard interaction**: The system runs until completion or failure

## Agent Flow

```
Vision Input → Architecture → Design → Development → Testing → Review → Complete
```

Each agent:
- Reads outputs from previous agents
- Does their specialized work  
- Writes results to `.agent_work/` directory
- Updates the state file to trigger next agent

## Usage

```bash
# Give your product vision
./orchestrate.sh "Build a real-time chat app with user authentication"

# The system runs autonomously through all phases
# Check progress in .agent_work/ directory
```

## File Structure

```
.agent_work/
├── state.txt           # Current phase (planning|design|development|testing|review|complete)
├── context.md          # Shared context updated by each agent
├── architecture.md     # Technical plan from project-architect
├── design.md           # UI/UX designs from ui-feature-designer  
├── implementation.md   # Code and implementation notes from developer-agent
├── test_results.md     # Test results from feature-tester
└── final_review.md     # Code review from pr-reviewer
```

## Agent Requirements

Agents must be installed in `~/.claude/agents/`:
- `project-architect`
- `ui-feature-designer` 
- `developer-agent`
- `feature-tester`
- `pr-reviewer`

## Benefits vs Complex Orchestrator

- ✅ **Simple**: Just a shell script vs full Node.js app
- ✅ **No infrastructure**: No Redis, Docker, Kubernetes needed
- ✅ **File-based**: Easy to debug and understand
- ✅ **Autonomous**: Truly hands-off after initial command
- ✅ **Resumable**: Can restart from any phase
- ✅ **Transparent**: All outputs visible in `.agent_work/`