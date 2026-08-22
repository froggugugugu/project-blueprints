#!/usr/bin/env bash
# ==============================================================================
# scan-harness.sh — PreToolUse hook (Skill matcher) — Self-SAST + high-risk skill block
#
# Role:
#   1. Detect secrets / drift in the harness itself (.claude/, .mcp.json*, settings.json)
#   2. Hash-monitor constitution.md (tamper detection)
#   3. Effectively block high-risk skills (deploy*) via tool_input.skill
#      Doubles up with the Skill(skill:deploy*) deny rules in settings.json.
#      The deny rules are absolute; this hook is the operational layer a profile can relax.
#
# Profile switching: $BLUEPRINT_HOOK_PROFILE
#   - minimal:  pass-through only
#   - standard: warn-only on detection (non-blocking, default)
#   - strict:   block on detection / on high-risk skill launch
#
# Input:  JSON via stdin {"tool_name":"Skill","tool_input":{"skill":"..."}}
# Output: exit 0 = allow / exit 2 = block (strict, or high-risk skill)
# Policy: fail-open (pass through if parsing fails)
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

INPUT="$(cat 2>/dev/null || true)"

# ── 1. Extract tool_input.skill ───────────────────────────────────────
SKILL=""
if command -v jq &>/dev/null; then
    SKILL=$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // .tool_input.name // empty' 2>/dev/null)
else
    # sed fallback when jq is absent: prevents deploy-block bypass
    SKILL=$(printf '%s' "$INPUT" | sed -n 's/.*"skill"\s*:\s*"\([^"]*\)".*/\1/p' | head -1)
    [[ -z "$SKILL" ]] && SKILL=$(printf '%s' "$INPUT" | sed -n 's/.*"name"\s*:\s*"\([^"]*\)".*/\1/p' | head -1)
fi

# ── 2. High-risk skill check (always, profile-independent) ────────────
case "$SKILL" in
    # Note: `prod-*` was removed because of false positives (prod-test, prod-validate, etc.).
    #       Only explicit deploy / production prefixes are blocked.
    deploy|deploy-*|*-deploy|production-*|*-production)
        echo "🛡️  scan-harness: high-risk skill '$SKILL' is effectively blocked" >&2
        echo "  Reason: this template denies deploy/production-class skills (doubled up with the Skill(skill:...) deny rules in settings.json)" >&2
        echo "  To allow: set BLUEPRINT_HOOK_PROFILE=minimal in settings.local.json" >&2
        exit 2
        ;;
esac

# ── 3. Heavy SAST: only for select skills. Hash check runs always. ────
NEED_FULL_SCAN=0
case "$SKILL" in
    security-scan|legal-check|review-fix|architecture|prd|"")
        NEED_FULL_SCAN=1
        ;;
esac

PROJECT="${CLAUDE_PROJECT_DIR:-.}"
ISSUES=()

# Cross-platform sha256: prefer sha256sum (GNU), fall back to shasum -a 256 (macOS)
sha256_of() {
    if command -v sha256sum &>/dev/null; then
        sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$1" | cut -d' ' -f1
    else
        echo ""  # neither available; fail-open below
    fi
}

# 3a. Constitution hash monitoring (always, lightweight, deterministic)
CONST="$PROJECT/constitution.md"
HASH_FILE="$PROJECT/.claude/.constitution.sha256"
if [[ -f "$CONST" && -f "$HASH_FILE" ]]; then
    CURRENT=$(sha256_of "$CONST")
    EXPECTED=$(cat "$HASH_FILE")
    if [[ -n "$CURRENT" && "$CURRENT" != "$EXPECTED" ]]; then
        ISSUES+=("constitution.md has been modified (hash mismatch). If this change is intentional, update .claude/.constitution.sha256")
    fi
fi

# 3b. Detect deny-rule weakening in settings.local.json (always, lightweight)
LOCAL="$PROJECT/.claude/settings.local.json"
if [[ -f "$LOCAL" ]] && command -v jq &>/dev/null; then
    # Warn when the deny key exists at all (empty [] also overrides shared deny rules)
    if jq -e 'getpath(["permissions","deny"]) != null' "$LOCAL" >/dev/null 2>&1; then
        ISSUES+=("settings.local.json defines permissions.deny (an empty [] clears all deny rules — manage deny rules in shared settings.json instead)")
    fi
fi

# 3c. Secret pattern scan (only when NEED_FULL_SCAN=1, this is the heavy one)
if [[ "$NEED_FULL_SCAN" -eq 1 && -d "$PROJECT/.claude" ]]; then
    SCAN_TARGETS=(
        "$PROJECT/.claude"
        "$PROJECT/.mcp.json"
        "$PROJECT/.mcp.json.template"
    )
    for target in "${SCAN_TARGETS[@]}"; do
        [[ -e "$target" ]] || continue
        if grep -rEq -- 'AKIA[0-9A-Z]{16}' "$target" 2>/dev/null; then
            ISSUES+=("AWS Access Key ID pattern present in ${target}")
        fi
        # GitHub PAT (legacy ghp_ + fine-grained github_pat_)
        if grep -rEq -- 'ghp_[a-zA-Z0-9]{36}' "$target" 2>/dev/null; then
            ISSUES+=("GitHub PAT (legacy ghp_) pattern present in ${target}")
        fi
        if grep -rEq -- 'github_pat_[A-Za-z0-9]{22}_[A-Za-z0-9]{59}' "$target" 2>/dev/null; then
            ISSUES+=("GitHub PAT (fine-grained github_pat_) pattern present in ${target}")
        fi
        if grep -rEq -- 'sk-[a-zA-Z0-9]{32,}' "$target" 2>/dev/null; then
            ISSUES+=("API key pattern (sk-...) present in ${target}")
        fi
    done
fi

# ── 4. Result output ──────────────────────────────────────────────────
if [[ ${#ISSUES[@]} -eq 0 ]]; then
    exit 0
fi

SUMMARY="scan-harness: self-SAST detected ${#ISSUES[@]} issue(s)"
for i in "${ISSUES[@]}"; do
    SUMMARY="$SUMMARY"$'\n'"  - $i"
done

case "$PROFILE" in
    strict)
        # exit 2 is the only path where stderr reaches Claude (official spec)
        printf '%s\n' "$SUMMARY" >&2
        echo "(BLUEPRINT_HOOK_PROFILE=strict, blocking skill invocation)" >&2
        exit 2
        ;;
    standard|*)
        # non-blocking: tell Claude via stdout additionalContext
        emit_context PreToolUse "$SUMMARY"
        exit 0
        ;;
esac
