#!/usr/bin/env bash
# ==============================================================================
# subagent-audit.sh — SubagentStart / SubagentStop hook
#
# Records subagent lifecycle events as JSONL for observability in parallel
# team workflows (TEAM_PJM --parallel etc.).
# Does NOT block subagent execution (observation only).
#
# Input:  JSON via stdin  {"hook_event":"SubagentStart|SubagentStop", ...}
# Output: appends one JSONL line to testreport/agents/<session>.jsonl
#
# Policy: fail-open (if parsing fails, the event is allowed to proceed)
# ==============================================================================

set -uo pipefail

# --- Paths ---
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOG_DIR="$PROJECT_DIR/testreport/agents"
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%Y%m%d)}"
LOG_FILE="$LOG_DIR/$SESSION_ID.jsonl"

# --- Read stdin JSON ---
INPUT="$(cat)"

# Fail-open: empty input is allowed
if [[ -z "$INPUT" ]]; then
    exit 0
fi

# --- Extract event fields ---
if command -v jq &>/dev/null; then
    EVENT="$(echo "$INPUT" | jq -r '.hook_event // .hookEventName // "unknown"' 2>/dev/null)"
    AGENT_NAME="$(echo "$INPUT" | jq -r '.subagent_type // .tool_input.subagent_type // "unknown"' 2>/dev/null)"
    AGENT_ID="$(echo "$INPUT" | jq -r '.subagent_id // .agent_id // "unknown"' 2>/dev/null)"
else
    # Fallback: rough extraction without jq
    EVENT="$(echo "$INPUT" | sed -n 's/.*"hook_event"\s*:\s*"\([^"]*\)".*/\1/p' | head -1)"
    AGENT_NAME="$(echo "$INPUT" | sed -n 's/.*"subagent_type"\s*:\s*"\([^"]*\)".*/\1/p' | head -1)"
    AGENT_ID="unknown"
fi

# Fail-open: couldn't parse event
if [[ -z "${EVENT:-}" ]]; then
    exit 0
fi

# --- Ensure log directory exists ---
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

# --- Write JSONL line ---
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
LINE="{\"timestamp\":\"$TIMESTAMP\",\"event\":\"$EVENT\",\"agent_name\":\"$AGENT_NAME\",\"agent_id\":\"$AGENT_ID\",\"session_id\":\"$SESSION_ID\"}"

echo "$LINE" >> "$LOG_FILE" 2>/dev/null || true

# Always exit 0 — this is observation only, never blocks
exit 0
