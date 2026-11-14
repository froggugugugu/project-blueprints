#!/usr/bin/env bash
# ==============================================================================
# codex-adapter.sh — Codex のフック入力を共通形に直して .agents/hooks/<hook>.sh を呼ぶ
#
# フックスクリプトは Claude Code と Codex で共有する(.agents/hooks/*.sh)。Codex のフックは
# stdin JSON・exit 2・permissionDecision の形が Claude Code と同じなので、違う点だけをここで吸収する:
#
#   1. プロジェクトルート: Codex には CLAUDE_PROJECT_DIR が無い。このファイルの位置
#      (<root>/.agents/hooks/lib/)から求め、BLUEPRINT_PROJECT_DIR で渡す
#   2. セッション ID: 入力の session_id を BLUEPRINT_SESSION_ID で渡す
#   3. ファイル編集: Codex の編集は tool_name "apply_patch" で、パッチ本文が tool_input.command に入る。
#      パッチが触るファイルごとに {tool_name:"Edit", tool_input.file_path:<絶対パス>} の入力を作って
#      フックを 1 回ずつ呼ぶ。どれか 1 つが exit 2 ならブロックし、additionalContext は連結して返す
#   4. Stop / SubagentStop: Codex は exit 0 のとき stdout に JSON 以外を受け付けない。JSON でない出力は stderr へ回す
#
# 使い方(.codex/hooks.json の command):
#   "$(git rev-parse --show-toplevel)/.agents/hooks/lib/codex-adapter.sh" [--fail-closed] <hook.sh> [args...]
#
# --fail-closed: フック本体が見つからないときに exit 2 で止める(ブロック系フック用)。
#   Codex には Claude Code の `onFailure: "block"` に当たる設定が無いため、ここで代替する。
#   付けない場合は通過させる(観測系フックが壊れても作業を止めない)。
# ==============================================================================

set -uo pipefail

FAIL_CLOSED=0
if [[ "${1:-}" == "--fail-closed" ]]; then
    FAIL_CLOSED=1
    shift
fi
HOOK="${1:-}"
[[ $# -gt 0 ]] && shift

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_DIR="$(dirname "$LIB_DIR")"
SCRIPT="$HOOK_DIR/$HOOK"

give_up() {
    echo "codex-adapter: $1" >&2
    if [[ $FAIL_CLOSED -eq 1 ]]; then
        echo "codex-adapter: ブロック系フックを実行できないため、この操作を止めました。setup.sh --upgrade でフックを復元してください。" >&2
        exit 2
    fi
    exit 0
}

# フック名はファイル名だけを受け付ける(パス区切りを含む指定で .agents/hooks/ の外を実行させない)
if [[ -z "$HOOK" || "$HOOK" == */* ]]; then
    give_up "フック名が不正です: '${HOOK}'"
fi
if [[ ! -f "$SCRIPT" ]]; then
    give_up "フックが見つかりません: .agents/hooks/${HOOK}"
fi

INPUT="$(cat 2>/dev/null || true)"

export BLUEPRINT_AGENT="codex"
BLUEPRINT_PROJECT_DIR="$(cd "$HOOK_DIR/../.." && pwd)"
export BLUEPRINT_PROJECT_DIR

# bash 3.2(macOS 標準)では空配列の "${a[@]}" が set -u で落ちるため、引数の有無で呼び分ける
run_hook() {
    if [[ $# -gt 1 ]]; then
        local payload="$1"
        shift
        printf '%s' "$payload" | bash "$SCRIPT" "$@"
    else
        printf '%s' "$1" | bash "$SCRIPT"
    fi
}

# jq が無ければ変換せずに渡す(各フックの jq 不在時フォールバックに任せる)
if ! command -v jq &>/dev/null; then
    run_hook "$INPUT" "$@"
    exit $?
fi

SID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"
if [[ -n "$SID" ]]; then
    export BLUEPRINT_SESSION_ID="$SID"
fi
EVENT="$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"

# ── apply_patch: 触るファイルごとにフックを呼ぶ ─────────────────────────
if [[ "$TOOL" == "apply_patch" ]]; then
    CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)"
    [[ -n "$CWD" ]] || CWD="$BLUEPRINT_PROJECT_DIR"
    PATHS="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null | awk '
        /^\*\*\* (Add File|Update File|Delete File): / { sub(/^\*\*\* [A-Za-z]+ File: /, ""); print; next }
        /^\*\*\* Move to: /                           { sub(/^\*\*\* Move to: /, ""); print }
    ')"
    if [[ -n "$PATHS" ]]; then
        CONTEXTS=""
        while IFS= read -r rel; do
            [[ -z "$rel" ]] && continue
            case "$rel" in
                /*) abs="$rel" ;;
                *)  abs="$CWD/$rel" ;;
            esac
            one="$(printf '%s' "$INPUT" | jq -c --arg p "$abs" '.tool_name = "Edit" | .tool_input = ((.tool_input // {}) + {file_path: $p})' 2>/dev/null)"
            [[ -n "$one" ]] || continue
            out="$(run_hook "$one" "$@")"
            rc=$?
            if [[ $rc -eq 2 ]]; then
                exit 2
            fi
            ctx="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null || true)"
            if [[ -n "$ctx" ]]; then
                CONTEXTS="${CONTEXTS:+$CONTEXTS$'\n'}$ctx"
            fi
        done <<< "$PATHS"
        if [[ -n "$CONTEXTS" ]]; then
            jq -nc --arg e "${EVENT:-PostToolUse}" --arg t "$CONTEXTS" \
                '{hookSpecificOutput: {hookEventName: $e, additionalContext: $t}}'
        fi
        exit 0
    fi
    # パスを取り出せなかったパッチは変換せずに渡す(フック側は file_path が無ければ通過させる)
fi

# ── それ以外: そのまま渡す ───────────────────────────────────────────────
OUT="$(run_hook "$INPUT" "$@")"
RC=$?

if [[ ( "$EVENT" == "Stop" || "$EVENT" == "SubagentStop" ) && -n "$OUT" ]]; then
    if ! printf '%s' "$OUT" | jq -e . >/dev/null 2>&1; then
        printf '%s\n' "$OUT" >&2
        OUT=""
    fi
fi
if [[ -n "$OUT" ]]; then
    printf '%s\n' "$OUT"
fi
exit $RC
