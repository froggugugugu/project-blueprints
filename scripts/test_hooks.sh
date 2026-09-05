#!/usr/bin/env bash
# ==============================================================================
# test_hooks.sh — フックスクリプトの機能テスト(日英ミラー両方)
#
# validate_harness.py は「構文が通るか / 登録されているか」しか見ない。
# ここでは実際に stdin へ hook JSON を流し込み、期待どおりの exit code / JSON を
# 返すかを検証する。ガードレールが "存在するだけ" にならないための回帰テスト。
#
#   bash scripts/validate-harness.sh --hooks   # ラッパー経由
#   bash scripts/test_hooks.sh                 # 直接
#
# 要件: bash 4+, jq。終了コード: 0 = 全件 PASS / 1 = FAIL あり / 2 = 環境不備
# ==============================================================================

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v jq &>/dev/null || { echo "ERROR: jq が必要です" >&2; exit 2; }

PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
ng()   { echo "  [FAIL] $1"; echo "        期待: $2"; echo "        実際: ${3:0:240}"; FAIL=$((FAIL + 1)); }

# expect_contains <name> <expected-substring> <actual>
expect_contains() { [[ "$3" == *"$2"* ]] && ok "$1" || ng "$1" "contains '$2'" "$3"; }
# expect_empty <name> <actual>
expect_empty()    { [[ -z "$2" ]] && ok "$1" || ng "$1" "(empty)" "$2"; }
# expect_rc <name> <expected-rc> <actual-rc>
expect_rc()       { [[ "$3" == "$2" ]] && ok "$1" || ng "$1" "exit $2" "exit $3"; }

# run_hook <script> <mode-arg or ''> <json> <profile>  → stdout に出力、RC に exit code
RC=0
run_hook() {
    local script="$1" arg="$2" json="$3" profile="${4:-standard}"
    local out
    if [[ -n "$arg" ]]; then
        out="$(printf '%s' "$json" | BLUEPRINT_HOOK_PROFILE="$profile" bash "$script" "$arg" 2>/dev/null)"
    else
        out="$(printf '%s' "$json" | BLUEPRINT_HOOK_PROFILE="$profile" bash "$script" 2>/dev/null)"
    fi
    RC=$?
    printf '%s' "$out"
}

for MIRROR in project-blueprint project-blueprint-en; do
    H="$REPO/$MIRROR/.claude/hooks"
    [[ -d "$H" ]] || continue
    echo "== $MIRROR =="

    T="$(mktemp -d)"
    mkdir -p "$T/src" "$T/docs" "$T/output/tasks"
    export CLAUDE_PROJECT_DIR="$T"

    # ── safety-check.sh(PreToolUse: Bash)──────────────────────────
    run_hook "$H/safety-check.sh" "" '{"tool_name":"Bash","tool_input":{"command":"git push origin main --force"}}' >/dev/null
    expect_rc "safety-check: force push はブロック" 2 "$RC"
    run_hook "$H/safety-check.sh" "" '{"tool_name":"Bash","tool_input":{"command":"git status --short"}}' >/dev/null
    expect_rc "safety-check: 安全なコマンドは通過" 0 "$RC"
    run_hook "$H/safety-check.sh" "" 'not json at all' >/dev/null
    expect_rc "safety-check: パース不能は fail-open" 0 "$RC"

    # ── protect-files.sh(PreToolUse: Edit|Write)──────────────────
    run_hook "$H/protect-files.sh" "" "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$T/.env\"}}" >/dev/null
    expect_rc "protect-files: .env への書込はブロック" 2 "$RC"
    run_hook "$H/protect-files.sh" "" "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$T/.claude/settings.json\"}}" >/dev/null
    expect_rc "protect-files: settings.json への書込はブロック" 2 "$RC"
    run_hook "$H/protect-files.sh" "" "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$T/src/app.ts\"}}" >/dev/null
    expect_rc "protect-files: ソースへの書込は通過" 0 "$RC"

    # ── user-prompt-submit.sh(UserPromptSubmit)───────────────────
    FAKE_KEY="AKIA$(printf 'EXAMPLEEXAMPLE00')"   # AWS 形式の偽キー(ファイル内に生パターンを残さない)
    OUT="$(run_hook "$H/user-prompt-submit.sh" "" "{\"prompt\":\"use key $FAKE_KEY please\"}" standard)"
    expect_contains "user-prompt-submit: standard は additionalContext で警告" '"additionalContext"' "$OUT"
    OUT="$(run_hook "$H/user-prompt-submit.sh" "" "{\"prompt\":\"use key $FAKE_KEY please\"}" strict)"
    expect_contains "user-prompt-submit: strict は block" '"decision":"block"' "$OUT"
    OUT="$(run_hook "$H/user-prompt-submit.sh" "" '{"prompt":"hello"}' standard)"
    expect_empty "user-prompt-submit: 通常プロンプトは無出力" "$OUT"

    # ── verify-gate.sh(PostToolUse track / Stop gate / TaskCompleted task)──
    run_hook "$H/verify-gate.sh" track "{\"session_id\":\"s1\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$T/src/app.ts\"}}" >/dev/null
    [[ -f "$T/testreport/.verify/s1.edit" ]] && ok "verify-gate track: ソース編集を記録" || ng "verify-gate track: ソース編集を記録" "s1.edit exists" "$(ls "$T/testreport/.verify" 2>/dev/null)"
    run_hook "$H/verify-gate.sh" track "{\"session_id\":\"s2\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$T/docs/x.md\"}}" >/dev/null
    [[ ! -f "$T/testreport/.verify/s2.edit" ]] && ok "verify-gate track: docs 編集は対象外" || ng "verify-gate track: docs 編集は対象外" "no s2.edit" "s2.edit exists"
    run_hook "$H/verify-gate.sh" track '{"session_id":"s3","tool_name":"Bash","tool_input":{"command":"test -f foo && echo ok"}}' >/dev/null
    [[ ! -f "$T/testreport/.verify/s3.verify" ]] && ok "verify-gate track: 'test -f' は検証扱いしない" || ng "verify-gate track: 'test -f' は検証扱いしない" "no s3.verify" "s3.verify exists"

    OUT="$(run_hook "$H/verify-gate.sh" gate '{"session_id":"s1","stop_hook_active":false,"background_tasks":[]}' standard)"
    expect_contains "verify-gate gate: standard は systemMessage" '"systemMessage"' "$OUT"
    OUT="$(run_hook "$H/verify-gate.sh" gate '{"session_id":"s1","stop_hook_active":false}' strict)"
    expect_contains "verify-gate gate: strict は block" '"decision":"block"' "$OUT"
    OUT="$(run_hook "$H/verify-gate.sh" gate '{"session_id":"s1","stop_hook_active":true}' strict)"
    expect_empty "verify-gate gate: stop_hook_active は通過(ループ防止)" "$OUT"
    OUT="$(run_hook "$H/verify-gate.sh" gate '{"session_id":"s1","stop_hook_active":false,"background_tasks":[{"id":"1","type":"shell"}]}' strict)"
    expect_empty "verify-gate gate: background_tasks 非空は通過" "$OUT"
    OUT="$(run_hook "$H/verify-gate.sh" gate '{"session_id":"s1","stop_hook_active":false}' minimal)"
    expect_empty "verify-gate gate: minimal は素通り" "$OUT"
    # exit code を見るケースはコマンド置換 $(...) に入れない(RC がサブシェルに閉じる)
    run_hook "$H/verify-gate.sh" task '{"session_id":"s1","task_id":"t1"}' strict >/dev/null
    expect_rc "verify-gate task: strict は TaskCompleted をブロック(exit 2)" 2 "$RC"
    OUT="$(run_hook "$H/verify-gate.sh" task '{"session_id":"s1","task_id":"t1"}' standard)"
    expect_contains "verify-gate task: standard は systemMessage" '"systemMessage"' "$OUT"

    sleep 1
    run_hook "$H/verify-gate.sh" track '{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"npm test -- --run"}}' >/dev/null
    OUT="$(run_hook "$H/verify-gate.sh" gate '{"session_id":"s1","stop_hook_active":false}' strict)"
    expect_empty "verify-gate gate: 検証コマンド後は通過" "$OUT"
    run_hook "$H/verify-gate.sh" task '{"session_id":"s1","task_id":"t1"}' strict >/dev/null
    expect_rc "verify-gate task: 検証コマンド後は完了を許可" 0 "$RC"
    run_hook "$H/verify-gate.sh" track '{"session_id":"s4","tool_name":"Bash","tool_input":{"command":"cd api && pytest tests/ -q"}}' >/dev/null
    [[ -f "$T/testreport/.verify/s4.verify" ]] && ok "verify-gate track: pytest を検証扱い" || ng "verify-gate track: pytest を検証扱い" "s4.verify exists" "missing"

    # ── permission-denied-log.sh(PermissionDenied)────────────────
    run_hook "$H/permission-denied-log.sh" "" '{"session_id":"abcdef12","tool_name":"Bash","tool_input":{"command":"aws s3 cp build.zip s3://external/"},"reason":"Blocked by classifier","permission_mode":"auto"}' >/dev/null
    LOG="$(cat "$T/testreport/denials/abcdef12.jsonl" 2>/dev/null)"
    expect_contains "permission-denied-log: JSONL に記録" '"reason":"Blocked by classifier"' "$LOG"

    # ── session-start.sh(SessionStart: PROGRESS 注入 + docs 肥大化)──
    cp "$REPO/$MIRROR/.claude/tasks/PROGRESS_TEMPLATE.md" "$T/output/tasks/PROGRESS.md"
    for i in $(seq 1 400); do echo "- line $i"; done > "$T/docs/project.md"
    OUT="$(run_hook "$H/session-start.sh" "" '{"session_id":"s","source":"startup"}')"
    expect_contains "session-start: PROGRESS.md を注入" 'progress handoff' "$OUT"
    expect_contains "session-start: docs 肥大化を警告(目安 300 行)" '300' "$OUT"
    CTX="$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)"
    [[ ${#CTX} -le 10000 ]] && ok "session-start: additionalContext は 10,000 文字以内" || ng "session-start: additionalContext は 10,000 文字以内" "<= 10000" "${#CTX}"

    # ── post-failure-log.sh(PostToolUseFailure)───────────────────
    run_hook "$H/post-failure-log.sh" "" '{"session_id":"fail0001","tool_name":"Bash","tool_input":{"command":"npm test"},"error":"exit 1","duration_ms":12}' >/dev/null
    expect_rc "post-failure-log: 常に exit 0" 0 "$RC"

    unset CLAUDE_PROJECT_DIR
    rm -rf "$T"
done

echo
echo "結果: PASS $PASS / FAIL $FAIL"
if (( FAIL > 0 )); then
    echo "フックの機能テストに失敗があります。"
    exit 1
fi
echo "フックの機能テスト全件 PASS。"
exit 0
