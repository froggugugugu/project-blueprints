#!/usr/bin/env bash
# ==============================================================================
# session-end.sh — SessionEnd hook (2026 spec)
#
# Role: Generate aggregated reports on session end and append to
#       output/reports/sessions/. Core observability primitive. Profile-aware.
#
# Profile switching: $BLUEPRINT_HOOK_PROFILE
#   - minimal:  no-op (pass through)
#   - standard: append a one-line summary (default)
#   - strict:   append detailed report (changed files, commit count, test results)
#
# Input:  JSON via stdin {"session_id":"...", "transcript_path":"...", "reason":"..."}
# Output: exit 0 (always allow)
# ==============================================================================

set -uo pipefail

PROFILE="${BLUEPRINT_HOOK_PROFILE:-standard}"
[[ "$PROFILE" == "minimal" ]] && exit 0

INPUT="$(cat)"
REPORT_DIR="${CLAUDE_PROJECT_DIR:-.}/output/reports/sessions"
mkdir -p "$REPORT_DIR" 2>/dev/null || exit 0

TODAY=$(date +%Y-%m-%d)
LOG="$REPORT_DIR/$TODAY.md"

if command -v jq &>/dev/null; then
    SID="$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)"
    REASON="$(printf '%s' "$INPUT" | jq -r '.reason // "stop"' 2>/dev/null)"
else
    SID="unknown"
    REASON="stop"
fi

NOW=$(date '+%H:%M:%S')

if [[ ! -f "$LOG" ]]; then
    {
        echo "# Session log — $TODAY"
        echo ""
        echo "| End time | session_id | Reason | Changed files | Commits |"
        echo "| -------- | ---------- | ------ | ------------- | ------- |"
    } > "$LOG"
fi

CHANGED=0
COMMITS=0
if [[ -d "${CLAUDE_PROJECT_DIR:-.}/.git" ]]; then
    CHANGED=$(git -C "${CLAUDE_PROJECT_DIR:-.}" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$PROFILE" == "strict" ]]; then
        COMMITS=$(git -C "${CLAUDE_PROJECT_DIR:-.}" log --since="1 hour ago" --oneline 2>/dev/null | wc -l | tr -d ' ')
    fi
fi

printf '| %s | `%s` | %s | %s | %s |\n' "$NOW" "${SID:0:8}" "$REASON" "$CHANGED" "$COMMITS" >> "$LOG"

exit 0
