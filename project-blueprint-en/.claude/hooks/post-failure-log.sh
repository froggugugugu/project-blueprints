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
# Sanitize SESSION_ID to prevent path traversal (reject `/`, `..`, etc.)
SESSION_ID_RAW="${CLAUDE_SESSION_ID:-$(date +%Y%m%d)}"
SESSION_ID="$(printf '%s' "$SESSION_ID_RAW" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-64)"
[[ -z "$SESSION_ID" ]] && SESSION_ID="$(date +%Y%m%d)"
LOG_FILE="$LOG_DIR/$SESSION_ID.jsonl"

# --- Read stdin JSON ---
INPUT="$(cat)"

# Fail-open: empty input
if [[ -z "$INPUT" ]]; then
    exit 0
fi

# --- Check if this is actually a failure (fail-secure for audit) ---
# Default to "unknown" so that parse errors and malformed payloads are still
# recorded rather than silently dropped (prevents audit evasion).
IS_ERROR="unknown"
if command -v jq &>/dev/null; then
    IS_ERROR="$(echo "$INPUT" | jq -r '.tool_result.is_error // .tool_response.is_error // "unknown"' 2>/dev/null)"
    [[ -z "$IS_ERROR" ]] && IS_ERROR="unknown"
else
    # jq-absent fallback: coarse grep-based parse. Without jq we can't be fully
    # authoritative, so we positively identify true/false and otherwise keep
    # IS_ERROR="unknown" (which still gets logged, per fail-secure policy).
    if echo "$INPUT" | grep -qE '"is_error"[[:space:]]*:[[:space:]]*true\b'; then
        IS_ERROR="true"
    elif echo "$INPUT" | grep -qE '"is_error"[[:space:]]*:[[:space:]]*false\b'; then
        IS_ERROR="false"
    fi
fi

# Only skip when we are CERTAIN the tool call was NOT an error.
# Unknown / ambiguous / truthy values all fall through to recording.
case "$IS_ERROR" in
    false|False|0) exit 0 ;;
esac

# --- Extract fields ---
if command -v jq &>/dev/null; then
    TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)"
    # jq's .[0:500] is a character-based slice (multibyte-safe), unlike `head -c 500`
    # which splits on bytes and corrupts UTF-8 (e.g. Japanese error messages).
    ERROR_MSG="$(echo "$INPUT" | jq -r '(.tool_result.error // .tool_result.content[0].text // "unknown") | tostring | .[0:500]' 2>/dev/null)"
    # Emit raw compact JSON (no extra string-quoting) and byte-truncate.
    # Avoids double-encoding when later passed to `jq -nc --arg input_summary`.
    TOOL_INPUT_SUMMARY="$(echo "$INPUT" | jq -c '.tool_input' 2>/dev/null | cut -c1-500)"
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
