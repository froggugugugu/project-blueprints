#!/usr/bin/env bash
# ==============================================================================
# user-prompt-submit.sh — UserPromptSubmit hook (2026 spec)
#
# Role: Inspect user input before Claude processes it; detect secret patterns / leak risk.
# Profile switching: $BLUEPRINT_HOOK_PROFILE
#   - minimal:  pass-through (skip checks)
#   - standard: warn-only on detection (non-blocking, default)
#   - strict:   block via stdout JSON {"decision":"block"} (official spec, exit 0)
#
# Input:  JSON via stdin {"prompt": "...", "session_id": "..."}
# Output:
#   exit 0 + plain stdout = inject additional context to Claude
#   exit 0 + JSON {"decision":"block","reason":"..."} = ask Claude to revise the prompt
#                                                       (the 2026 spec uses exit 0 + JSON, not exit 2)
#
# Policy: fail-open — pass through when jq is missing or parsing fails (don't break).
# ==============================================================================

set -uo pipefail

PROFILE="${BLUEPRINT_HOOK_PROFILE:-standard}"
[[ "$PROFILE" == "minimal" ]] && exit 0

# Without jq we drop secret detection and pass through (fail-open).
# A fragile sed fallback would risk false positives/negatives, so we don't use it.
command -v jq &>/dev/null || exit 0

INPUT="$(cat 2>/dev/null || true)"
PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)"
[[ -z "$PROMPT" ]] && exit 0

# Secret patterns (high mis-paste risk)
SECRET_PATTERNS=(
    'AKIA[0-9A-Z]{16}'                    # AWS Access Key ID
    'sk-[a-zA-Z0-9]{32,}'                  # OpenAI / Anthropic style
    'ghp_[a-zA-Z0-9]{36}'                                  # GitHub PAT (legacy)
    'github_pat_[A-Za-z0-9]{22}_[A-Za-z0-9]{59}'           # GitHub PAT (fine-grained)
    'gho_[a-zA-Z0-9]{36}'                                  # GitHub OAuth Token
    'xox[baprs]-[a-zA-Z0-9-]+'             # Slack Token
    '-----BEGIN [A-Z ]+PRIVATE KEY-----'   # PEM private key
)

DETECTED=""
for pat in "${SECRET_PATTERNS[@]}"; do
    if printf '%s' "$PROMPT" | grep -qE -- "$pat"; then
        DETECTED="$pat"
        break
    fi
done

if [[ -n "$DETECTED" ]]; then
    case "$PROFILE" in
        strict)
            # Official spec: stdout JSON {decision:block} + exit 0 (sends back the prompt)
            printf '{"decision":"block","reason":"The prompt may contain a sensitive value matching pattern (%s). Please redact the value to [REDACTED] and resubmit."}\n' "$DETECTED"
            exit 0
            ;;
        standard|*)
            # standard warnings go to **stderr**. stdout would be injected into Claude's
            # prompt (2026 spec); stderr is the correct channel for human-facing feedback.
            printf '⚠️  user-prompt-submit hook: detected secret pattern (%s). Recommend redacting the value before submitting.\n' "$DETECTED" >&2
            exit 0
            ;;
    esac
fi

exit 0
