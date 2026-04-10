#!/usr/bin/env bash
# ==============================================================================
# commit-quality.sh — PostToolUse hook for Bash (git commit)
#
# Validates commit quality after git commit commands:
#   1. Conventional Commits format check
#   2. Secret detection in staged files
#
# Input:  JSON via stdin  {"tool_name":"Bash","tool_input":{"command":"..."},"tool_output":"..."}
# Output: exit 0 = allow (warnings via stderr)
#
# Policy: warn-only (never blocks, provides feedback)
# ==============================================================================

set -uo pipefail

# --- Extract the command from stdin JSON ---
INPUT="$(cat)"

if command -v jq &>/dev/null; then
    CMD="$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
else
    CMD="$(echo "$INPUT" | sed -n 's/.*"command"\s*:\s*"\(.*\)"/\1/p' | head -1)"
fi

# Only run on git commit commands
if [[ -z "$CMD" ]] || ! echo "$CMD" | grep -qE '^\s*git\s+commit\b'; then
    exit 0
fi

WARNINGS=()

# --- 1. Conventional Commits format check ---
# Extract the commit message from the command
COMMIT_MSG=""
if echo "$CMD" | grep -qE '\-m\s'; then
    # Extract message from -m flag
    COMMIT_MSG="$(echo "$CMD" | sed -n "s/.*-m\s*[\"']\(.*\)[\"'].*/\1/p" | head -1)"
    if [[ -z "$COMMIT_MSG" ]]; then
        COMMIT_MSG="$(echo "$CMD" | sed -n 's/.*-m\s*\([^ ]*\).*/\1/p' | head -1)"
    fi
fi

if [[ -n "$COMMIT_MSG" ]]; then
    # Check first line against Conventional Commits
    FIRST_LINE="$(echo "$COMMIT_MSG" | head -1)"
    if ! echo "$FIRST_LINE" | grep -qE '^(feat|fix|docs|style|refactor|perf|test|chore|ci|build|revert)(\(.+\))?!?:\s'; then
        WARNINGS+=("Commit message does not follow Conventional Commits format: '$FIRST_LINE'")
        WARNINGS+=("Expected format: <type>: <description> (e.g., feat: add new feature)")
    fi
fi

# --- 2. Secret detection in staged files ---
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    # Check staged file contents for secret patterns
    SECRET_PATTERNS=(
        'API_KEY\s*='
        'API_SECRET\s*='
        'SECRET_KEY\s*='
        'PRIVATE_KEY\s*='
        'ACCESS_TOKEN\s*='
        'AUTH_TOKEN\s*='
        'AWS_ACCESS_KEY_ID\s*='
        'AWS_SECRET_ACCESS_KEY\s*='
        'GITHUB_TOKEN\s*='
        'password\s*=\s*["\x27][^"\x27]{8,}'
    )

    STAGED_FILES="$(git diff --cached --name-only 2>/dev/null || true)"
    if [[ -n "$STAGED_FILES" ]]; then
        for pattern in "${SECRET_PATTERNS[@]}"; do
            MATCHES="$(git diff --cached -U0 2>/dev/null | grep -nE "^\+" | grep -iE "$pattern" | head -3 || true)"
            if [[ -n "$MATCHES" ]]; then
                WARNINGS+=("Detected potential secret pattern in staged files: $pattern")
                break
            fi
        done
    fi
fi

# --- Output warnings ---
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo "⚠ commit-quality check:" >&2
    for w in "${WARNINGS[@]}"; do
        echo "  - $w" >&2
    done
fi

exit 0
