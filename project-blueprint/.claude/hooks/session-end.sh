#!/usr/bin/env bash
# ==============================================================================
# session-end.sh — SessionEnd hook (2026 spec)
#
# 役割: セッション終了時に集計レポートを生成し、output/reports/sessions/ に追記する。
# 観測性向上の中核。Profile 切替に対応。
#
# Profile 切替: $BLUEPRINT_HOOK_PROFILE
#   - minimal:  何もしない(通過)
#   - standard: 1 行サマリのみ追記(既定)
#   - strict:   詳細レポート(変更ファイル・コミット数・テスト結果)を追記
#
# Input:  JSON via stdin {"session_id":"...", "transcript_path":"...", "reason":"..."}
# Output: exit 0 (常に通過)
# ==============================================================================

set -uo pipefail

PROFILE="${BLUEPRINT_HOOK_PROFILE:-standard}"
[[ "$PROFILE" == "minimal" ]] && exit 0

INPUT="$(cat)"
REPORT_DIR="${CLAUDE_PROJECT_DIR:-.}/output/reports/sessions"
mkdir -p "$REPORT_DIR" 2>/dev/null || exit 0

TODAY=$(date +%Y-%m-%d)
LOG="$REPORT_DIR/$TODAY.md"

if command -v jq &>/dev/null; then
    SID="$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)"
    REASON="$(printf '%s' "$INPUT" | jq -r '.reason // "stop"' 2>/dev/null)"
else
    SID="unknown"
    REASON="stop"
fi

NOW=$(date '+%H:%M:%S')

if [[ ! -f "$LOG" ]]; then
    {
        echo "# Session log — $TODAY"
        echo ""
        echo "| 終了時刻 | session_id | 終了理由 | 変更ファイル数 | コミット数 |"
        echo "| -------- | ---------- | -------- | -------------- | ---------- |"
    } > "$LOG"
fi

CHANGED=0
COMMITS=0
if [[ -d "${CLAUDE_PROJECT_DIR:-.}/.git" ]]; then
    CHANGED=$(git -C "${CLAUDE_PROJECT_DIR:-.}" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$PROFILE" == "strict" ]]; then
        # 直近 1 時間のコミット数(strict のみ)
        COMMITS=$(git -C "${CLAUDE_PROJECT_DIR:-.}" log --since="1 hour ago" --oneline 2>/dev/null | wc -l | tr -d ' ')
    fi
fi

printf '| %s | `%s` | %s | %s | %s |\n' "$NOW" "${SID:0:8}" "$REASON" "$CHANGED" "$COMMITS" >> "$LOG"

exit 0
