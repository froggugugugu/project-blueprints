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
    # source == "compact" は起動時チェックを繰り返さず、中核ルールを即座に再注入する(公式の SessionStart compact パターン)
    OUT="$(run_hook "$H/session-start.sh" "" '{"session_id":"s","source":"compact"}')"
    expect_contains "session-start(compact): 中核ルールを再注入" 'post-compact recovery' "$OUT"
    expect_contains "session-start(compact): PROGRESS.md も併せて注入" 'progress handoff' "$OUT"
    [[ "$OUT" != *"300"* ]] && ok "session-start(compact): 起動時チェックは繰り返さない" || ng "session-start(compact): 起動時チェックは繰り返さない" "no readiness warnings" "$OUT"

    # ── post-failure-log.sh(PostToolUseFailure)───────────────────
    run_hook "$H/post-failure-log.sh" "" '{"session_id":"fail0001","tool_name":"Bash","tool_input":{"command":"npm test"},"error":"exit 1","duration_ms":12}' >/dev/null
    expect_rc "post-failure-log: 常に exit 0" 0 "$RC"

    # ── scope-guard.sh(agent frontmatter の PreToolUse)───────────
    for spec in "docs|docs/project.md|0" "docs|project-config.md|0" "docs|src/app.ts|2" "docs|docs/../src/app.ts|2" \
                "output|output/reports/x.md|0" "output|docs/x.md|2" \
                "tests|src/a.test.ts|0" "tests|e2e/login.spec.ts|0" "tests|tests/fixtures/u.json|0" "tests|src/a.ts|2" \
                "unknown|docs/x.md|2"; do
        IFS='|' read -r sc rel want <<<"$spec"
        run_hook "$H/scope-guard.sh" "$sc" "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$T/$rel\"}}" >/dev/null
        expect_rc "scope-guard $sc: $rel" "$want" "$RC"
    done
    run_hook "$H/scope-guard.sh" docs '{"tool_name":"Edit","tool_input":{"file_path":"/etc/hosts"}}' >/dev/null
    expect_rc "scope-guard docs: プロジェクト外の絶対パスはブロック" 2 "$RC"
    run_hook "$H/scope-guard.sh" docs '{"tool_name":"Bash","tool_input":{"command":"ls"}}' >/dev/null
    expect_rc "scope-guard: file_path の無い入力は通過" 0 "$RC"

    # ── scan-harness.sh(PreToolUse: Skill)— ルートの指示ファイルも secret 検査する ─
    mkdir -p "$T/.claude"
    printf '# rules\nkey: %s\n' "$FAKE_KEY" > "$T/AGENTS.md"
    OUT="$(run_hook "$H/scan-harness.sh" "" '{"tool_name":"Skill","tool_input":{"skill":"security-scan"}}' standard)"
    expect_contains "scan-harness: AGENTS.md の secret を検出" "AGENTS.md" "$OUT"
    rm -f "$T/AGENTS.md"
    OUT="$(run_hook "$H/scan-harness.sh" "" '{"tool_name":"Skill","tool_input":{"skill":"security-scan"}}' standard)"
    expect_empty "scan-harness: secret が無ければ無出力" "$OUT"

    # ── config-guard.sh(ConfigChange)— 防御層を弱める設定変更だけをブロックする ──
    printf '{"disableAllHooks": true}' > "$T/.claude/settings.local.json"
    run_hook "$H/config-guard.sh" "" "{\"session_id\":\"cg1\",\"source\":\"local_settings\",\"file_path\":\"$T/.claude/settings.local.json\"}" standard >/dev/null
    expect_rc "config-guard: disableAllHooks はブロック(standard でも)" 2 "$RC"
    printf '{"permissions":{"deny":[]}}' > "$T/.claude/settings.local.json"
    run_hook "$H/config-guard.sh" "" "{\"session_id\":\"cg1\",\"source\":\"local_settings\",\"file_path\":\"$T/.claude/settings.local.json\"}" strict >/dev/null
    expect_rc "config-guard: local の permissions.deny(空配列)はブロック" 2 "$RC"
    printf '{"permissions":{"allow":["Bash(ls *)"]}}' > "$T/.claude/settings.local.json"
    run_hook "$H/config-guard.sh" "" "{\"session_id\":\"cg1\",\"source\":\"local_settings\",\"file_path\":\"$T/.claude/settings.local.json\"}" standard >/dev/null
    expect_rc "config-guard: allow の追加は通過" 0 "$RC"
    cp "$REPO/$MIRROR/.claude/settings.json" "$T/.claude/settings.json"
    run_hook "$H/config-guard.sh" "" "{\"session_id\":\"cg1\",\"source\":\"project_settings\",\"file_path\":\"$T/.claude/settings.json\"}" standard >/dev/null
    expect_rc "config-guard: テンプレートの settings.json は通過" 0 "$RC"
    jq 'del(.hooks.PreToolUse[] | select(.hooks[].command | contains("protect-files")))' "$REPO/$MIRROR/.claude/settings.json" > "$T/.claude/settings.json"
    run_hook "$H/config-guard.sh" "" "{\"session_id\":\"cg1\",\"source\":\"project_settings\",\"file_path\":\"$T/.claude/settings.json\"}" standard >/dev/null
    expect_rc "config-guard: protect-files.sh の削除はブロック" 2 "$RC"
    jq '(.hooks.PreToolUse[].hooks[] | select(.command | contains("safety-check"))) |= del(.onFailure)' "$REPO/$MIRROR/.claude/settings.json" > "$T/.claude/settings.json"
    run_hook "$H/config-guard.sh" "" "{\"session_id\":\"cg1\",\"source\":\"project_settings\",\"file_path\":\"$T/.claude/settings.json\"}" standard >/dev/null
    expect_rc "config-guard: safety-check.sh の onFailure: block 削除はブロック" 2 "$RC"
    run_hook "$H/config-guard.sh" "" "{\"session_id\":\"cg1\",\"source\":\"project_settings\",\"file_path\":\"$T/.claude/settings.json\"}" minimal >/dev/null
    expect_rc "config-guard: minimal は素通り" 0 "$RC"
    run_hook "$H/config-guard.sh" "" '{"session_id":"cg1","source":"policy_settings","file_path":"/nonexistent/managed-settings.json"}' strict >/dev/null
    expect_rc "config-guard: 読めないファイル / policy_settings は通過(fail-open)" 0 "$RC"
    LOG="$(cat "$T/testreport/config-changes/cg1.jsonl" 2>/dev/null)"
    expect_contains "config-guard: JSONL に判定を記録" '"decision":"block"' "$LOG"

    # ── scan-harness.sh(UserPromptExpansion)— `/skill` の直接入力でも高リスク skill を止める ──
    run_hook "$H/scan-harness.sh" "" '{"hook_event_name":"UserPromptExpansion","expansion_type":"slash_command","command_name":"deploy","command_args":"","prompt":"/deploy"}' standard >/dev/null
    expect_rc "scan-harness(UserPromptExpansion): /deploy の直接入力はブロック" 2 "$RC"
    run_hook "$H/scan-harness.sh" "" '{"hook_event_name":"UserPromptExpansion","expansion_type":"slash_command","command_name":"my-plugin:deploy-prod","prompt":"/my-plugin:deploy-prod"}' standard >/dev/null
    expect_rc "scan-harness(UserPromptExpansion): plugin 名前空間付きの deploy もブロック" 2 "$RC"
    run_hook "$H/scan-harness.sh" "" '{"hook_event_name":"UserPromptExpansion","expansion_type":"slash_command","command_name":"prd","command_args":"x.md","prompt":"/prd x.md"}' standard >/dev/null
    expect_rc "scan-harness(UserPromptExpansion): 通常 skill は通過" 0 "$RC"
    run_hook "$H/scan-harness.sh" "" '{"hook_event_name":"UserPromptExpansion","expansion_type":"mcp_prompt","command_name":"deploy","prompt":"/mcp__x__deploy"}' standard >/dev/null
    expect_rc "scan-harness(UserPromptExpansion): MCP prompt の展開は対象外" 0 "$RC"

    # ── scan-harness.sh(FileChanged)— constitution.md のディスク上の改変を検知(ブロック不可。stderr + 記録)──
    printf '# constitution\n' > "$T/constitution.md"
    if command -v sha256sum &>/dev/null; then sha256sum "$T/constitution.md" | cut -d' ' -f1 > "$T/.claude/.constitution.sha256"; else shasum -a 256 "$T/constitution.md" | cut -d' ' -f1 > "$T/.claude/.constitution.sha256"; fi
    run_hook "$H/scan-harness.sh" filechanged "{\"hook_event_name\":\"FileChanged\",\"session_id\":\"fc1\",\"file_path\":\"$T/constitution.md\"}" standard >/dev/null
    expect_rc "scan-harness(FileChanged): ハッシュ一致は exit 0" 0 "$RC"
    [[ ! -f "$T/testreport/config-changes/fc1.jsonl" ]] && ok "scan-harness(FileChanged): 一致なら記録しない" || ng "scan-harness(FileChanged): 一致なら記録しない" "no fc1.jsonl" "exists"
    printf '# tampered\n' >> "$T/constitution.md"
    ERR="$(printf '%s' "{\"hook_event_name\":\"FileChanged\",\"session_id\":\"fc1\",\"file_path\":\"$T/constitution.md\"}" | BLUEPRINT_HOOK_PROFILE=standard bash "$H/scan-harness.sh" filechanged 2>&1 >/dev/null)"
    expect_contains "scan-harness(FileChanged): 不一致は stderr(ユーザー向け)で警告" "constitution.md" "$ERR"
    LOG="$(cat "$T/testreport/config-changes/fc1.jsonl" 2>/dev/null)"
    expect_contains "scan-harness(FileChanged): 不一致を JSONL に記録" '"source":"file_watch"' "$LOG"
    rm -f "$T/constitution.md" "$T/.claude/.constitution.sha256"

    # ── verify-gate.sh teammate(TeammateIdle)— teammate の手待ちにも検証ゲートを掛ける ──
    run_hook "$H/verify-gate.sh" track "{\"session_id\":\"tm1\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$T/src/b.ts\"}}" >/dev/null
    run_hook "$H/verify-gate.sh" teammate '{"session_id":"tm1","teammate_name":"dev"}' strict >/dev/null
    expect_rc "verify-gate teammate: strict は exit 2(teammate は作業を続ける)" 2 "$RC"
    OUT="$(run_hook "$H/verify-gate.sh" teammate '{"session_id":"tm1","teammate_name":"dev"}' standard)"
    expect_contains "verify-gate teammate: standard は systemMessage" '"systemMessage"' "$OUT"
    run_hook "$H/verify-gate.sh" track '{"session_id":"tm1","tool_name":"Bash","tool_input":{"command":"npm test"}}' >/dev/null
    run_hook "$H/verify-gate.sh" teammate '{"session_id":"tm1","teammate_name":"dev"}' strict >/dev/null
    expect_rc "verify-gate teammate: 検証後は通過" 0 "$RC"

    # ── post-failure-log.sh(StopFailure)— API エラーによるターン終了も記録する ──
    CLAUDE_SESSION_ID=sf0001 run_hook "$H/post-failure-log.sh" "" '{"session_id":"sf0001","hook_event_name":"StopFailure","error":"rate_limit","error_details":"429 Too Many Requests","last_assistant_message":"API Error: Rate limit reached"}' >/dev/null
    expect_rc "post-failure-log(StopFailure): exit 0" 0 "$RC"
    LOG="$(cat "$T/testreport/failures/sf0001.jsonl" 2>/dev/null)"
    expect_contains "post-failure-log(StopFailure): tool=api:<error> で記録" '"tool":"api:rate_limit"' "$LOG"
    expect_contains "post-failure-log(StopFailure): error_details を記録" '429 Too Many Requests' "$LOG"

    # ── permission-denied-log.sh request(PermissionRequest)— 無人実行で止まった呼び出しも同じログに残す ──
    run_hook "$H/permission-denied-log.sh" request '{"session_id":"pr000001","hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"npm publish"},"permission_mode":"dontAsk","permission_suggestions":[{"type":"addRules"}]}' >/dev/null
    LOG="$(cat "$T/testreport/denials/pr000001.jsonl" 2>/dev/null)"
    expect_contains "permission-denied-log(request): kind=request で記録" '"kind":"request"' "$LOG"
    expect_contains "permission-denied-log(request): suggestions 件数を記録" '"suggestions":1' "$LOG"
    LOG="$(cat "$T/testreport/denials/abcdef12.jsonl" 2>/dev/null)"
    expect_contains "permission-denied-log(denied): 既定は kind=denied" '"kind":"denied"' "$LOG"

    # ── instructions-log.sh(InstructionsLoaded)— rule の load 実績を記録。プロジェクト外のパスはファイル名だけ残す ──
    run_hook "$H/instructions-log.sh" "" "{\"session_id\":\"il000001\",\"hook_event_name\":\"InstructionsLoaded\",\"file_path\":\"$T/.claude/rules/x.md\",\"memory_type\":\"Project\",\"load_reason\":\"path_glob_match\",\"globs\":[\"src/**\"],\"trigger_file_path\":\"$T/src/a.ts\"}" >/dev/null
    run_hook "$H/instructions-log.sh" "" '{"session_id":"il000001","hook_event_name":"InstructionsLoaded","file_path":"/home/someone/.claude/CLAUDE.md","memory_type":"User","load_reason":"session_start"}' >/dev/null
    expect_rc "instructions-log: exit 0" 0 "$RC"
    LOG="$(cat "$T/testreport/instructions/il000001.jsonl" 2>/dev/null)"
    expect_contains "instructions-log: プロジェクト相対パスと load_reason を記録" '"file":".claude/rules/x.md","memory_type":"Project","load_reason":"path_glob_match"' "$LOG"
    expect_contains "instructions-log: プロジェクト外はファイル名だけ" '"file":"…/CLAUDE.md"' "$LOG"
    [[ "$LOG" != *"/home/someone"* ]] && ok "instructions-log: ホームディレクトリのパスを残さない" || ng "instructions-log: ホームディレクトリのパスを残さない" "no /home/someone" "$LOG"
    run_hook "$H/instructions-log.sh" "" '{"session_id":"il000002","hook_event_name":"InstructionsLoaded","file_path":"/x/CLAUDE.md"}' minimal >/dev/null
    [[ ! -f "$T/testreport/instructions/il000002.jsonl" ]] && ok "instructions-log: minimal は記録しない" || ng "instructions-log: minimal は記録しない" "no file" "exists"

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
