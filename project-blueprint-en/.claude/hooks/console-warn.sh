#!/usr/bin/env bash
# ==============================================================================
# console-warn.sh — PostToolUse hook for Edit/Write tools
#
# Detects debug statements left in edited files:
#   console.log, console.debug, debugger, print() (Python), dd() (PHP/Laravel)
#
# Input:  JSON via stdin  {"tool_name":"Edit","tool_input":{"file_path":"..."}}
# Output: exit 0 + stdout JSON hookSpecificOutput.additionalContext
#         (stderr on exit 0 is invisible to Claude — official spec)
#
# Policy: warn-only (never blocks, provides feedback)
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

# --- Extract the file path from stdin JSON ---
INPUT="$(cat)"

if command -v jq &>/dev/null; then
    FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null)"
else
    FILE_PATH="$(echo "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    if [[ -z "$FILE_PATH" ]]; then
        FILE_PATH="$(echo "$INPUT" | sed -n 's/.*"filePath"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    fi
fi

# Skip if no file path or file doesn't exist
if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then
    exit 0
fi

# Skip non-source files (config, docs, etc.)
case "$FILE_PATH" in
    *.md|*.json|*.yaml|*.yml|*.toml|*.xml|*.csv|*.txt|*.lock|*.log)
        exit 0
        ;;
esac

# --- Debug statement patterns ---
# Each entry: "pattern|description"
DEBUG_PATTERNS=(
    'console\.log([[:space:]]|\()|console.log (JavaScript/TypeScript)'
    'console\.debug([[:space:]]|\()|console.debug (JavaScript/TypeScript)'
    '(^|[^[:alnum:]_])debugger([^[:alnum:]_]|$)|debugger statement (JavaScript/TypeScript)'
    '(^|[^[:alnum:]_])print[[:space:]]*\(|print() (Python)'
    '(^|[^[:alnum:]_])pp([[:space:]]|\()|pp (Ruby)'
    '(^|[^[:alnum:]_])dd[[:space:]]*\(|dd() (PHP/Laravel)'
    '(^|[^[:alnum:]_])var_dump[[:space:]]*\(|var_dump() (PHP)'
    '(^|[^[:alnum:]_])puts([[:space:]]|\()|puts (Ruby)'
    'NSLog[[:space:]]*\(|NSLog() (Swift/ObjC)'
    'System\.out\.print|System.out.print (Java)'
    'fmt\.Print|fmt.Print (Go)'
    'println![[:space:]]*\(|println!() (Rust)'
)

WARNINGS=()

for entry in "${DEBUG_PATTERNS[@]}"; do
    PATTERN="${entry%|*}"
    DESC="${entry##*|}"

    # Search the file for the pattern (limit to first 3 matches)
    MATCHES="$(grep -nE -- "$PATTERN" "$FILE_PATH" 2>/dev/null | head -3 || true)"
    if [[ -n "$MATCHES" ]]; then
        WARNINGS+=("$DESC detected:")
        while IFS= read -r line; do
            WARNINGS+=("  $FILE_PATH:$line")
        done <<< "$MATCHES"
    fi
done

# --- Report warnings to Claude ---
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    MSG="Debug statements detected (consider removing before commit):"
    for w in "${WARNINGS[@]}"; do
        MSG="$MSG"$'\n'"  $w"
    done
    emit_context PostToolUse "$MSG"
fi

exit 0
