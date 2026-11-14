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

# Without jq an apply_patch cannot be converted. A blocking hook stops an edit it cannot inspect instead of letting it through
# (Bash input needs no conversion, so it is passed on and each hook's own no-jq fallback applies)
if ! command -v jq &>/dev/null; then
    if [[ $FAIL_CLOSED -eq 1 ]] && printf '%s' "$INPUT" | grep -qE '"tool_name"[[:space:]]*:[[:space:]]*"apply_patch"'; then
        echo "codex-adapter: jq is missing, so the files this edit touches cannot be inspected. Stopped for safety. Install jq (brew install jq / apt-get install jq)" >&2
        exit 2
    fi
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
    # If this parser disagrees with Codex's own patch parser, an edit to a file missed here would run uninspected.
    # Strip surrounding whitespace and CR before matching, and mark a file directive (Add / Update / Delete File, Move to) whose path cannot be read.
    # A body line (a context line with a leading space, say) that happens to look like a directive only adds a path to check; it never hides one.
    # Codex trims more kinds of whitespace than this does (full-width space, NBSP and so on). Instead of reproducing that rule,
    # every line that contains a directive word but is not in the canonical form (`*** <directive>: <path>` from the start of the line)
    # counts as an unreadable directive. Lines starting with `+` or `-` are added / removed body text and are skipped
    PATHS="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null | awk '
        {
            line = $0
            gsub(/^[ \t\r\f\v]+|[ \t\r\f\v]+$/, "", line)
            first = substr(line, 1, 1)
            if (first == "+" || first == "-") next
            if (line !~ /\*\*\*[^A-Za-z]*(Add File|Update File|Delete File|Move to)/) next
            if (line ~ /^\*\*\* (Add File|Update File|Delete File|Move to):/) {
                sub(/^\*\*\* (Add File|Update File|Delete File|Move to):[ \t]*/, "", line)
                if (line != "") { print line; next }
            }
            print "@@BLUEPRINT_BAD_DIRECTIVE@@"
        }
    ')"
    if printf '%s\n' "$PATHS" | grep -qxF '@@BLUEPRINT_BAD_DIRECTIVE@@'; then
        if [[ $FAIL_CLOSED -eq 1 ]]; then
            echo "codex-adapter: the patch has a directive line that cannot be read. Stopped because it could slip past the protected-file check" >&2
            exit 2
        fi
        PATHS="$(printf '%s\n' "$PATHS" | grep -vxF '@@BLUEPRINT_BAD_DIRECTIVE@@' || true)"
    fi
    # A path with Unicode whitespace (NBSP, full-width space, ...) at either end, or a control character anywhere, counts as an
    # unreadable directive. Codex trims those from the path, so `.env` + NBSP edits `.env` under Codex while this check would see
    # a differently named file and let it through. Other non-ASCII characters (Japanese file names, say) are allowed
    if [[ $FAIL_CLOSED -eq 1 && -n "$PATHS" ]]; then
        # Unicode の White_Space のうち ASCII 以外のもの(UTF-8 のバイト列): U+0085 U+00A0 U+1680 U+2000〜U+200A U+2028 U+2029 U+202F U+205F U+3000
        UNICODE_WS=($'\xc2\x85' $'\xc2\xa0' $'\xe1\x9a\x80' $'\xe2\x80\x80' $'\xe2\x80\x81' $'\xe2\x80\x82' $'\xe2\x80\x83'
            $'\xe2\x80\x84' $'\xe2\x80\x85' $'\xe2\x80\x86' $'\xe2\x80\x87' $'\xe2\x80\x88' $'\xe2\x80\x89' $'\xe2\x80\x8a'
            $'\xe2\x80\xa8' $'\xe2\x80\xa9' $'\xe2\x80\xaf' $'\xe2\x81\x9f' $'\xe3\x80\x80')
        while IFS= read -r rel; do
            bad=0
            case "$rel" in *[[:cntrl:]]*) bad=1 ;; esac
            for ws in "${UNICODE_WS[@]}"; do
                case "$rel" in "$ws"*|*"$ws") bad=1 ;; esac
            done
            if [[ $bad -eq 1 ]]; then
                echo "codex-adapter: a path has invisible whitespace at its edge or a control character. Stopped because it could slip past the protected-file check" >&2
                exit 2
            fi
        done <<< "$PATHS"
    fi
    if [[ -z "$PATHS" && $FAIL_CLOSED -eq 1 ]]; then
        echo "codex-adapter: no file path could be extracted from the patch. Stopped because an edit that cannot be inspected must not go through" >&2
        exit 2
    fi
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
    # A patch with no extractable path: an observation hook gets the input unchanged (hooks do nothing without file_path)
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
