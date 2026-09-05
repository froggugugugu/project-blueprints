#!/usr/bin/env bash
# ==============================================================================
# verify-gate.sh — Verification gate (record on PostToolUse / judge on Stop)
#
# Implements the official best practice "give Claude a way to verify its work
# and gate the stop deterministically with a Stop hook". Mechanically closes the
# trust-then-verify gap (pitfalls #19) where work ends on "it should work".
#
# Usage (settings.json):
#   PostToolUse (Bash|Edit|Write|NotebookEdit) → verify-gate.sh track
#   Stop                                       → verify-gate.sh gate
#
# track: record timestamps of source edits / verification commands in testreport/.verify/
# gate : if no verification command ran after the last source edit
#          standard: warn the human via systemMessage (non-blocking)
#          strict  : {"decision":"block"} once, sending Claude back to verify
#          minimal : do nothing
#
# Infinite-loop protection (per official spec):
#   - stop_hook_active == true (a stop after our own block) always passes
#   - non-empty background_tasks (paused, not finished) passes
#   - Claude Code itself overrides the hook after 8 consecutive blocks
#
# Input:  JSON via stdin (track: tool_name/tool_input, gate: stop_hook_active etc.)
# Output: JSON on stdout for gate only. Exit is always 0
# Policy: fail-open (missing jq, parse failure, write failure all pass through)
# ==============================================================================

set -uo pipefail

MODE="${1:-gate}"
PROFILE="${BLUEPRINT_HOOK_PROFILE:-standard}"
[[ "$PROFILE" == "minimal" ]] && exit 0
command -v jq &>/dev/null || exit 0

INPUT="$(cat 2>/dev/null || true)"
[[ -z "$INPUT" ]] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SID="$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)"
SID="${SID:0:16}"
STATE_DIR="$PROJECT_DIR/testreport/.verify"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
EDIT_MARK="$STATE_DIR/$SID.edit"
VERIFY_MARK="$STATE_DIR/$SID.verify"

# Patterns treated as verification commands (grep -E, case-insensitive)
VERIFY_PATTERNS=(
    '(npm|pnpm|yarn|bun) (run )?(test|lint|typecheck|type-check|check|build|e2e|verify|validate)'
    'npx (vitest|jest|playwright|tsc|eslint|biome|prettier|depcruise|mocha)'
    '(^|[;&| ])(vitest|jest|pytest|ruff|mypy|pyright|tsc|eslint|biome|rspec|phpunit|mocha)( |$)'
    'python3? -m (pytest|unittest|mypy|ruff)'
    'cargo (test|check|clippy)'
    'go (test|vet|build)'
    'make (test|lint|check|verify|build)'
    '(dotnet|swift|flutter|deno|mix|xcodebuild) test'
    '(gradle|gradlew|mvn) (test|check|verify)'
    'playwright test'
    'validate-harness'
)

# Paths that don't count as source (docs, deliverables, configuration)
NON_SOURCE_RE='(^|/)(output|docs|input|testreport|\.claude|\.github|node_modules|dist|build|coverage)(/|$)|\.(md|txt|json|ya?ml|toml|lock|csv|svg|png|jpg)$'

case "$MODE" in
    track)
        TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
        case "$TOOL" in
            Bash)
                CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
                [[ -z "$CMD" ]] && exit 0
                for pat in "${VERIFY_PATTERNS[@]}"; do
                    if printf '%s' "$CMD" | grep -qiE -- "$pat"; then
                        date +%s > "$VERIFY_MARK" 2>/dev/null
                        break
                    fi
                done
                ;;
            Edit|Write|NotebookEdit)
                FP="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)"
                [[ -z "$FP" ]] && exit 0
                REL="${FP#"$PROJECT_DIR"/}"
                if ! printf '%s' "$REL" | grep -qE -- "$NON_SOURCE_RE"; then
                    date +%s > "$EDIT_MARK" 2>/dev/null
                fi
                ;;
        esac
        exit 0
        ;;

    gate)
        [[ -f "$EDIT_MARK" ]] || exit 0

        ACTIVE="$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)"
        [[ "$ACTIVE" == "true" ]] && exit 0

        BG="$(printf '%s' "$INPUT" | jq -r '(.background_tasks // []) | length' 2>/dev/null)"
        [[ -n "$BG" && "$BG" != "0" ]] && exit 0

        EDIT_TS="$(cat "$EDIT_MARK" 2>/dev/null || echo 0)"
        VERIFY_TS=0
        [[ -f "$VERIFY_MARK" ]] && VERIFY_TS="$(cat "$VERIFY_MARK" 2>/dev/null || echo 0)"
        [[ "$EDIT_TS" =~ ^[0-9]+$ ]] || exit 0
        [[ "$VERIFY_TS" =~ ^[0-9]+$ ]] || VERIFY_TS=0
        (( VERIFY_TS >= EDIT_TS )) && exit 0

        if [[ "$PROFILE" == "strict" ]]; then
            REASON="verify-gate (strict): no verification command (tests / lint / type check / build) was recorded after the last source edit. Run the project's verification command (project-config.md §3 or docs/project.md) and present the result (pass/fail counts, error counts) as evidence before finishing. If no verification tooling exists yet, state 'not run (N/A) + reason + next action' explicitly and finish."
            jq -nc --arg r "$REASON" '{decision:"block", reason:$r}'
        else
            MSG="verify-gate: no verification command was recorded after the last source edit. Check that the completion report includes verification results (evidence). The strict profile sends the turn back instead."
            jq -nc --arg m "$MSG" '{systemMessage:$m}'
        fi
        exit 0
        ;;

    *)
        exit 0
        ;;
esac
