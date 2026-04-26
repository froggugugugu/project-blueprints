#!/usr/bin/env bash
# ==============================================================================
# user-prompt-submit.sh — UserPromptSubmit hook (2026 spec)
#
# 役割: ユーザー入力を Claude が処理する前に検査し、機密語・誤投稿を検出する。
# Profile 切替: $BLUEPRINT_HOOK_PROFILE で挙動切替
#   - minimal:  パススルー(検査スキップ)
#   - standard: 機密パターン検出のみ警告(non-blocking、既定)
#   - strict:   検出時にブロック(decision=block で差し戻し)
#
# Input:  JSON via stdin {"prompt": "...", "session_id": "..."}
# Output:
#   exit 0 + plain stdout = additional context を Claude に注入
#   exit 0 + JSON {"decision":"block","reason":"..."} = プロンプトを差し戻し
#   exit 2 = ブロック(stderr が Claude にフィードバック)
#
# Policy: fail-open — パース失敗時は通過させる(壊さない)。
# ==============================================================================

set -uo pipefail

PROFILE="${BLUEPRINT_HOOK_PROFILE:-standard}"
[[ "$PROFILE" == "minimal" ]] && exit 0

INPUT="$(cat)"

if command -v jq &>/dev/null; then
    PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)"
else
    PROMPT="$(printf '%s' "$INPUT" | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\(.*\)"[[:space:]]*}.*/\1/p' | head -1)"
fi

[[ -z "$PROMPT" ]] && exit 0

# 機密パターン(誤投稿リスク高い)
SECRET_PATTERNS=(
    'AKIA[0-9A-Z]{16}'                    # AWS Access Key ID
    'sk-[a-zA-Z0-9]{32,}'                  # OpenAI / Anthropic 形式
    'ghp_[a-zA-Z0-9]{36}'                  # GitHub Personal Access Token
    'gho_[a-zA-Z0-9]{36}'                  # GitHub OAuth Token
    'xox[baprs]-[a-zA-Z0-9-]+'             # Slack Token
    '-----BEGIN [A-Z ]+PRIVATE KEY-----'   # PEM private key
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
            # JSON で差し戻し(2026 仕様)
            printf '{"decision":"block","reason":"プロンプトに機密値の可能性のあるパターン (%s) が含まれます。値を [REDACTED] に置換して再送してください。"}\n' "$DETECTED"
            exit 0
            ;;
        standard|*)
            # 警告のみ(コンテキストに注入)
            printf '⚠️  user-prompt-submit hook: 機密パターン (%s) を検出しました。プロンプト内のシークレットを伏字化することを推奨します。\n' "$DETECTED"
            exit 0
            ;;
    esac
fi

exit 0
