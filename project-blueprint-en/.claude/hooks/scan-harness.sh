#!/usr/bin/env bash
# ==============================================================================
# scan-harness.sh — PreToolUse(Skill) / UserPromptExpansion / FileChanged hook — self-SAST + high-risk skill suppression + constitution watch
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
# Input:  JSON via stdin — PreToolUse {"tool_input":{"skill":...}} / UserPromptExpansion {"command_name":...} /
#         FileChanged {"file_path":...} (the `filechanged` argument selects the same path)
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
MODE="${1:-}"

# ── 0. Event detection (PreToolUse: Skill / UserPromptExpansion / FileChanged) ──
# Typing `/skill` directly bypasses PreToolUse(Skill) (official spec). UserPromptExpansion
# gets the same check; FileChanged only re-verifies the constitution.md hash.
EVENT=""
if command -v jq &>/dev/null; then
    EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
else
    EVENT=$(printf '%s' "$INPUT" | sed -n 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi
[[ "$MODE" == "filechanged" ]] && EVENT="FileChanged"

PROJECT="${CLAUDE_PROJECT_DIR:-.}"

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

# Compare constitution.md against its recorded hash. Returns 0 = drift (tampered) / 1 = match or not checkable
constitution_drift() {
    local const="$PROJECT/constitution.md" hash_file="$PROJECT/.claude/.constitution.sha256" current expected
    [[ -f "$const" && -f "$hash_file" ]] || return 1
    current=$(sha256_of "$const")
    expected=$(cat "$hash_file")
    [[ -n "$current" && "$current" != "$expected" ]]
}

# ── 0a. FileChanged (watching constitution.md) — cannot block; stderr (for the user) + log only ──
# protect-files.sh stops Edit / Write, but a Bash `sed -i` or an external editor gets through.
# The file watcher catches those and records them under testreport/config-changes/ (same place as config-guard.sh).
if [[ "$EVENT" == "FileChanged" ]]; then
    if constitution_drift; then
        echo "🛡️  scan-harness: constitution.md changed on disk (hash mismatch) through something other than the Edit tool (sed -i, an external editor, ...). If intended, update .claude/.constitution.sha256; if not, inspect with git diff constitution.md" >&2
        LOG_DIR="$PROJECT/testreport/config-changes"
        if command -v jq &>/dev/null && mkdir -p "$LOG_DIR" 2>/dev/null; then
            SID="$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)"
            SID="$(printf '%s' "$SID" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-8)"
            jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg file "$PROJECT/constitution.md" \
                '{ts: $ts, source: "file_watch", file: $file, decision: "warn", violations: ["constitution.md hash mismatch"]}' \
                >> "$LOG_DIR/${SID:-unknown}.jsonl" 2>/dev/null || true
        fi
    fi
    exit 0
fi

# ── 1. Extract the skill name (PreToolUse: tool_input.skill / UserPromptExpansion: command_name) ──
SKILL=""
if [[ "$EVENT" == "UserPromptExpansion" ]]; then
    if command -v jq &>/dev/null; then
        EXP_TYPE=$(printf '%s' "$INPUT" | jq -r '.expansion_type // "slash_command"' 2>/dev/null)
        [[ "$EXP_TYPE" == "slash_command" ]] || exit 0   # MCP prompt expansions are out of scope
        SKILL=$(printf '%s' "$INPUT" | jq -r '.command_name // empty' 2>/dev/null)
    else
        SKILL=$(printf '%s' "$INPUT" | sed -n 's/.*"command_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    fi
    SKILL="${SKILL##*:}"   # plugin:name → name
elif command -v jq &>/dev/null; then
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

ISSUES=()

# 3a. Constitution hash monitoring (always, lightweight, deterministic)
if constitution_drift; then
    ISSUES+=("constitution.md has been modified (hash mismatch). If this change is intentional, update .claude/.constitution.sha256")
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
        "$PROJECT/CLAUDE.md"
        "$PROJECT/AGENTS.md"
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
        # non-blocking: tell Claude through additionalContext on stdout
        # (on UserPromptExpansion plain-text stdout is passed as context as is — official spec)
        if [[ "$EVENT" == "UserPromptExpansion" ]]; then
            printf '%s\n' "$SUMMARY"
        else
            emit_context PreToolUse "$SUMMARY"
        fi
        exit 0
        ;;
esac
