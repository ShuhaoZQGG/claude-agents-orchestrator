#!/bin/bash

# Functions operating on $ORCHESTRATION_STATE_FILE; mirrors original logic

init_orchestration_state() {
    cat > "$ORCHESTRATION_STATE_FILE" << EOF
{
  "current_phase": "planning",
  "current_cycle": 1,
  "last_updated": "$(date -Iseconds)",
  "phases": {
    "planning": {"status": "pending", "started": null, "completed": null, "attempts": 0, "cycle": 1},
    "design": {"status": "pending", "started": null, "completed": null, "attempts": 0, "cycle": 0},
    "development": {"status": "pending", "started": null, "completed": null, "attempts": 0, "cycle": 0},
    "review": {"status": "pending", "started": null, "completed": null, "attempts": 0, "cycle": 0}
  },
  "overall_status": "in_progress",
  "handoffs": {
    "planning_to_design": [],
    "design_to_development": [],
    "development_to_review": [],
    "review_to_planning": [],
    "planning_to_planning": [],
    "design_to_design": [],
    "development_to_development": [],
    "review_to_review": []
  },
  "cycle_history": {
    "1": {"phases_completed": [], "issues_found": [], "lessons_learned": []}
  }
}
EOF
}

mark_phase_started() {
    local phase="$1"
    local timestamp
    timestamp=$(date -Iseconds)
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Warning: Could not update orchestration state (python3 not available)" >&2
        return 0
    fi
    python3 - <<PY 2>/dev/null || true
import json, sys
try:
    with open(r"$ORCHESTRATION_STATE_FILE","r") as f:
        state=json.load(f)
    state['current_phase'] = "$phase"
    state['last_updated'] = "$timestamp"
    state['phases']["$phase"]["status"] = 'running'
    state['phases']["$phase"]["started"] = "$timestamp"
    state['phases']["$phase"]["attempts"] = state['phases']["$phase"].get('attempts',0)+1
    with open(r"$ORCHESTRATION_STATE_FILE","w") as f:
        json.dump(state,f,indent=2)
except Exception as e:
    sys.exit(1)
PY
}

mark_phase_completed() {
    local phase="$1"
    local timestamp
    timestamp=$(date -Iseconds)
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Warning: Could not update orchestration state (python3 not available)" >&2
        return 0
    fi
    python3 - <<PY 2>/dev/null || true
import json, sys
try:
    with open(r"$ORCHESTRATION_STATE_FILE","r") as f:
        state=json.load(f)
    state['last_updated'] = "$timestamp"
    state['phases']["$phase"]["status"] = 'completed'
    state['phases']["$phase"]["completed"] = "$timestamp"
    with open(r"$ORCHESTRATION_STATE_FILE","w") as f:
        json.dump(state,f,indent=2)
except Exception as e:
    sys.exit(1)
PY
}

mark_orchestration_completed() {
    local timestamp
    timestamp=$(date -Iseconds)
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Warning: Could not update orchestration state (python3 not available)" >&2
        return 0
    fi
    python3 - <<PY 2>/dev/null || true
import json, sys
try:
    with open(r"$ORCHESTRATION_STATE_FILE","r") as f:
        state=json.load(f)
    state['current_phase'] = 'complete'
    state['last_updated'] = "$timestamp"
    state['overall_status'] = 'completed'
    with open(r"$ORCHESTRATION_STATE_FILE","w") as f:
        json.dump(state,f,indent=2)
except Exception as e:
    sys.exit(1)
PY
}

get_phase_status() {
    local phase="$1"
    python3 - <<PY 2>/dev/null || echo "unknown"
import json, sys
try:
    with open(r"$ORCHESTRATION_STATE_FILE","r") as f:
        state=json.load(f)
    print(state['phases']["$phase"]["status"]) 
except:
    print('unknown')
PY
}

get_phase_attempts() {
    local phase="$1"
    python3 - <<PY 2>/dev/null || echo "0"
import json, sys
try:
    with open(r"$ORCHESTRATION_STATE_FILE","r") as f:
        state=json.load(f)
    print(state['phases']["$phase"].get('attempts',0))
except:
    print('0')
PY
}

get_phase_cycle() {
    local phase="$1"
    python3 - <<PY 2>/dev/null || echo "1"
import json, sys
try:
    with open(r"$ORCHESTRATION_STATE_FILE","r") as f:
        state=json.load(f)
    print(state['phases']["$phase"].get('cycle',1))
except:
    print('1')
PY
}

get_current_cycle() {
    python3 - <<PY 2>/dev/null || echo "1"
import json, sys
try:
    with open(r"$ORCHESTRATION_STATE_FILE","r") as f:
        state=json.load(f)
    print(state.get('current_cycle',1))
except:
    print('1')
PY
}

add_handoff_note() {
    local from_phase="$1"; local to_phase="$2"; local note="$3"
    local timestamp
    timestamp=$(date -Iseconds)
    local handoff_key="${from_phase}_to_${to_phase}"
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Warning: Could not add handoff note (python3 not available)" >&2
        return 0
    fi
    python3 - <<PY 2>/dev/null || true
import json, sys
try:
    with open(r"$ORCHESTRATION_STATE_FILE","r") as f:
        state=json.load(f)
    entry={'timestamp':"$timestamp", 'cycle': state.get('current_cycle',1), 'note':"$note"}
    state['handoffs'].setdefault("$handoff_key",[]).append(entry)
    state['last_updated'] = "$timestamp"
    with open(r"$ORCHESTRATION_STATE_FILE","w") as f:
        json.dump(state,f,indent=2)
except Exception as e:
    sys.exit(1)
PY
}

get_handoff_notes() {
    local from_phase="$1"; local to_phase="$2"; local handoff_key="${from_phase}_to_${to_phase}"
    python3 - <<PY 2>/dev/null || echo ""
import json, sys
try:
    with open(r"$ORCHESTRATION_STATE_FILE","r") as f:
        state=json.load(f)
    for h in state['handoffs'].get("$handoff_key",[])[-3:]:
        print(f"[Cycle {h.get('cycle','unknown')}] {h.get('note','')}")
except:
    pass
PY
}

increment_cycle() {
    local timestamp
    timestamp=$(date -Iseconds)
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Warning: Could not increment cycle (python3 not available)" >&2
        return 0
    fi
    python3 - <<PY 2>/dev/null || true
import json, sys
try:
    with open(r"$ORCHESTRATION_STATE_FILE","r") as f:
        state=json.load(f)
    current=state.get('current_cycle',1)
    new=current+1
    state['current_cycle']=new
    state['last_updated'] = "$timestamp"
    state['cycle_history'][str(new)]={ 'phases_completed': [], 'issues_found': [], 'lessons_learned': [] }
    for phase in state['phases']:
        state['phases'][phase]['cycle'] = new if phase=='planning' else 0
    with open(r"$ORCHESTRATION_STATE_FILE","w") as f:
        json.dump(state,f,indent=2)
except Exception as e:
    sys.exit(1)
PY
}

update_phase_cycle() {
    local phase="$1"
    local timestamp
    timestamp=$(date -Iseconds)
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Warning: Could not update phase cycle (python3 not available)" >&2
        return 0
    fi
    python3 - <<PY 2>/dev/null || true
import json, sys
try:
    with open(r"$ORCHESTRATION_STATE_FILE","r") as f:
        state=json.load(f)
    current=state.get('current_cycle',1)
    state['phases']["$phase"]["cycle"]=current
    state['last_updated'] = "$timestamp"
    with open(r"$ORCHESTRATION_STATE_FILE","w") as f:
        json.dump(state,f,indent=2)
except Exception as e:
    sys.exit(1)
PY
}

is_phase_completed_in_current_cycle() {
    local phase="$1"
    python3 - <<PY 2>/dev/null || echo "false"
import json, sys
try:
    with open(r"$ORCHESTRATION_STATE_FILE","r") as f:
        state=json.load(f)
    current=state.get('current_cycle',1)
    cycle=state['phases']["$phase"].get('cycle',0)
    status=state['phases']["$phase"].get('status','pending')
    print('true' if status=='completed' and cycle==current else 'false')
except:
    print('false')
PY
}
