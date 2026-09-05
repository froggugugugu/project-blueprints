#!/usr/bin/env bash
# ==============================================================================
# validate-harness.sh — `.claude/` ハーネスの静的検証ゲート
#
# 仕様との乖離を人間のレビュー待ちにせず、決定論的に落とす。
# `/harness-refine`(LLM 判断)の前段に置く非 LLM チェック。
#
# 使い方:
#   bash scripts/validate-harness.sh                  # 日英ミラー両方 + 構成一致
#   bash scripts/validate-harness.sh --root <dir>     # 単一ハーネスのみ
#   bash scripts/validate-harness.sh --online         # npm パッケージの実在確認も行う
#   bash scripts/validate-harness.sh --test           # バリデータ自身の負のテスト
#   bash scripts/validate-harness.sh --hooks          # フックスクリプトの機能テスト(要 jq)
#
# 終了コード: 0 = 合格 / 1 = ERROR あり / 2 = 実行環境の不備
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PYTHON=""
for candidate in python3 python; do
    if command -v "$candidate" &>/dev/null; then
        PYTHON="$candidate"
        break
    fi
done

if [[ -z "$PYTHON" ]]; then
    echo "ERROR: python3 が見つかりません。バリデータの実行には Python 3.8 以上が必要です。" >&2
    exit 2
fi

# --test はバリデータ自身のテスト、--hooks はフックの機能テストに振り分ける
for arg in "$@"; do
    if [[ "$arg" == "--test" ]]; then
        exec "$PYTHON" "$SCRIPT_DIR/test_validate_harness.py"
    fi
    if [[ "$arg" == "--hooks" ]]; then
        exec bash "$SCRIPT_DIR/test_hooks.sh"
    fi
done

exec "$PYTHON" "$SCRIPT_DIR/validate_harness.py" "$@"
