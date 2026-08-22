#!/usr/bin/env bash
# ==============================================================================
# user-prompt-submit.sh — UserPromptSubmit hook
#
# Role:
#   1. Inspect the user prompt before Claude processes it and detect secrets
#      that were pasted by mistake.
#   2. For exactly one prompt right after a compact, re-inject the core rules
#      through additionalContext (PostCompact itself has no decision control
#      and cannot inject context, so post-compact-restore.sh drops a marker
#      that this hook collects).
#
# Profile switch: $BLUEPRINT_HOOK_PROFILE
#   - minimal:  pass-through (skip inspection)
#   - standard: warn only on secret patterns (non-blocking, default)
#   - strict:   emit JSON {"decision":"block"} on stdout to reject the prompt
#               (official spec: exit 0 + JSON, not exit 2)
#
# Input:  JSON via stdin {"prompt": "...", "session_id": "..."}
# Output:
#   exit 0 + stdout JSON hookSpecificOutput.additionalContext = inject context
#   exit 0 + JSON {"decision":"block","reason":"..."} = reject the prompt
#
# Policy: fail-open — pass through when jq is missing or parsing fails.
# ==============================================================================

set -uo pipefail

# ── Shared emitter that actually reaches Claude ───────────────────────
# Official spec: on exit 0, stderr only reaches the debug log — neither Claude nor
# the user sees it. To tell Claude, print hookSpecificOutput.additionalContext on stdout.
emit_context() {
    local event="$1"; shift
    local text="$*"
    [[ -z "$text" ]] && return 0
    if command -v jq &>/dev/null; then
        jq -nc --arg e "$event" --arg t "$text" \
            '{hookSpecificOutput:{hookEventName:$e, additionalContext:$t}}'
    else
        local esc
        esc="$(printf '%s' "$text" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}')"
        printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$event" "$esc"
    fi
}

PROFILE="${BLUEPRINT_HOOK_PROFILE:-standard}"
[[ "$PROFILE" == "minimal" ]] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MARKER="$PROJECT_DIR/testreport/.post-compact-pending"

# ── (1) Re-inject core rules right after a compact ────────────────────
NOTES=""
if [[ -f "$MARKER" ]]; then
    rm -f "$MARKER" 2>/dev/null || true
    NOTES="[post-compact recovery] The context was just compacted. Before continuing, re-confirm:
  - Inviolable principles: constitution.md (7 principles) — especially the human/AI split and the 5 quality gates
  - Cross-cutting rules: CLAUDE.md and .claude/rules/*.md
  - Work in flight: the newest files under output/ and any unfinished tasks
  - The pre-compact summary is preserved under testreport/transcripts/ if you need it
  If work is unfinished, resume from the existing artifacts instead of redesigning them."
fi

# Without jq we give up on secret detection (fail-open), but still deliver the
# recovery note. A sed fallback would be too lossy to trust here.
if ! command -v jq &>/dev/null; then
    [[ -n "$NOTES" ]] && emit_context UserPromptSubmit "$NOTES"
    exit 0
fi

INPUT="$(cat 2>/dev/null || true)"
PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)"
if [[ -z "$PROMPT" ]]; then
    [[ -n "$NOTES" ]] && emit_context UserPromptSubmit "$NOTES"
    exit 0
fi

# ── (2) Secret patterns (high paste-by-mistake risk) ──────────────────
SECRET_PATTERNS=(
    'AKIA[0-9A-Z]{16}'                                     # AWS Access Key ID
    'sk-[a-zA-Z0-9]{32,}'                                  # OpenAI / Anthropic style
    'ghp_[a-zA-Z0-9]{36}'                                  # GitHub PAT (legacy)
    'github_pat_[A-Za-z0-9]{22}_[A-Za-z0-9]{59}'           # GitHub PAT (fine-grained)
    'gho_[a-zA-Z0-9]{36}'                                  # GitHub OAuth Token
    'xox[baprs]-[a-zA-Z0-9-]+'                             # Slack Token
    '-----BEGIN [A-Z ]+PRIVATE KEY-----'                   # PEM private key
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
            # Official spec: print block JSON on stdout and exit 0 (prompt rejected)
            printf '{"decision":"block","reason":"The prompt contains a pattern that looks like a secret (%s). Replace the value with [REDACTED] and resend."}\n' "$DETECTED"
            exit 0
            ;;
        standard|*)
            # Non-blocking warnings reach Claude through additionalContext on stdout.
            # On exit 0, stderr only reaches the debug log (official spec).
            WARN="user-prompt-submit hook: detected a secret-like pattern ($DETECTED). Ask the user to redact the secret in their prompt, and never echo the value back."
            [[ -n "$NOTES" ]] && WARN="$NOTES"$'\n\n'"$WARN"
            emit_context UserPromptSubmit "$WARN"
            exit 0
            ;;
    esac
fi

[[ -n "$NOTES" ]] && emit_context UserPromptSubmit "$NOTES"
exit 0
