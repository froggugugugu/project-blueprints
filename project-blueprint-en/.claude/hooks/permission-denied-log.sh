#!/usr/bin/env bash
# ==============================================================================
# permission-denied-log.sh — PermissionDenied hook (observe only)
#
# Records tool calls denied by the auto mode classifier (auto mode is the
# default permission mode on Pro / Max / Team) as JSONL. The denial history
# feeds the next round of tuning:
#   - a legitimate action denied repeatedly → add an allow rule in settings.local.json
#   - your own infrastructure treated as "external" → describe it in
#     autoMode.environment in ~/.claude/settings.json via /auto-mode-setup
#
# No decision control (no retry is returned). Logging only.
#
# Input:  JSON via stdin
#         {"hook_event_name":"PermissionDenied","tool_name":"Bash",
#          "tool_input":{...},"reason":"Blocked by classifier","permission_mode":"auto"}
# Output: appends one line to testreport/denials/<session>.jsonl (gitignored)
# Policy: fail-open (exit 0 whatever fails)
# ==============================================================================

set -uo pipefail

PROFILE="${BLUEPRINT_HOOK_PROFILE:-standard}"
[[ "$PROFILE" == "minimal" ]] && exit 0
command -v jq &>/dev/null || exit 0

INPUT="$(cat 2>/dev/null || true)"
[[ -z "$INPUT" ]] && exit 0

LOG_DIR="${CLAUDE_PROJECT_DIR:-.}/testreport/denials"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

SID="$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)"
SID="${SID:0:8}"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# tool_input is truncated to 500 chars (avoid persisting secret values long-term)
printf '%s' "$INPUT" | jq -c --arg ts "$TS" '{
    ts: $ts,
    tool: (.tool_name // "unknown"),
    reason: (.reason // ""),
    permission_mode: (.permission_mode // ""),
    input: ((.tool_input // {}) | tostring | .[0:500])
}' >> "$LOG_DIR/$SID.jsonl" 2>/dev/null

exit 0
