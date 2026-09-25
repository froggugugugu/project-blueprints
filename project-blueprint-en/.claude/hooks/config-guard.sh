#!/usr/bin/env bash
# ==============================================================================
# config-guard.sh — ConfigChange hook (audit settings changes + refuse to weaken the guardrails)
#
# Role:
#   1. Record every settings-file change during a session (user / project / local
#      settings, skills) to testreport/config-changes/<session>.jsonl (observability)
#   2. When a project / local settings change would weaken the 3-layer defence
#      (constitution ⑤), exit 2 so the change is NOT applied to the running session:
#        - disableAllHooks: true (turns every hook off at once)
#        - permissions.deny defined in settings.local.json (overrides the shared deny
#          list; an empty array counts too)
#        - a Layer 1 blocking hook (safety-check.sh / protect-files.sh) disappears
#          from .claude/settings.json
#
# Official spec:
#   - ConfigChange can stop a change from applying with exit 2 or {"decision":"block"}
#     (policy_settings changes can't be blocked). systemMessage / continue are
#     discarded, and a blocked change shows no message to you or to Claude — so the
#     reason is written to the log instead
#   - Input: {"hook_event_name":"ConfigChange","source":"project_settings|local_settings|
#             user_settings|policy_settings|skills","file_path":"..."}
#
# Profile switch: $BLUEPRINT_HOOK_PROFILE
#   - minimal:  do nothing (exit 0)
#   - standard / strict: log, and block the weakenings above (constitution ⑤ is not
#     relaxed by profile)
#
# Policy: fail-open (missing jq, unparsable input or a missing file → exit 0)
# ==============================================================================

set -uo pipefail

PROFILE="${BLUEPRINT_HOOK_PROFILE:-standard}"
[[ "$PROFILE" == "minimal" ]] && exit 0
command -v jq &>/dev/null || exit 0

INPUT="$(cat 2>/dev/null || true)"
[[ -z "$INPUT" ]] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SOURCE="$(printf '%s' "$INPUT" | jq -r '.source // "unknown"' 2>/dev/null || echo unknown)"
FILE="$(printf '%s' "$INPUT" | jq -r '.file_path // empty' 2>/dev/null || true)"
SID="$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)"
SID="$(printf '%s' "$SID" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-8)"
[[ -z "$SID" ]] && SID="unknown"

# ── Weakening checks (project / local settings only; an unreadable file passes) ──
VIOLATIONS=()
if [[ ( "$SOURCE" == "project_settings" || "$SOURCE" == "local_settings" ) && -n "$FILE" && -f "$FILE" ]]; then
    if jq -e . "$FILE" >/dev/null 2>&1; then
        if jq -e '.disableAllHooks == true' "$FILE" >/dev/null 2>&1; then
            VIOLATIONS+=("disableAllHooks: true (turns every hook off — constitution ⑤)")
        fi
        if [[ "$SOURCE" == "local_settings" ]] && jq -e 'getpath(["permissions","deny"]) != null' "$FILE" >/dev/null 2>&1; then
            VIOLATIONS+=("permissions.deny in settings.local.json (overrides the shared deny list; an empty array disables it too)")
        fi
        if [[ "$SOURCE" == "project_settings" ]]; then
            for guard in safety-check.sh protect-files.sh; do
                if ! jq -e --arg g "$guard" '[.hooks.PreToolUse[]?.hooks[]?.command // "" | select(contains($g))] | length > 0' "$FILE" >/dev/null 2>&1; then
                    VIOLATIONS+=("$guard is missing from PreToolUse (a Layer 1 blocking hook)")
                fi
            done
        fi
    fi
fi

# ── Log (under testreport/, which is gitignored) ──────────────────────────────
LOG_DIR="$PROJECT_DIR/testreport/config-changes"
if mkdir -p "$LOG_DIR" 2>/dev/null; then
    TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    DECISION="allow"
    [[ ${#VIOLATIONS[@]} -gt 0 ]] && DECISION="block"
    printf '%s\n' "${VIOLATIONS[@]:-}" | jq -R . | jq -s -c --arg ts "$TS" --arg src "$SOURCE" --arg file "$FILE" --arg d "$DECISION" \
        '{ts: $ts, source: $src, file: $file, decision: $d, violations: (map(select(length > 0)))}' \
        >> "$LOG_DIR/$SID.jsonl" 2>/dev/null || true
fi

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
    {
        echo "config-guard: blocked a settings change ($SOURCE: $FILE)"
        for v in "${VIOLATIONS[@]}"; do echo "  - $v"; done
        echo "  Details: testreport/config-changes/$SID.jsonl. Change the guardrails through a PR to settings.json that passes validate-harness.sh"
    } >&2
    exit 2
fi

exit 0
