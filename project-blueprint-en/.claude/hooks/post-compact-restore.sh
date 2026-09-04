#!/usr/bin/env bash
# ==============================================================================
# post-compact-restore.sh — PostCompact hook
#
# Role: after a compact completes, (1) preserve the generated summary and
#       (2) drop a marker so the core rules get re-injected on the next prompt.
#
# Official-spec constraint:
#   PostCompact has no decision control at all (not even additionalContext).
#   It is a side-effect-only event, for logging and external state updates.
#   So the "rules fade after compaction" problem is solved by dropping a marker
#   here and collecting it in the UserPromptSubmit hook, which CAN emit
#   additionalContext.
#
# Input:  JSON via stdin
#         {"hook_event_name":"PostCompact","trigger":"manual|auto","compact_summary":"..."}
# Output: none (stdout only reaches the debug log). Side effects only:
#         - testreport/transcripts/<session>-compact-<ts>.md  … summary snapshot
#         - testreport/.post-compact-pending                   … re-injection marker
#
# Policy: fail-open (exit 0 whatever fails; never stall the session)
# ==============================================================================

set -uo pipefail

PROFILE="${BLUEPRINT_HOOK_PROFILE:-standard}"
[[ "$PROFILE" == "minimal" ]] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
OUT_DIR="$PROJECT_DIR/testreport/transcripts"
MARKER="$PROJECT_DIR/testreport/.post-compact-pending"

# Sanitize the session ID (prevents path traversal)
SESSION_ID_RAW="${CLAUDE_SESSION_ID:-$(date +%Y%m%d)}"
SESSION_ID="$(printf '%s' "$SESSION_ID_RAW" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-64)"
[[ -z "$SESSION_ID" ]] && SESSION_ID="$(date +%Y%m%d)"

INPUT="$(cat 2>/dev/null || true)"
[[ -z "$INPUT" ]] && exit 0

TRIGGER="unknown"
SUMMARY=""
if command -v jq &>/dev/null; then
    TRIGGER="$(printf '%s' "$INPUT" | jq -r '.trigger // "unknown"' 2>/dev/null || echo unknown)"
    SUMMARY="$(printf '%s' "$INPUT" | jq -r '.compact_summary // empty' 2>/dev/null || true)"
fi

mkdir -p "$OUT_DIR" 2>/dev/null || exit 0

TS="$(date -u +%Y%m%dT%H%M%SZ)"
{
    echo "# Compact Summary — $SESSION_ID ($TRIGGER)"
    echo
    echo "- generated_at: $TS"
    echo "- trigger: $TRIGGER"
    echo
    if [[ -n "$SUMMARY" ]]; then
        echo "$SUMMARY"
    else
        echo "_(compact_summary unavailable — jq may not be installed)_"
    fi
} > "$OUT_DIR/$SESSION_ID-compact-$TS.md" 2>/dev/null || true

# Re-injection marker. user-prompt-submit.sh collects it for exactly one prompt,
# then deletes it.
mkdir -p "$(dirname "$MARKER")" 2>/dev/null || true
printf '%s\n' "$TRIGGER" > "$MARKER" 2>/dev/null || true

exit 0
