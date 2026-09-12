#!/usr/bin/env bash
# ==============================================================================
# scope-guard.sh — PreToolUse hook that enforces the write scope of a subagent
#
# Registered in a subagent's frontmatter (not settings.json), so it is active only
# while that agent runs:
#   hooks:
#     PreToolUse:
#       - matcher: "Edit|Write|NotebookEdit"
#         hooks:
#           - type: command
#             command: '"$CLAUDE_PROJECT_DIR"/.claude/hooks/scope-guard.sh docs'
#
# Why: doc-synchronizer / doc-writer skip permission prompts with
# permissionMode: acceptEdits. If their scope lives only in prose, an out-of-scope
# write also goes through unprompted. Following the official guidance "enforce
# must-hold constraints with hooks, not instructions", this stops it deterministically.
#
# Scopes (first argument):
#   docs    docs/** and project-config.md       (doc-synchronizer)
#   output  output/**                           (doc-writer)
#   tests   test files and test directories     (test-writer)
#
# Input:  JSON via stdin {"tool_name":"Edit","tool_input":{"file_path":"..."}}
# Output: exit 0 = allow / exit 2 = block (stderr goes back to the agent as the reason)
# Policy: input parse failures fail open. An unknown scope is a config error and fails closed
# ==============================================================================

set -uo pipefail

SCOPE="${1:-}"

block() {
    echo "BLOCKED (scope-guard:${SCOPE}): $1" >&2
    echo "This agent may only write to: ${SCOPE_DESC:-undefined}. Report to the parent session if an out-of-scope change is needed." >&2
    exit 2
}

case "$SCOPE" in
    docs)   SCOPE_DESC="docs/** and project-config.md" ;;
    output) SCOPE_DESC="output/**" ;;
    tests)  SCOPE_DESC="test files (*.test.* / *.spec.* / tests/ / e2e/ / __tests__/ / fixtures/)" ;;
    *)      SCOPE_DESC=""; block "unknown scope '${SCOPE}' (expected docs / output / tests)" ;;
esac

command -v jq &>/dev/null || exit 0

INPUT="$(cat 2>/dev/null || true)"
FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)"
[[ -z "$FILE_PATH" ]] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
case "$FILE_PATH" in
    "$PROJECT_DIR"/*) REL="${FILE_PATH#"$PROJECT_DIR"/}" ;;
    /*)               block "cannot write outside the project: $FILE_PATH" ;;
    *)                REL="${FILE_PATH#./}" ;;
esac

# Refuse path traversal (../) that escapes the scope
if [[ "/$REL/" == *"/../"* ]]; then
    block "path contains ../: $FILE_PATH"
fi

BASE="${REL##*/}"
allowed=0
case "$SCOPE" in
    docs)
        [[ "$REL" == docs/* || "$REL" == "project-config.md" ]] && allowed=1
        ;;
    output)
        [[ "$REL" == output/* ]] && allowed=1
        ;;
    tests)
        [[ "$REL" == tests/* || "$REL" == test/* || "$REL" == e2e/* || "$REL" == __tests__/* \
            || "$REL" == */__tests__/* || "$REL" == */__mocks__/* || "$REL" == */fixtures/* \
            || "$REL" == testreport/* ]] && allowed=1
        [[ "$BASE" == *.test.* || "$BASE" == *.spec.* || "$BASE" == test_*.py \
            || "$BASE" == *_test.py || "$BASE" == *_test.go ]] && allowed=1
        ;;
esac

(( allowed == 1 )) && exit 0
block "out-of-scope file: $REL"
