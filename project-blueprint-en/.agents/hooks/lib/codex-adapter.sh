#!/usr/bin/env bash
# ==============================================================================
# codex-adapter.sh — turn Codex hook input into the shared shape and call .agents/hooks/<hook>.sh
#
# The hook scripts are shared by Claude Code and Codex (.agents/hooks/*.sh). Codex hooks use the same
# stdin JSON, exit 2 and permissionDecision shapes as Claude Code, so only the differences are handled here:
#
#   1. Project root: Codex has no CLAUDE_PROJECT_DIR. It is derived from this file's location
#      (<root>/.agents/hooks/lib/) and passed as BLUEPRINT_PROJECT_DIR
#   2. Session ID: the input's session_id is passed as BLUEPRINT_SESSION_ID
#   3. File edits: a Codex edit arrives as tool_name "apply_patch" with the patch text in tool_input.command.
#      For each file the patch touches, the hook is called once with
#      {tool_name:"Edit", tool_input.file_path:<absolute path>}. Any exit 2 blocks the patch, and
#      additionalContext values are joined
#   4. Stop / SubagentStop: Codex accepts only JSON on stdout when the hook exits 0. Non-JSON output goes to stderr
#
# Usage (command in .codex/hooks.json):
#   "$(git rev-parse --show-toplevel)/.agents/hooks/lib/codex-adapter.sh" [--fail-closed] <hook.sh> [args...]
#
# --fail-closed: exit 2 when the hook script is missing (for the blocking hooks).
#   Codex has no setting equivalent to Claude Code's `onFailure: "block"`, so this replaces it.
#   Without the flag the action goes ahead (a broken observation hook must not stop the work).
# ==============================================================================

set -uo pipefail

FAIL_CLOSED=0
if [[ "${1:-}" == "--fail-closed" ]]; then
    FAIL_CLOSED=1
    shift
fi
HOOK="${1:-}"
[[ $# -gt 0 ]] && shift

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_DIR="$(dirname "$LIB_DIR")"
SCRIPT="$HOOK_DIR/$HOOK"

give_up() {
    echo "codex-adapter: $1" >&2
    if [[ $FAIL_CLOSED -eq 1 ]]; then
        echo "codex-adapter: a blocking hook could not run, so this action was stopped. Restore the hooks with setup.sh --upgrade." >&2
        exit 2
    fi
    exit 0
}

# Accept a bare file name only (a path separator must not run anything outside .agents/hooks/)
if [[ -z "$HOOK" || "$HOOK" == */* ]]; then
    give_up "invalid hook name: '${HOOK}'"
fi
if [[ ! -f "$SCRIPT" ]]; then
    give_up "hook not found: .agents/hooks/${HOOK}"
fi

INPUT="$(cat 2>/dev/null || true)"

export BLUEPRINT_AGENT="codex"
BLUEPRINT_PROJECT_DIR="$(cd "$HOOK_DIR/../.." && pwd)"
export BLUEPRINT_PROJECT_DIR

# bash 3.2 (the macOS default) fails on an empty "${a[@]}" under set -u, so branch on the argument count
run_hook() {
    if [[ $# -gt 1 ]]; then
        local payload="$1"
        shift
        printf '%s' "$payload" | bash "$SCRIPT" "$@"
    else
        printf '%s' "$1" | bash "$SCRIPT"
    fi
}

# Without jq, pass the input through unchanged (each hook has its own no-jq fallback)
if ! command -v jq &>/dev/null; then
    run_hook "$INPUT" "$@"
    exit $?
fi

SID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"
if [[ -n "$SID" ]]; then
    export BLUEPRINT_SESSION_ID="$SID"
fi
EVENT="$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"

# ── apply_patch: call the hook once per touched file ───────────────────────
if [[ "$TOOL" == "apply_patch" ]]; then
    CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)"
    [[ -n "$CWD" ]] || CWD="$BLUEPRINT_PROJECT_DIR"
    PATHS="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null | awk '
        /^\*\*\* (Add File|Update File|Delete File): / { sub(/^\*\*\* [A-Za-z]+ File: /, ""); print; next }
        /^\*\*\* Move to: /                           { sub(/^\*\*\* Move to: /, ""); print }
    ')"
    if [[ -n "$PATHS" ]]; then
        CONTEXTS=""
        while IFS= read -r rel; do
            [[ -z "$rel" ]] && continue
            case "$rel" in
                /*) abs="$rel" ;;
                *)  abs="$CWD/$rel" ;;
            esac
            one="$(printf '%s' "$INPUT" | jq -c --arg p "$abs" '.tool_name = "Edit" | .tool_input = ((.tool_input // {}) + {file_path: $p})' 2>/dev/null)"
            [[ -n "$one" ]] || continue
            out="$(run_hook "$one" "$@")"
            rc=$?
            if [[ $rc -eq 2 ]]; then
                exit 2
            fi
            ctx="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null || true)"
            if [[ -n "$ctx" ]]; then
                CONTEXTS="${CONTEXTS:+$CONTEXTS$'\n'}$ctx"
            fi
        done <<< "$PATHS"
        if [[ -n "$CONTEXTS" ]]; then
            jq -nc --arg e "${EVENT:-PostToolUse}" --arg t "$CONTEXTS" \
                '{hookSpecificOutput: {hookEventName: $e, additionalContext: $t}}'
        fi
        exit 0
    fi
    # A patch whose paths could not be extracted is passed through unchanged (hooks allow input without file_path)
fi

# ── Everything else: pass through ──────────────────────────────────────────
OUT="$(run_hook "$INPUT" "$@")"
RC=$?

if [[ ( "$EVENT" == "Stop" || "$EVENT" == "SubagentStop" ) && -n "$OUT" ]]; then
    if ! printf '%s' "$OUT" | jq -e . >/dev/null 2>&1; then
        printf '%s\n' "$OUT" >&2
        OUT=""
    fi
fi
if [[ -n "$OUT" ]]; then
    printf '%s\n' "$OUT"
fi
exit $RC
