#!/usr/bin/env bash
# ==============================================================================
# post-compact-restore.sh — PostCompact hook
#
# Role: after a compact completes, preserve the generated summary under testreport/
#       (audit and recovery).
#
# Official-spec constraint:
#   PostCompact has no decision control at all (not even additionalContext).
#   It is a side-effect-only event, for logging and external state updates.
#   The "rules fade after compaction" problem is solved by the SessionStart hook
#   (source == "compact"): session-start.sh re-injects the core rules right away
#   (the official pattern).
#
# Input:  JSON via stdin
#         {"hook_event_name":"PostCompact","trigger":"manual|auto","compact_summary":"..."}
# Output: none (stdout only reaches the debug log). Side effects only:
#         - testreport/transcripts/<session>-compact-<ts>.md  … summary snapshot
#
# Policy: fail-open (exit 0 whatever fails; never stall the session)
# ==============================================================================

set -uo pipefail

PROFILE="${BLUEPRINT_HOOK_PROFILE:-standard}"
[[ "$PROFILE" == "minimal" ]] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
OUT_DIR="$PROJECT_DIR/testreport/transcripts"

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

exit 0
