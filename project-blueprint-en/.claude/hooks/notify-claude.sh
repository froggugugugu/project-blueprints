#!/usr/bin/env bash
# Push notifications to your phone and bidirectional communication via ntfy.sh
#
# Usage:
#   notify-claude.sh stop                 — Send completion notification
#   notify-claude.sh notify               — Send message from stdin JSON (fire-and-forget)
#   notify-claude.sh notify --wait [sec]  — Send notification + wait for response (default 120 sec)
#
# --wait mode response flow:
#   1. Generate a request ID (4-char hex) and prepend [ID] to the message
#   2. Send notification with Yes/No/Reply action buttons
#   3. Subscribe to response topic ({TOPIC}-res) via JSON stream
#   4. Match by request ID and output the matching response to stdout
#   5. stdout: "yes" / "no" / free text / fallback value on timeout
#
# Timeout fallback:
#   Returns the first line of ntfy-timeout-fallback.txt (default: "timeout")
#   Can be set to "yes" / "no" / "timeout" / any string depending on use case
#   exit code: 2 on timeout (0 on normal response)
#
# Testing:
#   echo '{"message":"test"}' | ./notify-claude.sh notify
#   echo '{"message":"OK to deploy?"}' | ./notify-claude.sh notify --wait 30
#   # In another terminal: curl -d "XXXX:yes" https://ntfy.sh/{TOPIC}-res

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOPIC_FILE="${SCRIPT_DIR}/ntfy-topic.txt"

if [ ! -f "$TOPIC_FILE" ]; then
  exit 0
fi

NTFY_TOPIC="$(head -1 "$TOPIC_FILE" | tr -d '[:space:]')"
NTFY_URL="https://ntfy.sh/${NTFY_TOPIC}"
RESPONSE_TOPIC="${NTFY_TOPIC}-res"
RESPONSE_URL="https://ntfy.sh/${RESPONSE_TOPIC}"

generate_request_id() {
  od -An -tx1 -N2 /dev/urandom | tr -d ' \n'
}

# Get timeout fallback value
# Returns first line of ntfy-timeout-fallback.txt if it exists, otherwise "timeout"
get_timeout_fallback() {
  local fallback_file="${SCRIPT_DIR}/ntfy-timeout-fallback.txt"
  if [ -f "$fallback_file" ]; then
    head -1 "$fallback_file" | tr -d '[:space:]'
  else
    echo "timeout"
  fi
}

event_type="${1:-notify}"

case "$event_type" in
  stop)
    curl -s -d "Claude Code: Task completed" "$NTFY_URL" >/dev/null 2>&1 || true
    ;;

  notify)
    # Read Notification event JSON from stdin
    input=$(cat)
    message=$(echo "$input" | jq -r '.message // empty' 2>/dev/null)
    if [ -z "$message" ]; then
      message="Claude Code: Waiting for input"
    fi

    # --wait option check
    shift
    wait_mode=false
    wait_timeout=120
    while [ $# -gt 0 ]; do
      case "$1" in
        --wait)
          wait_mode=true
          if [ -n "${2:-}" ] && [[ "${2:-}" =~ ^[0-9]+$ ]]; then
            wait_timeout="${2:-}"
            shift
          fi
          ;;
      esac
      shift
    done

    if [ "$wait_mode" = false ]; then
      # fire-and-forget: notification only
      curl -s -d "$message" "$NTFY_URL" >/dev/null 2>&1 || true
    else
      # Blocking: notification with request ID + wait for response
      request_id=$(generate_request_id)
      tagged_message="[${request_id}] ${message}"

      # Send notification with action buttons (JSON format)
      payload=$(jq -n \
        --arg topic "$NTFY_TOPIC" \
        --arg msg "$tagged_message" \
        --arg res_url "$RESPONSE_URL" \
        --arg yes_body "${request_id}:yes" \
        --arg no_body "${request_id}:no" \
        --arg reply_url "https://ntfy.sh/${RESPONSE_TOPIC}" \
        '{
          topic: $topic,
          message: $msg,
          title: "Claude Code",
          priority: 4,
          actions: [
            { action: "http", label: "Yes", url: $res_url, body: $yes_body, clear: true },
            { action: "http", label: "No", url: $res_url, body: $no_body, clear: true },
            { action: "view", label: "Reply", url: $reply_url, clear: true }
          ]
        }')

      curl -s -d "$payload" "$NTFY_URL" >/dev/null 2>&1

      # Wait for response via JSON stream (match by request ID)
      matched=false
      while IFS= read -r line; do
        event=$(echo "$line" | jq -r '.event // empty' 2>/dev/null)
        [ "$event" = "message" ] || continue

        msg=$(echo "$line" | jq -r '.message // empty' 2>/dev/null)
        if [[ "$msg" == "${request_id}:"* ]]; then
          answer="${msg#"${request_id}":}"
          echo "$answer"
          matched=true
          break
        fi
      done < <(timeout "$wait_timeout" curl -s -N "${RESPONSE_URL}/json?since=now" 2>/dev/null)

      if [ "$matched" = false ]; then
        get_timeout_fallback
        exit 2
      fi
    fi
    ;;

  *)
    curl -s -d "Claude Code: ${event_type}" "$NTFY_URL" >/dev/null 2>&1 || true
    ;;
esac
