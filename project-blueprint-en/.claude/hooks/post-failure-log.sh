#!/usr/bin/env bash
# ==============================================================================
# post-failure-log.sh — PostToolUse hook (failure branch)
#
# Records tool failure events as structured JSONL for debugging and audit.
# Runs AFTER a tool has failed (not blocking — the failure already happened).
#
# Input:  JSON via stdin  {"tool_name":"...","tool_input":{...},"tool_result":{"is_error":true,...}}
# Output: appends one JSONL line to testreport/failures/<session>.jsonl
#
# Policy: fail-open (if logging fails, we still exit 0)
# ==============================================================================

set -uo pipefail

# --- Paths ---
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOG_DIR="$PROJECT_DIR/testreport/failures"
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%Y%m%d)}"
LOG_FILE="$LOG_DIR/$SESSION_ID.jsonl"

# --- Read stdin JSON ---
INPUT="$(cat)"

# Fail-open: empty input
if [[ -z "$INPUT" ]]; then
    exit 0
fi

# --- Check if this is actually a failure ---
IS_ERROR="false"
if command -v jq &>/dev/null; then
    IS_ERROR="$(echo "$INPUT" | jq -r '.tool_result.is_error // .tool_response.is_error // false' 2>/dev/null)"
fi

# Only log actual failures
if [[ "$IS_ERROR" != "true" ]]; then
    exit 0
fi

# --- Extract fields ---
if command -v jq &>/dev/null; then
    TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)"
    ERROR_MSG="$(echo "$INPUT" | jq -r '.tool_result.error // .tool_result.content[0].text // "unknown"' 2>/dev/null | head -c 500)"
    TOOL_INPUT_SUMMARY="$(echo "$INPUT" | jq -c '.tool_input' 2>/dev/null | head -c 500)"
else
    TOOL_NAME="$(echo "$INPUT" | sed -n 's/.*"tool_name"\s*:\s*"\([^"]*\)".*/\1/p' | head -1)"
    ERROR_MSG="unknown"
    TOOL_INPUT_SUMMARY="unknown"
fi

# --- Ensure log directory exists ---
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

# --- Write JSONL line (escaped) ---
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Use jq to construct the JSON safely if available
if command -v jq &>/dev/null; then
    jq -nc \
        --arg timestamp "$TIMESTAMP" \
        --arg tool "$TOOL_NAME" \
        --arg error "$ERROR_MSG" \
        --arg input_summary "$TOOL_INPUT_SUMMARY" \
        --arg session "$SESSION_ID" \
        '{timestamp: $timestamp, tool: $tool, error: $error, input_summary: $input_summary, session_id: $session}' \
        >> "$LOG_FILE" 2>/dev/null || true
else
    # Fallback: manual escaping (best-effort)
    ESCAPED_ERROR="$(echo "$ERROR_MSG" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n')"
    printf '{"timestamp":"%s","tool":"%s","error":"%s","session_id":"%s"}\n' \
        "$TIMESTAMP" "$TOOL_NAME" "$ESCAPED_ERROR" "$SESSION_ID" \
        >> "$LOG_FILE" 2>/dev/null || true
fi

# Always exit 0 — observation only, failure already happened
exit 0
