#!/usr/bin/env bash
# ==============================================================================
# test_migrate.sh — migrate.sh(0.x の配置 → 1.0 の配置)の機能テスト(日英ミラー両方)
#
# 合成した旧環境ではなく、このリポジトリの git 履歴から 0.x のテンプレートを取り出し、当時の setup.sh で
# 実際に導入したプロジェクトを移行する。移行シェルの主経路(manifest の無い 0.4.0 を、テンプレートの履歴との
# 照合で「未変更 / 変更あり」に分ける)は、本物の履歴でしか確かめられないため。
#
#   bash scripts/validate-harness.sh --migrate   # ラッパー経由
#   bash scripts/test_migrate.sh                 # 直接
#
# 要件: git の履歴(shallow clone では不可。CI は fetch-depth: 0)、jq。
# 終了コード: 0 = 全件 PASS / 1 = FAIL あり / 2 = 実行環境の不備(履歴が無い)
# ==============================================================================

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

# 0.x の基準コミット
#   LEGACY_040: v0.4.0 のリリースコミット。manifest を持たない(リリース済みの 0.x はすべてこの形)
#   LEGACY_V1 : 1.0 直前の main。.claude/blueprint-manifest.txt(v1)を書く
LEGACY_040="3fffe64"
LEGACY_V1="eda6185"

ok() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
ng() { echo "  [FAIL] $1"; echo "        期待: $2"; echo "        実際: ${3:0:300}"; FAIL=$((FAIL + 1)); }
expect_eq()       { [[ "$3" == "$2" ]] && ok "$1" || ng "$1" "$2" "$3"; }
expect_exists()   { [[ -e "$2" ]] && ok "$1" || ng "$1" "exists: $2" "missing"; }
expect_missing()  { [[ ! -e "$2" && ! -L "$2" ]] && ok "$1" || ng "$1" "missing: $2" "exists"; }
expect_contains() { [[ "$3" == *"$2"* ]] && ok "$1" || ng "$1" "contains '$2'" "$3"; }
expect_link()     { [[ -L "$2" ]] && ok "$1" || ng "$1" "symlink: $2" "not a symlink"; }

sha() { shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1 || sha256sum "$1" | cut -d' ' -f1; }
field() { sed -n "s/^# $2: //p" "$1/.agents/blueprint-manifest.txt" | head -1; }
strip_color() { sed $'s/\x1b\\[[0-9;]*m//g'; }
git_q() { git -C "$1" -c user.name=test -c user.email=test@example.invalid "${@:2}"; }

for c in "$LEGACY_040" "$LEGACY_V1"; do
    if ! git -C "$REPO" cat-file -e "${c}^{commit}" 2>/dev/null; then
        echo "ERROR: 基準コミット $c が履歴にありません。shallow clone では実行できません(git fetch --unshallow、CI は fetch-depth: 0)" >&2
        exit 2
    fi
done
command -v jq &>/dev/null || { echo "ERROR: jq が必要です" >&2; exit 2; }

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

# 0.x のテンプレートを履歴から取り出す(2 つの基準コミット × 日英)
mkdir -p "$ROOT/t040" "$ROOT/tv1"
git -C "$REPO" archive "$LEGACY_040" project-blueprint project-blueprint-en VERSION | tar -x -C "$ROOT/t040"
git -C "$REPO" archive "$LEGACY_V1" project-blueprint project-blueprint-en VERSION | tar -x -C "$ROOT/tv1"

# make_legacy <old-template-root> <mirror> <dest> [setup-args...] — 当時の setup.sh で導入し、git に載せる
make_legacy() {
    local tmpl="$1" mirror="$2" dest="$3"
    shift 3
    bash "$tmpl/$mirror/setup.sh" "$dest" "$@" >/dev/null 2>&1 || return 1
    git -C "$dest" init -q . && git_q "$dest" add -A && git_q "$dest" commit -qm "0.x install"
}

# 利用者がよく行う変更を入れる: CLAUDE.md の追記、独自 skill、独自フックの登録、docs からの参照
customize() {
    local d="$1"
    printf '\n## local rules\n- local edit marker\n' >> "$d/CLAUDE.md"
    mkdir -p "$d/.claude/skills/my-skill"
    printf -- '---\nname: my-skill\ndescription: custom skill\n---\n\nSee `.claude/quality-gates.md` and `.claude/hooks/my-hook.sh`.\n' > "$d/.claude/skills/my-skill/SKILL.md"
    printf '#!/usr/bin/env bash\necho "$CLAUDE_PROJECT_DIR"/.claude/hooks/my-hook.sh\n' > "$d/.claude/hooks/my-hook.sh"
    jq '.hooks.PreToolUse += [{"matcher":"Bash","hooks":[{"type":"command","command":"\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/my-hook.sh","timeout":5}]}]' \
        "$d/.claude/settings.json" > "$d/.claude/settings.json.tmp" && mv "$d/.claude/settings.json.tmp" "$d/.claude/settings.json"
    printf '\n- see `.claude/rules/git-conventions.md`\n' >> "$d/docs/development-patterns.md"
    # ホーム側の Claude Code 設定への言及(プロジェクトの移動対象ではない)
    printf '\n- personal skills live in `~/.claude/skills/` and $HOME/.claude/rules/\n' >> "$d/docs/development-patterns.md"
    # rules のサブディレクトリ、空にしたフック、統合途中の .blueprint-new、自動修正の対象外から旧パスを呼ぶファイル
    mkdir -p "$d/.claude/rules/frontend"
    printf '# react rule\n' > "$d/.claude/rules/frontend/react.md"
    : > "$d/.claude/hooks/console-warn.sh"
    printf 'half merged\n' > "$d/CLAUDE.md.blueprint-new"
    printf '{"scripts":{"stats":"bash .claude/scripts/harness-stats.sh"}}\n' > "$d/package.json"
    printf 'local-secret.txt' >> "$d/.gitignore"            # 末尾に改行なし
    git_q "$d" add -A && git_q "$d" commit -qm "local customizations"
}

for MIRROR in project-blueprint project-blueprint-en; do
    SRC="$REPO/$MIRROR"
    [[ -f "$SRC/migrate.sh" ]] || continue
    OTHER="project-blueprint-en"; [[ "$MIRROR" == *-en ]] && OTHER="project-blueprint"
    echo "== $MIRROR =="
    T="$ROOT/$MIRROR"
    mkdir -p "$T"

    # ── A. 0.4.0(manifest なし)+ 利用者の変更 ──────────────────────────
    A="$T/a"
    make_legacy "$ROOT/t040" "$MIRROR" "$A" && customize "$A"
    expect_exists "fixture: 0.4.0 を当時の setup.sh で導入できる" "$A/.claude/hooks/safety-check.sh"
    expect_missing "fixture: 0.4.0 は manifest を持たない" "$A/.claude/blueprint-manifest.txt"

    printf 'dirty\n' > "$A/untracked.txt"
    OUT="$(bash "$SRC/migrate.sh" "$A" 2>&1)"
    expect_eq "未コミットの変更があれば止まる(exit 1)" 1 "$?"
    expect_missing "未コミットで止まったときは何も動かさない" "$A/.agents"
    rm -f "$A/untracked.txt"

    OUT="$(bash "$SRC/migrate.sh" "$A" --dry-run 2>&1 | strip_color)"
    expect_eq "dry-run: exit 0" 0 "$?"
    expect_eq "dry-run: プロジェクトを変更しない(git status が空)" "" "$(git -C "$A" status --porcelain)"
    expect_missing "dry-run: .agents/ を作らない" "$A/.agents"
    expect_missing "dry-run: バックアップを残さない" "$A/.blueprint-migrate-backup"
    expect_contains "dry-run: 競合するファイルを事前に示す" "conflict CLAUDE.md" "$OUT"
    expect_contains "dry-run: 出力のパスは本物のプロジェクトを指す" "$A" "$OUT"

    bash "$SRC/migrate.sh" "$A" --rollback --dry-run >/dev/null 2>&1
    expect_eq "--rollback と --dry-run の併用は exit 1(黙って実行しない)" 1 "$?"

    OUT="$(bash "$SRC/$OTHER/../$OTHER/migrate.sh" "$A" 2>&1 | strip_color)"
    expect_contains "もう一方のミラーの migrate.sh は導入元の違いを検出して止まる" "$MIRROR" "$OUT"
    expect_missing "ミラー違いで止まったときは何も動かさない" "$A/.agents"

    OUT="$(bash "$SRC/migrate.sh" "$A" 2>&1 | strip_color)"
    expect_eq "migrate: exit 0" 0 "$?"
    expect_contains "migrate: 未変更の判定に git 履歴を使う" "git" "$(printf '%s' "$OUT" | grep -iE '未変更の判定|Untouched-file detection')"
    # 配置
    expect_exists "migrate: skill を .agents/ へ移す" "$A/.agents/skills/prd/SKILL.md"
    expect_exists "migrate: フックを .agents/ へ移す" "$A/.agents/hooks/safety-check.sh"
    expect_exists "migrate: 共有文書を .agents/ へ移す" "$A/.agents/quality-gates.md"
    expect_missing "migrate: .claude/hooks/ を残さない" "$A/.claude/hooks"
    expect_missing "migrate: .claude/quality-gates.md を残さない" "$A/.claude/quality-gates.md"
    expect_link "migrate: .claude/skills/<name> は .agents/ へのリンクになる" "$A/.claude/skills/prd"
    expect_link "migrate: .claude/rules/*.md もリンクになる" "$A/.claude/rules/git-conventions.md"
    expect_exists "migrate: Claude Code 専用のものは .claude/ に残す" "$A/.claude/agents/verifier.md"
    expect_exists "migrate: Codex 用アダプタを足す(既定 = both)" "$A/.codex/config.toml"
    expect_exists "migrate: Codex アダプタ本体を足す" "$A/.agents/hooks/lib/codex-adapter.sh"
    # 利用者の変更
    expect_exists "migrate: 独自 skill も一緒に移す" "$A/.agents/skills/my-skill/SKILL.md"
    expect_link "migrate: 独自 skill もリンクする" "$A/.claude/skills/my-skill"
    expect_contains "migrate: 独自 skill の中の参照を書き換える" '`.agents/quality-gates.md` and `.agents/hooks/my-hook.sh`' "$(cat "$A/.agents/skills/my-skill/SKILL.md")"
    expect_exists "migrate: 独自フックも一緒に移す" "$A/.agents/hooks/my-hook.sh"
    expect_contains "migrate: settings.json の独自フック登録を新しいパスへ直す" '/.agents/hooks/my-hook.sh' "$(jq -r '.hooks.PreToolUse[].hooks[].command' "$A/.claude/settings.json")"
    expect_eq "migrate: settings.json に旧パスのフック登録を残さない" 0 "$(grep -c '\.claude/hooks/' "$A/.claude/settings.json")"
    expect_eq "migrate: 手で変えた CLAUDE.md を上書きしない" 1 "$(grep -c 'local edit marker' "$A/CLAUDE.md")"
    expect_exists "migrate: 変更ありのファイルは新版を横に置く" "$A/CLAUDE.md.blueprint-new"
    expect_eq "migrate: 横に置いた新版は 1.0 のテンプレート" "$(sha "$SRC/.claude/CLAUDE.md")" "$(sha "$A/CLAUDE.md.blueprint-new")"
    expect_exists "migrate: 変更ありの settings.json にも新版を横に置く" "$A/.claude/settings.json.blueprint-new"
    expect_eq "migrate: docs/ の中の参照も書き換える" 1 "$(grep -c 'see `.agents/rules/git-conventions.md`' "$A/docs/development-patterns.md")"
    # 独立レビューの指摘への回帰テスト
    expect_eq "migrate: ホーム側(~/.claude/skills/)の参照は書き換えない" 1 "$(grep -c '`~/.claude/skills/` and \$HOME/.claude/rules/' "$A/docs/development-patterns.md")"
    expect_exists "migrate: rules のサブディレクトリも移す" "$A/.agents/rules/frontend/react.md"
    expect_link "migrate: rules のサブディレクトリも Claude Code へつなぐ" "$A/.claude/rules/frontend"
    [[ ! -s "$A/.agents/hooks/console-warn.sh" ]] && ok "migrate: 空にしたフックを「未変更」と誤認して上書きしない" || ng "migrate: 空にしたフックを「未変更」と誤認して上書きしない" "still empty" "$(head -c 80 "$A/.agents/hooks/console-warn.sh")"
    expect_exists "migrate: 空にしたフックには新版を横に置く" "$A/.agents/hooks/console-warn.sh.blueprint-new"
    expect_eq "migrate: 統合途中だった .blueprint-new を .old に退避する" "half merged" "$(cat "$A/CLAUDE.md.blueprint-new.old" 2>/dev/null)"
    expect_contains "migrate: 自動修正の対象外に残った参照を知らせる" "package.json" "$OUT"
    grep -qxF 'local-secret.txt' "$A/.gitignore" && ok "migrate: 末尾に改行の無い .gitignore の最終行を壊さない" || ng "migrate: 末尾に改行の無い .gitignore の最終行を壊さない" "a line 'local-secret.txt'" "$(tail -4 "$A/.gitignore")"
    grep -qxF '.blueprint-migrate-backup/' "$A/.gitignore" && ok "migrate: バックアップの除外は独立した行になる" || ng "migrate: バックアップの除外は独立した行になる" "a line" "$(tail -4 "$A/.gitignore")"

    # 未変更ファイルは 1.0 の内容になる
    expect_eq "migrate: 未変更のフックは 1.0 の内容に置き換わる" "$(sha "$SRC/.agents/hooks/protect-files.sh")" "$(sha "$A/.agents/hooks/protect-files.sh")"
    expect_eq "migrate: 未変更の skill は 1.0 の内容に置き換わる" "$(sha "$SRC/.agents/skills/prd/SKILL.md")" "$(sha "$A/.agents/skills/prd/SKILL.md")"
    expect_eq "migrate: 未変更の AGENTS.md は 1.0 の内容に置き換わる" "$(sha "$SRC/AGENTS.md")" "$(sha "$A/AGENTS.md")"
    # 整合
    expect_eq "migrate: constitution.md とハッシュが一致したまま" "$(sha "$A/constitution.md")" "$(tr -d '[:space:]' < "$A/.agents/.constitution.sha256")"
    # 除外しているのは、1.0 のテンプレート自身が .claude/skills/ と .claude/rules/(リンクの置き場)を説明・点検しているファイル
    STALE="$(grep -rIE '\.claude/(skills|hooks|rules|scripts|learnings|tasks)/|\.claude/(guardrails|quality-gates|pitfalls)\.md' \
        "$A/.agents" "$A/.claude" "$A/CLAUDE.md" "$A/AGENTS.md" "$A/project-config.md" "$A/docs" 2>/dev/null \
        | grep -v '~/\.claude/' | cut -d: -f1 | sort -u \
        | grep -vE '\.blueprint-new$|rules/README\.md$|guardrails\.md$|pitfalls\.md$|harness-authoring\.md$|/harness-refine/|hooks/session-start\.sh$' | head -5)"
    expect_eq "migrate: 移したパスへの古い参照を残さない" "" "$STALE"
    expect_eq "migrate: manifest は新形式" "both" "$(field "$A" agent)"
    expect_eq "migrate: manifest の profile を推定(full)" "full" "$(field "$A" profile)"
    expect_missing "migrate: 旧 manifest の場所に何も置かない" "$A/.claude/blueprint-manifest.txt"
    grep -qxF '.blueprint-migrate-backup/' "$A/.gitignore" && ok "migrate: バックアップを .gitignore に入れる" || ng "migrate: バックアップを .gitignore に入れる" ".blueprint-migrate-backup/" "missing"
    expect_exists "migrate: 移行前の .claude/ を退避する" "$A/.blueprint-migrate-backup/.claude/hooks/safety-check.sh"
    # 移行後のフックが新しいパスで動く
    printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push origin main --force"}}' | CLAUDE_PROJECT_DIR="$A" bash "$A/.agents/hooks/safety-check.sh" >/dev/null 2>&1
    expect_eq "migrate: 移行後のフックが新しいパスで動く(force push をブロック)" 2 "$?"
    REG="$(jq -r '.hooks.PreToolUse[].hooks[].command' "$A/.claude/settings.json" | sed 's/"\$CLAUDE_PROJECT_DIR"/./' | awk '{print $1}')"
    MISSING=""
    for cmd in $REG; do [[ -f "$A/$cmd" ]] || MISSING="$MISSING $cmd"; done
    expect_eq "migrate: settings.json が登録するフックはすべて実在する" "" "$MISSING"

    # 冪等性
    OUT="$(bash "$SRC/migrate.sh" "$A" 2>&1 | strip_color)"
    expect_eq "再実行: exit 0(移行済みと報告)" 0 "$?"
    expect_contains "再実行: 以後は setup.sh --upgrade を案内" "setup.sh --upgrade" "$OUT"
    OUT="$(bash "$SRC/setup.sh" "$A" --upgrade 2>&1 | strip_color)"
    if [[ "$OUT" == *"更新 0 /"* || "$OUT" == *"updated 0 /"* ]]; then ok "移行後の --upgrade は更新 0(移行が 1.0 の内容まで揃えている)"; else ng "移行後の --upgrade は更新 0" "updated 0" "$OUT"; fi

    # 取り消し
    OUT="$(bash "$SRC/migrate.sh" "$A" --rollback 2>&1)"
    expect_eq "rollback: exit 0" 0 "$?"
    expect_eq "rollback: 移行前と完全に同じ状態へ戻る(git status が空)" "" "$(git -C "$A" status --porcelain)"
    expect_missing "rollback: .agents/ を取り除く" "$A/.agents"
    expect_missing "rollback: .codex/ を取り除く" "$A/.codex"
    expect_missing "rollback: 移行が横に置いた新版を取り除く" "$A/.claude/settings.json.blueprint-new"
    expect_missing "rollback: バックアップを片付ける" "$A/.blueprint-migrate-backup"
    expect_exists "rollback: フックが元の場所に戻る" "$A/.claude/hooks/my-hook.sh"
    expect_eq "rollback: 統合途中だった .blueprint-new を元の内容に戻す" "half merged" "$(cat "$A/CLAUDE.md.blueprint-new" 2>/dev/null)"
    expect_missing "rollback: .old を残さない" "$A/CLAUDE.md.blueprint-new.old"
    OUT="$(bash "$SRC/migrate.sh" "$A" --rollback 2>&1)"
    expect_eq "rollback: バックアップが無ければ exit 1" 1 "$?"

    # --agent claude: Codex 用アダプタを足さない
    OUT="$(bash "$SRC/migrate.sh" "$A" --agent claude 2>&1)"
    expect_eq "migrate(--agent claude): exit 0" 0 "$?"
    expect_missing "migrate(--agent claude): .codex/ を作らない" "$A/.codex"
    expect_eq "migrate(--agent claude): manifest の agent" "claude" "$(field "$A" agent)"
    expect_link "migrate(--agent claude): skill のリンクは作る" "$A/.claude/skills/plan"

    # ── B. 1.0 直前(manifest v1 あり)の minimal 導入 ───────────────────
    B="$T/b"
    make_legacy "$ROOT/tv1" "$MIRROR" "$B" --profile minimal
    expect_exists "fixture: 1.0 直前は manifest v1 を書く" "$B/.claude/blueprint-manifest.txt"
    printf '\n# local skill edit\n' >> "$B/.claude/skills/plan/SKILL.md"
    git_q "$B" add -A && git_q "$B" commit -qm "edit a skill"
    OLD_PLAN_HASH="$(awk '$1 !~ /^#/ && $2 == ".claude/skills/plan/SKILL.md" {print $1; exit}' "$B/.claude/blueprint-manifest.txt")"
    OUT="$(bash "$SRC/migrate.sh" "$B" 2>&1 | strip_color)"
    expect_eq "migrate(manifest v1): exit 0" 0 "$?"
    expect_contains "migrate(manifest v1): 未変更の判定に manifest を使う" "blueprint-manifest.txt" "$(printf '%s' "$OUT" | grep -iE '未変更の判定|Untouched-file detection')"
    expect_eq "migrate(manifest v1): profile を引き継ぐ" "minimal" "$(field "$B" profile)"
    expect_eq "migrate(minimal): skill は 5 本のまま" 5 "$(find "$B/.agents/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
    expect_missing "migrate(minimal): teams/ を持ち込まない" "$B/.claude/teams"
    expect_missing "migrate(minimal): 剪定済みのフックを持ち込まない" "$B/.agents/hooks/session-start.sh"
    expect_eq "migrate(minimal): Codex のフック登録も minimal 版" "$(sha "$SRC/.codex/hooks.minimal.json")" "$(sha "$B/.codex/hooks.json")"
    expect_eq "migrate(manifest v1): 手で変えた skill を上書きしない" 1 "$(grep -c 'local skill edit' "$B/.agents/skills/plan/SKILL.md")"
    expect_exists "migrate(manifest v1): 変更ありの skill に新版を横に置く" "$B/.agents/skills/plan/SKILL.md.blueprint-new"
    expect_eq "migrate(manifest v1): 変更ありのファイルは導入時のハッシュを新しいパスへ引き継ぐ" "$OLD_PLAN_HASH" "$(awk '$1 !~ /^#/ && $2 == ".agents/skills/plan/SKILL.md" {print $1; exit}' "$B/.agents/blueprint-manifest.txt")"

    # ── C. テンプレートに git 履歴が無い(zip で取得した等)─────────────────
    NOHIST="$T/nohist"
    mkdir -p "$NOHIST"
    cp -R "$SRC" "$NOHIST/$MIRROR"
    cp "$REPO/VERSION" "$NOHIST/VERSION"
    Cdir="$T/c"
    make_legacy "$ROOT/t040" "$MIRROR" "$Cdir"
    OLD_HOOK_SHA="$(sha "$Cdir/.claude/hooks/session-start.sh")"
    OUT="$(bash "$NOHIST/$MIRROR/migrate.sh" "$Cdir" 2>&1 | strip_color)"
    expect_eq "migrate(履歴なし): exit 0" 0 "$?"
    expect_contains "migrate(履歴なし): 判定できないことを警告" "--assume-pristine" "$OUT"
    expect_exists "migrate(履歴なし): 上書きせず新版を横に置く" "$Cdir/.agents/hooks/session-start.sh.blueprint-new"
    expect_eq "migrate(履歴なし): 元のファイルは内容を保つ(参照の書き換えだけ)" 0 "$(grep -c 'BLUEPRINT_AGENT' "$Cdir/.agents/hooks/session-start.sh")"
    [[ "$(sha "$Cdir/.agents/hooks/session-start.sh")" != "$(sha "$SRC/.agents/hooks/session-start.sh")" && -n "$OLD_HOOK_SHA" ]] && ok "migrate(履歴なし): 1.0 の内容で上書きしていない" || ng "migrate(履歴なし): 1.0 の内容で上書きしていない" "differs from 1.0" "equal"
    bash "$NOHIST/$MIRROR/migrate.sh" "$Cdir" --rollback >/dev/null 2>&1
    OUT="$(bash "$NOHIST/$MIRROR/migrate.sh" "$Cdir" --assume-pristine 2>&1 | strip_color)"
    expect_eq "migrate(--assume-pristine): exit 0" 0 "$?"
    expect_eq "migrate(--assume-pristine): すべて 1.0 の内容で上書きする" "$(sha "$SRC/.agents/hooks/session-start.sh")" "$(sha "$Cdir/.agents/hooks/session-start.sh")"
    expect_missing "migrate(--assume-pristine): 競合を作らない" "$Cdir/.agents/hooks/session-start.sh.blueprint-new"
    expect_exists "migrate(--assume-pristine): 元の版はバックアップに残る" "$Cdir/.blueprint-migrate-backup/.claude/hooks/session-start.sh"

    # ── D. 途中で失敗したら自動で元に戻す ───────────────────────────────
    BROKEN="$T/broken"
    mkdir -p "$BROKEN"
    cp -R "$SRC" "$BROKEN/$MIRROR"
    cp "$REPO/VERSION" "$BROKEN/VERSION"
    printf '#!/usr/bin/env bash\necho "simulated failure" >&2\nexit 7\n' > "$BROKEN/$MIRROR/setup.sh"
    D="$T/d"
    make_legacy "$ROOT/t040" "$MIRROR" "$D"
    OUT="$(bash "$BROKEN/$MIRROR/migrate.sh" "$D" --assume-pristine 2>&1)"
    expect_eq "失敗時: exit 1" 1 "$?"
    expect_eq "失敗時: 自動で移行前の状態へ戻る(git status が空)" "" "$(git -C "$D" status --porcelain)"
    expect_missing "失敗時: .agents/ を残さない" "$D/.agents"
    expect_missing "失敗時: バックアップを片付ける" "$D/.blueprint-migrate-backup"
    expect_exists "失敗時: フックは元の場所にある" "$D/.claude/hooks/safety-check.sh"

    # ── E. 前回の移行が途中で止まっている ───────────────────────────────
    mkdir -p "$D/.blueprint-migrate-backup"
    OUT="$(bash "$SRC/migrate.sh" "$D" 2>&1 | strip_color)"
    expect_eq "中断状態: exit 1" 1 "$?"
    expect_contains "中断状態: --rollback を案内" "--rollback" "$OUT"
    rmdir "$D/.blueprint-migrate-backup"

    # ── F. 対象外のプロジェクト ─────────────────────────────────────────
    mkdir -p "$T/plain"
    OUT="$(bash "$SRC/migrate.sh" "$T/plain" 2>&1 | strip_color)"
    expect_eq "ブループリント未導入: exit 1" 1 "$?"
    expect_contains "ブループリント未導入: setup.sh を案内" "setup.sh" "$OUT"
    bash "$SRC/setup.sh" "$T/fresh" >/dev/null 2>&1
    OUT="$(bash "$SRC/migrate.sh" "$T/fresh" 2>&1 | strip_color)"
    expect_eq "1.0 で導入済み: exit 0(何もしない)" 0 "$?"
    expect_missing "1.0 で導入済み: バックアップを作らない" "$T/fresh/.blueprint-migrate-backup"

    # ── H. .claude がシンボリックリンク(dotfiles 管理など)──────────────────
    Hd="$T/h"
    make_legacy "$ROOT/t040" "$MIRROR" "$Hd"
    mv "$Hd/.claude" "$T/h-real-claude"
    ln -s "$T/h-real-claude" "$Hd/.claude"
    OUT="$(bash "$SRC/migrate.sh" "$Hd" --allow-dirty 2>&1 | strip_color)"
    expect_eq ".claude がシンボリックリンク: exit 1" 1 "$?"
    expect_exists ".claude がシンボリックリンク: リンク先の中身を動かさない" "$T/h-real-claude/skills/prd/SKILL.md"
    expect_missing ".claude がシンボリックリンク: .agents/ を作らない" "$Hd/.agents"
    OUT="$(bash "$SRC/migrate.sh" "$Hd" --dry-run 2>&1 | strip_color)"
    expect_exists ".claude がシンボリックリンク: --dry-run でもリンク先の中身を動かさない" "$T/h-real-claude/hooks/safety-check.sh"

    # ── G. 移動先に同名のファイルが既にある(利用者が Codex 用に置いていた)──
    G="$T/g"
    make_legacy "$ROOT/t040" "$MIRROR" "$G"
    mkdir -p "$G/.agents/skills/prd"
    printf 'my own codex skill\n' > "$G/.agents/skills/prd/SKILL.md"
    git_q "$G" add -A && git_q "$G" commit -qm "own .agents skill"
    OUT="$(bash "$SRC/migrate.sh" "$G" 2>&1 | strip_color)"
    expect_eq "移動先が既にある: exit 0" 0 "$?"
    expect_eq "移動先が既にある: 利用者のファイルを上書きしない" "my own codex skill" "$(cat "$G/.agents/skills/prd/SKILL.md")"
    expect_contains "移動先が既にある: 動かさなかったファイルを報告" ".claude/skills/prd/SKILL.md → .agents/skills/prd/SKILL.md" "$OUT"
    expect_exists "移動先が既にある: 元のファイルは .claude/ 側に残す" "$G/.claude/skills/prd/SKILL.md"
    expect_exists "移動先が既にある: 1.0 の版を横に置く" "$G/.agents/skills/prd/SKILL.md.blueprint-new"
done

echo
echo "結果: PASS $PASS / FAIL $FAIL"
if (( FAIL > 0 )); then
    echo "migrate.sh の機能テストに失敗があります。"
    exit 1
fi
echo "migrate.sh の機能テスト全件 PASS。"
exit 0
