#!/usr/bin/env bash
# ==============================================================================
# subagent-audit.sh — SubagentStart / SubagentStop hook
#
# Records subagent start and completion events as JSONL for observability in
# parallel team workflows (TEAM_PJM --parallel etc.).
# Does NOT block subagent execution (observation only).
#
# On SubagentStart it also returns additionalContext, injecting the harness's
# minimum guardrails into the subagent's opening context.
# (Official spec: SubagentStart is "Context only" — it can't block, but it can
#  inject context. SubagentStop uses the Stop decision format; here we only log.)
#
# Input:  JSON via stdin
#         start: {"hook_event_name":"SubagentStart","agent_id":"...","agent_type":"..."}
#         stop : {"hook_event_name":"SubagentStop","agent_id":"...","agent_type":"...",
#                 "last_assistant_message":"..."}
# Output: appends one JSONL line to testreport/agents/<session>.jsonl
#         On SubagentStart only, prints additionalContext JSON on stdout
#
# Policy: fail-open (if parsing fails, the event is allowed to proceed)
# ==============================================================================

set -uo pipefail

PROFILE="${BLUEPRINT_HOOK_PROFILE:-standard}"

# --- Paths ---
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOG_DIR="$PROJECT_DIR/testreport/agents"
# Sanitize SESSION_ID to prevent path traversal (reject `/`, `..`, etc.)
SESSION_ID_RAW="${CLAUDE_SESSION_ID:-$(date +%Y%m%d)}"
SESSION_ID="$(printf '%s' "$SESSION_ID_RAW" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-64)"
[[ -z "$SESSION_ID" ]] && SESSION_ID="$(date +%Y%m%d)"
LOG_FILE="$LOG_DIR/$SESSION_ID.jsonl"

# --- Read stdin JSON ---
INPUT="$(cat)"

# Fail-open: empty input is allowed
if [[ -z "$INPUT" ]]; then
    exit 0
fi

# --- Extract event fields ---
# `hook_event_name` is the official field name. `hook_event` / `hookEventName`
# are kept for compatibility with legacy payloads.
if command -v jq &>/dev/null; then
    EVENT="$(echo "$INPUT" | jq -r '.hook_event_name // .hook_event // .hookEventName // "unknown"' 2>/dev/null)"
    AGENT_NAME="$(echo "$INPUT" | jq -r '.agent_type // .subagent_type // .tool_input.subagent_type // "unknown"' 2>/dev/null)"
    AGENT_ID="$(echo "$INPUT" | jq -r '.agent_id // .subagent_id // "unknown"' 2>/dev/null)"
else
    # Fallback: rough extraction without jq
    EVENT="$(echo "$INPUT" | sed -n 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    [[ -z "$EVENT" ]] && EVENT="$(echo "$INPUT" | sed -n 's/.*"hook_event"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    AGENT_NAME="$(echo "$INPUT" | sed -n 's/.*"agent_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    [[ -z "$AGENT_NAME" ]] && AGENT_NAME="unknown"
    AGENT_ID="unknown"
fi

# Fail-open: couldn't parse event
if [[ -z "${EVENT:-}" ]]; then
    exit 0
fi

# --- Ensure log directory exists ---
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

# --- Write JSONL line (properly escaped) ---
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if command -v jq &>/dev/null; then
    # jq handles escaping for all values (quotes, backslashes, control chars)
    jq -nc \
        --arg timestamp "$TIMESTAMP" \
        --arg event "$EVENT" \
        --arg agent_name "$AGENT_NAME" \
        --arg agent_id "$AGENT_ID" \
        --arg session "$SESSION_ID" \
        '{timestamp: $timestamp, event: $event, agent_name: $agent_name, agent_id: $agent_id, session_id: $session}' \
        >> "$LOG_FILE" 2>/dev/null || true
else
    # Fallback: best-effort manual escaping (backslashes, double quotes, control chars stripped)
    esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\000-\037'; }
    printf '{"timestamp":"%s","event":"%s","agent_name":"%s","agent_id":"%s","session_id":"%s"}\n' \
        "$TIMESTAMP" "$(esc "$EVENT")" "$(esc "$AGENT_NAME")" "$(esc "$AGENT_ID")" "$(esc "$SESSION_ID")" \
        >> "$LOG_FILE" 2>/dev/null || true
fi

# --- SubagentStart: inject guardrails into the subagent ---
# The minimal profile skips injection and only keeps the log line.
if [[ "$EVENT" == "SubagentStart" && "$PROFILE" != "minimal" ]]; then
    CTX="[harness guardrails] Conventions for this repository:
  - Create new artifacts only under output/. Update docs/ with minimal diffs only
  - Do not modify project-config.md outside §2 / §3 / §11 (human decision area)
  - input/requirements/ and constitution.md are read-only
  - Never read or emit secrets (.env / private keys / tokens)
  - Pair every conclusion with evidence (file path:line number)"
    if command -v jq &>/dev/null; then
        jq -nc --arg t "$CTX" \
            '{hookSpecificOutput:{hookEventName:"SubagentStart", additionalContext:$t}}'
    else
        esc2="$(printf '%s' "$CTX" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}')"
        printf '{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"%s"}}\n' "$esc2"
    fi
fi

# Always exit 0 — this is observation only, never blocks
exit 0
