#!/usr/bin/env bash
# ==============================================================================
# test_setup.sh — setup.sh の機能テスト(日英ミラー両方)
#
# 導入(profile 別の剪定・配置・manifest)と --upgrade(未変更ファイルの更新、手で変えた
# ファイルの競合、テンプレートに増えたファイルの追加、project-config.md 不干渉、冪等性、
# manifest 不在のエラー)を仮ディレクトリで検証する。
# 1.0 の配置: 共通の核 .agents/ + アダプタ .claude/ / .codex/(--agent)、.claude/skills と
# .claude/rules のリンク(--links / --relink)、0.x の配置を migrate.sh へ誘導するエラー。
#
#   bash scripts/validate-harness.sh --setup   # ラッパー経由
#   bash scripts/test_setup.sh                 # 直接
#
# 終了コード: 0 = 全件 PASS / 1 = FAIL あり
# ==============================================================================

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

ok() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
ng() { echo "  [FAIL] $1"; echo "        期待: $2"; echo "        実際: ${3:0:240}"; FAIL=$((FAIL + 1)); }
expect_eq()       { [[ "$3" == "$2" ]] && ok "$1" || ng "$1" "$2" "$3"; }
expect_exists()   { [[ -e "$2" ]] && ok "$1" || ng "$1" "exists: $2" "missing"; }
expect_missing()  { [[ ! -e "$2" ]] && ok "$1" || ng "$1" "missing: $2" "exists"; }
expect_contains() { [[ "$3" == *"$2"* ]] && ok "$1" || ng "$1" "contains '$2'" "$3"; }

manifest_field() { sed -n "s/^# $2: //p" "$1/.agents/blueprint-manifest.txt" | head -1; }
manifest_hash()  { awk -v p="$2" '$1 !~ /^#/ && $2 == p {print $1; exit}' "$1/.agents/blueprint-manifest.txt"; }
sha() { shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1 || sha256sum "$1" | cut -d' ' -f1; }

for MIRROR in project-blueprint project-blueprint-en; do
    SRC="$REPO/$MIRROR"
    [[ -f "$SRC/setup.sh" ]] || continue
    echo "== $MIRROR =="
    T="$(mktemp -d)"

    # ── 導入(full)────────────────────────────────────────────────
    bash "$SRC/setup.sh" "$T/full" >/dev/null 2>&1
    expect_eq "install(full): exit 0" 0 "$?"
    expect_exists "install(full): CLAUDE.md がルートに置かれる" "$T/full/CLAUDE.md"
    expect_missing "install(full): .claude/CLAUDE.md は残らない" "$T/full/.claude/CLAUDE.md"
    expect_exists "install(full): AGENTS.md" "$T/full/AGENTS.md"
    expect_exists "install(full): teams/ が同梱される" "$T/full/.claude/teams"
    expect_exists "install(full): manifest が書かれる" "$T/full/.agents/blueprint-manifest.txt"
    expect_eq "install(full): manifest の profile" "full" "$(manifest_field "$T/full" profile)"
    expect_eq "install(full): manifest の version が VERSION と一致" "$(tr -d '[:space:]' < "$REPO/VERSION")" "$(manifest_field "$T/full" version)"
    expect_eq "install(full): manifest の CLAUDE.md ハッシュはテンプレートの .claude/CLAUDE.md" "$(sha "$SRC/.claude/CLAUDE.md")" "$(manifest_hash "$T/full" CLAUDE.md)"
    expect_eq "install(full): manifest に settings.local.json を含めない" "" "$(manifest_hash "$T/full" .claude/settings.local.json)"
    expect_eq "install(full): manifest に docs/ を含めない" "" "$(awk '$1 !~ /^#/ && $2 ~ /^docs\// {print; exit}' "$T/full/.agents/blueprint-manifest.txt")"
    N_SKILLS="$(find "$T/full/.agents/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
    expect_eq "install(full): skill 数がテンプレートと一致" "$(find "$SRC/.agents/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" "$N_SKILLS"
    [[ -x "$T/full/.agents/scripts/harness-stats.sh" ]] && ok "install(full): scripts/*.sh に実行権限" || ng "install(full): scripts/*.sh に実行権限" "executable" "not executable"

    # ── 導入(minimal)─────────────────────────────────────────────
    bash "$SRC/setup.sh" "$T/min" --profile minimal >/dev/null 2>&1
    expect_eq "install(minimal): exit 0" 0 "$?"
    expect_eq "install(minimal): skill は 5 本" 5 "$(find "$T/min/.agents/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
    expect_missing "install(minimal): teams/ は無い" "$T/min/.claude/teams"
    expect_eq "install(minimal): settings.json は settings.minimal.json 由来" "$(sha "$SRC/.claude/settings.minimal.json")" "$(sha "$T/min/.claude/settings.json")"
    expect_eq "install(minimal): manifest の settings.json ハッシュも minimal 版" "$(sha "$SRC/.claude/settings.minimal.json")" "$(manifest_hash "$T/min" .claude/settings.json)"
    expect_eq "install(minimal): manifest に剪定済み skill を含めない" "" "$(awk '$1 !~ /^#/ && $2 ~ /^\.claude\/skills\/security-scan\// {print; exit}' "$T/min/.agents/blueprint-manifest.txt")"

    # ── --upgrade ───────────────────────────────────────────────────
    # 新しいテンプレートを作る: skill を更新、CLAUDE.md を更新、hook を追加、project-config.md を変更
    cp -r "$SRC" "$T/tmpl"
    printf '\n# newer template\n' >> "$T/tmpl/.agents/skills/plan/SKILL.md"
    printf '\n# newer guide\n' >> "$T/tmpl/.claude/CLAUDE.md"
    printf '#!/usr/bin/env bash\necho hi\n' > "$T/tmpl/.agents/hooks/new-hook.sh"
    printf '\n<!-- template changed -->\n' >> "$T/tmpl/project-config.md"
    echo "9.9.9" > "$T/VERSION"
    # 利用者側の変更: CLAUDE.md と project-config.md を編集、ある hook を削除
    printf '\n# local edit\n' >> "$T/full/CLAUDE.md"
    printf '\n| プロジェクト名 | my-app |\n' >> "$T/full/project-config.md"
    rm -f "$T/full/.agents/hooks/console-warn.sh"

    OUT="$(bash "$T/tmpl/setup.sh" "$T/full" --upgrade --dry-run 2>&1)"
    expect_eq "upgrade(--dry-run): exit 0" 0 "$?"
    expect_contains "upgrade(--dry-run): 更新対象を列挙" "update   .agents/skills/plan/SKILL.md" "$OUT"
    expect_eq "upgrade(--dry-run): ファイルを変えない" "$(sha "$SRC/.agents/skills/plan/SKILL.md")" "$(sha "$T/full/.agents/skills/plan/SKILL.md")"
    expect_missing "upgrade(--dry-run): .blueprint-new を作らない" "$T/full/CLAUDE.md.blueprint-new"

    OUT="$(bash "$T/tmpl/setup.sh" "$T/full" --upgrade 2>&1)"
    expect_eq "upgrade: exit 0" 0 "$?"
    expect_eq "upgrade: 未変更の skill は新版で上書き" "$(sha "$T/tmpl/.agents/skills/plan/SKILL.md")" "$(sha "$T/full/.agents/skills/plan/SKILL.md")"
    expect_exists "upgrade: テンプレートに増えた hook を追加" "$T/full/.agents/hooks/new-hook.sh"
    [[ -x "$T/full/.agents/hooks/new-hook.sh" ]] && ok "upgrade: 追加した hook に実行権限" || ng "upgrade: 追加した hook に実行権限" "executable" "not executable"
    expect_eq "upgrade: 手で変えた CLAUDE.md は上書きしない" 1 "$(grep -c 'local edit' "$T/full/CLAUDE.md")"
    expect_exists "upgrade: 競合は CLAUDE.md.blueprint-new を横に置く" "$T/full/CLAUDE.md.blueprint-new"
    expect_eq "upgrade: .blueprint-new の中身は新テンプレート" "$(sha "$T/tmpl/.claude/CLAUDE.md")" "$(sha "$T/full/CLAUDE.md.blueprint-new")"
    expect_contains "upgrade: 競合を報告" "conflict CLAUDE.md" "$OUT"
    expect_eq "upgrade: project-config.md は触らない" 1 "$(grep -c 'my-app' "$T/full/project-config.md")"
    expect_eq "upgrade: project-config.md にテンプレート側の変更を混ぜない" 0 "$(grep -c 'template changed' "$T/full/project-config.md")"
    expect_contains "upgrade: project-config.md の変更を警告" "project-config.md" "$OUT"
    expect_missing "upgrade: ローカルで消した hook は復活させない" "$T/full/.agents/hooks/console-warn.sh"
    expect_contains "upgrade: ローカル削除をスキップとして報告" "skip     .agents/hooks/console-warn.sh" "$OUT"
    expect_eq "upgrade: manifest の version が新テンプレート" "9.9.9" "$(manifest_field "$T/full" version)"
    expect_eq "upgrade: 競合ファイルの manifest ハッシュは旧版のまま(次回も競合として扱う)" "$(sha "$SRC/.claude/CLAUDE.md")" "$(manifest_hash "$T/full" CLAUDE.md)"
    expect_eq "upgrade: 更新した skill の manifest ハッシュは新版" "$(sha "$T/tmpl/.agents/skills/plan/SKILL.md")" "$(manifest_hash "$T/full" .agents/skills/plan/SKILL.md)"
    expect_missing "upgrade: docs/ を触らない(stub のまま新規ファイル無し)" "$T/full/docs/.blueprint-new"

    OUT="$(bash "$T/tmpl/setup.sh" "$T/full" --upgrade 2>&1)"
    if [[ "$OUT" == *"更新 0 /"* || "$OUT" == *"updated 0 /"* ]]; then ok "upgrade(2 回目): 更新 0 で冪等"; else ng "upgrade(2 回目): 更新 0 で冪等" "updated 0" "$OUT"; fi
    expect_contains "upgrade(2 回目): 競合は再報告される" "conflict CLAUDE.md" "$OUT"

    # ── minimal プロファイルの upgrade は剪定を維持する ──────────────
    OUT="$(bash "$T/tmpl/setup.sh" "$T/min" --upgrade 2>&1)"
    expect_eq "upgrade(minimal): exit 0" 0 "$?"
    expect_missing "upgrade(minimal): 剪定済み skill を持ち込まない" "$T/min/.agents/skills/security-scan"
    expect_missing "upgrade(minimal): teams/ を持ち込まない" "$T/min/.claude/teams"
    expect_eq "upgrade(minimal): settings.json は minimal 版のまま" "$(sha "$T/tmpl/.claude/settings.minimal.json")" "$(sha "$T/min/.claude/settings.json")"

    # ── manifest が無いと失敗する ──────────────────────────────────
    mkdir -p "$T/bare/.claude"
    bash "$SRC/setup.sh" "$T/bare" --upgrade >/dev/null 2>&1
    expect_eq "upgrade: manifest 不在は exit 1" 1 "$?"
    expect_missing "upgrade: manifest 不在では何も配置しない" "$T/bare/CLAUDE.md"

    # ── エージェントの選択(--agent)と共通の核 ─────────────────────
    expect_exists "install(既定 = both): Codex 用アダプタ config.toml" "$T/full/.codex/config.toml"
    expect_exists "install(both): Codex 用フック登録" "$T/full/.codex/hooks.json"
    expect_exists "install(both): Codex 用エージェント" "$T/full/.codex/agents/verifier.toml"
    expect_exists "install(both): Codex アダプタ本体" "$T/full/.agents/hooks/lib/codex-adapter.sh"
    [[ -x "$T/full/.agents/hooks/lib/codex-adapter.sh" ]] && ok "install(both): アダプタに実行権限" || ng "install(both): アダプタに実行権限" "executable" "not executable"
    expect_eq "install(both): manifest の agent" "both" "$(manifest_field "$T/full" agent)"
    expect_eq "install(both): manifest の links" "symlink" "$(manifest_field "$T/full" links)"
    [[ -L "$T/full/.claude/skills/prd" ]] && ok "install(both): .claude/skills/<name> は .agents/ へのリンク" || ng "install(both): .claude/skills/<name> は .agents/ へのリンク" "symlink" "not a symlink"
    expect_eq "install(both): リンク先は相対パス" "../../.agents/skills/prd" "$(readlink "$T/full/.claude/skills/prd")"
    expect_exists "install(both): リンク越しに SKILL.md が読める" "$T/full/.claude/skills/prd/SKILL.md"
    [[ -L "$T/full/.claude/rules/git-conventions.md" ]] && ok "install(both): .claude/rules/*.md もリンク" || ng "install(both): .claude/rules/*.md もリンク" "symlink" "not a symlink"
    expect_missing "install(both): rules の README.md はつながない(常時 load を避ける)" "$T/full/.claude/rules/README.md"
    expect_missing "install(both): .example のルールはつながない" "$T/full/.claude/rules/language-python.md.example"
    expect_missing "install(both): .claude/ にフックの実体を置かない" "$T/full/.claude/hooks"
    expect_eq "install(both): manifest にリンクを含めない" "" "$(awk '$1 !~ /^#/ && $2 ~ /^\.claude\/(skills|rules)\// {print; exit}' "$T/full/.agents/blueprint-manifest.txt")"

    bash "$SRC/setup.sh" "$T/cl" --agent claude >/dev/null 2>&1
    expect_eq "install(claude): exit 0" 0 "$?"
    expect_missing "install(claude): .codex/ は無い" "$T/cl/.codex"
    expect_exists "install(claude): CLAUDE.md" "$T/cl/CLAUDE.md"
    expect_eq "install(claude): manifest に .codex/ を含めない" "" "$(awk '$1 !~ /^#/ && $2 ~ /^\.codex\// {print; exit}' "$T/cl/.agents/blueprint-manifest.txt")"

    bash "$SRC/setup.sh" "$T/cx" --agent codex --profile minimal >/dev/null 2>&1
    expect_eq "install(codex, minimal): exit 0" 0 "$?"
    expect_missing "install(codex): .claude/ は無い" "$T/cx/.claude"
    expect_missing "install(codex): CLAUDE.md は無い" "$T/cx/CLAUDE.md"
    expect_exists "install(codex): AGENTS.md" "$T/cx/AGENTS.md"
    expect_eq "install(codex, minimal): skill は 5 本" 5 "$(find "$T/cx/.agents/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
    expect_eq "install(codex, minimal): エージェントは 2 つ" 2 "$(find "$T/cx/.codex/agents" -name '*.toml' | wc -l | tr -d ' ')"
    expect_eq "install(codex, minimal): hooks.json は hooks.minimal.json 由来" "$(sha "$SRC/.codex/hooks.minimal.json")" "$(sha "$T/cx/.codex/hooks.json")"
    expect_missing "install(codex, minimal): hooks.minimal.json は残らない" "$T/cx/.codex/hooks.minimal.json"
    expect_exists "install(codex, minimal): アダプタは剪定しない" "$T/cx/.agents/hooks/lib/codex-adapter.sh"
    expect_eq "install(codex): manifest の links は none" "none" "$(manifest_field "$T/cx" links)"
    grep -q '^\.claude/' "$T/cx/.gitignore" && ng "install(codex): .gitignore に .claude/ の行を足さない" "no .claude entries" "found" || ok "install(codex): .gitignore に .claude/ の行を足さない"

    # もう一方のアダプタを後から足す
    OUT="$(bash "$SRC/setup.sh" "$T/cx" --upgrade --agent both 2>&1)"
    expect_eq "upgrade(--agent both): exit 0" 0 "$?"
    expect_exists "upgrade(--agent both): Claude Code 用アダプタを追加" "$T/cx/.claude/settings.json"
    expect_exists "upgrade(--agent both): CLAUDE.md を追加" "$T/cx/CLAUDE.md"
    expect_exists "upgrade(--agent both): settings.local.json を雛形から生成" "$T/cx/.claude/settings.local.json"
    [[ -L "$T/cx/.claude/skills/plan" ]] && ok "upgrade(--agent both): skill のリンクを作る" || ng "upgrade(--agent both): skill のリンクを作る" "symlink" "missing"
    expect_missing "upgrade(--agent both): minimal の剪定を維持" "$T/cx/.claude/skills/security-scan"
    expect_eq "upgrade(--agent both): manifest の agent を更新" "both" "$(manifest_field "$T/cx" agent)"
    grep -qxF '.claude/settings.local.json' "$T/cx/.gitignore" && ok "upgrade(--agent both): .gitignore に個人設定の除外を足す" || ng "upgrade(--agent both): .gitignore に個人設定の除外を足す" ".claude/settings.local.json" "missing"

    # ── リンク方式(--links copy / --relink)──────────────────────────
    bash "$SRC/setup.sh" "$T/cp" --agent claude --links copy >/dev/null 2>&1
    expect_eq "install(--links copy): exit 0" 0 "$?"
    [[ -d "$T/cp/.claude/skills/prd" && ! -L "$T/cp/.claude/skills/prd" ]] && ok "install(--links copy): 実体をコピーする" || ng "install(--links copy): 実体をコピーする" "real directory" "symlink or missing"
    expect_eq "install(--links copy): manifest の links" "copy" "$(manifest_field "$T/cp" links)"
    printf '\n# local copy edit\n' >> "$T/cp/.claude/skills/prd/SKILL.md"
    OUT="$(bash "$T/tmpl/setup.sh" "$T/cp" --upgrade 2>&1)"
    expect_eq "upgrade(copy): 原本と同じだったコピーは新版に作り直す" "$(sha "$T/tmpl/.agents/skills/plan/SKILL.md")" "$(sha "$T/cp/.claude/skills/plan/SKILL.md")"
    expect_eq "upgrade(copy): 手で変えたコピーは上書きしない" 1 "$(grep -c 'local copy edit' "$T/cp/.claude/skills/prd/SKILL.md")"
    if [[ "$OUT" == *".claude/skills/prd"* ]]; then ok "upgrade(copy): 触らなかったコピーを報告"; else ng "upgrade(copy): 触らなかったコピーを報告" "mentions .claude/skills/prd" "$OUT"; fi

    mkdir -p "$T/full/.agents/skills/my-skill"
    printf -- '---\nname: my-skill\ndescription: test\n---\nbody\n' > "$T/full/.agents/skills/my-skill/SKILL.md"
    printf '# my rule\n' > "$T/full/.agents/rules/my-rule.md"
    bash "$SRC/setup.sh" "$T/full" --relink >/dev/null 2>&1
    expect_eq "relink: exit 0" 0 "$?"
    [[ -L "$T/full/.claude/skills/my-skill" ]] && ok "relink: 足した skill をつなぐ" || ng "relink: 足した skill をつなぐ" "symlink" "missing"
    [[ -L "$T/full/.claude/rules/my-rule.md" ]] && ok "relink: 足したルールをつなぐ" || ng "relink: 足したルールをつなぐ" "symlink" "missing"
    rm -rf "$T/full/.agents/skills/my-skill"
    bash "$SRC/setup.sh" "$T/full" --relink >/dev/null 2>&1
    [[ ! -e "$T/full/.claude/skills/my-skill" && ! -L "$T/full/.claude/skills/my-skill" ]] && ok "relink: 原本が消えたリンクを掃除する" || ng "relink: 原本が消えたリンクを掃除する" "removed" "dangling link remains"

    # ── 既存プロジェクトへの後付け: 利用者のファイルを上書きしない ──────
    mkdir -p "$T/exist/docs"
    printf 'my config\n' > "$T/exist/project-config.md"
    printf 'my docs\n' > "$T/exist/docs/project.md"
    bash "$SRC/setup.sh" "$T/exist" >/dev/null 2>&1
    expect_eq "install(既存プロジェクト): project-config.md を保持" "my config" "$(cat "$T/exist/project-config.md")"
    expect_eq "install(既存プロジェクト): docs/ の既存ファイルを保持" "my docs" "$(cat "$T/exist/docs/project.md")"
    expect_exists "install(既存プロジェクト): 無い docs は置く" "$T/exist/docs/architecture.md"
    expect_missing "install(既存プロジェクト): docs/docs を作らない" "$T/exist/docs/docs"

    # ── 0.x の配置(すべて .claude/ 配下)は migrate.sh へ誘導する ───────
    mkdir -p "$T/legacy/.claude/hooks" "$T/legacy/.claude/skills/prd"
    : > "$T/legacy/.claude/hooks/safety-check.sh"
    : > "$T/legacy/.claude/quality-gates.md"
    OUT="$(bash "$SRC/setup.sh" "$T/legacy" 2>&1)"
    expect_eq "install(0.x の配置): exit 1" 1 "$?"
    expect_contains "install(0.x の配置): migrate.sh を案内" "migrate.sh" "$OUT"
    expect_exists "install(0.x の配置): 何も動かさない" "$T/legacy/.claude/hooks/safety-check.sh"
    expect_missing "install(0.x の配置): .claude.bak を作らない" "$T/legacy/.claude.bak"
    OUT="$(bash "$SRC/setup.sh" "$T/legacy" --upgrade 2>&1)"
    expect_eq "upgrade(0.x の配置): exit 1" 1 "$?"
    expect_contains "upgrade(0.x の配置): migrate.sh を案内" "migrate.sh" "$OUT"

    # ── 利用者のファイルを失わない(独立レビューの指摘への回帰テスト)────────
    # 既存の CLAUDE.md と、以前の .bak を上書き・削除しない
    mkdir -p "$T/own/.claude" "$T/own/.claude.bak"
    printf 'my own instructions\n' > "$T/own/CLAUDE.md"
    printf 'first backup\n' > "$T/own/.claude.bak/keep.txt"
    printf 'current claude dir\n' > "$T/own/.claude/mine.txt"
    printf '.env' > "$T/own/.gitignore"                      # 末尾に改行なし
    OUT="$(bash "$SRC/setup.sh" "$T/own" 2>&1)"
    expect_eq "install(既存 CLAUDE.md): exit 0" 0 "$?"
    expect_eq "install(既存 CLAUDE.md): 上書きしない" "my own instructions" "$(cat "$T/own/CLAUDE.md")"
    expect_eq "install(既存 CLAUDE.md): テンプレート版を横に置く" "$(sha "$SRC/.claude/CLAUDE.md")" "$(sha "$T/own/CLAUDE.md.blueprint-new")"
    expect_eq "install(既存の .bak): 以前のバックアップを消さない" "first backup" "$(cat "$T/own/.claude.bak/keep.txt")"
    expect_eq "install(既存の .bak): 今回の退避は別名に置く" "current claude dir" "$(cat "$T/own"/.claude.bak.*/mine.txt 2>/dev/null)"
    grep -qxF '.env' "$T/own/.gitignore" && ok "install(.gitignore 末尾に改行なし): 最終行を壊さない" || ng "install(.gitignore 末尾に改行なし): 最終行を壊さない" "a line '.env'" "$(head -3 "$T/own/.gitignore")"
    grep -qxF 'testreport/' "$T/own/.gitignore" && ok "install(.gitignore 末尾に改行なし): 除外は独立した行で足す" || ng "install(.gitignore 末尾に改行なし): 除外は独立した行で足す" "a line 'testreport/'" "$(head -3 "$T/own/.gitignore")"

    # 導入済みへの再導入は止める(.agents/ を作り直すと、足した skill や編集が退避先に回る)
    printf 'added by user\n' > "$T/own/.agents/skills/plan/NOTES.md"
    OUT="$(bash "$SRC/setup.sh" "$T/own" 2>&1)"
    expect_eq "install(導入済み): exit 1" 1 "$?"
    expect_contains "install(導入済み): --upgrade を案内" "--upgrade" "$OUT"
    expect_exists "install(導入済み): 利用者が足したファイルを動かさない" "$T/own/.agents/skills/plan/NOTES.md"
    expect_missing "install(導入済み): .agents.bak を作らない" "$T/own/.agents.bak"

    # --dry-run は --upgrade 専用。導入や --relink に付けても実行しない
    bash "$SRC/setup.sh" "$T/dry" --dry-run >/dev/null 2>&1
    expect_eq "install(--dry-run): exit 1(計画表示が無いので実行しない)" 1 "$?"
    expect_missing "install(--dry-run): 何も配置しない" "$T/dry/.agents"
    bash "$SRC/setup.sh" "$T/own" --relink --dry-run >/dev/null 2>&1
    expect_eq "relink(--dry-run): exit 1" 1 "$?"

    # テンプレート自身と、シンボリックリンクのハーネスディレクトリには何もしない
    OUT="$(bash "$T/tmpl/setup.sh" "$T/tmpl" 2>&1)"
    expect_eq "install(ターゲット = テンプレート): exit 1" 1 "$?"
    expect_exists "install(ターゲット = テンプレート): テンプレートを退避しない" "$T/tmpl/.agents/skills/plan/SKILL.md"
    mkdir -p "$T/realclaude" "$T/sym"
    printf 'dotfiles\n' > "$T/realclaude/mine.txt"
    ln -s "$T/realclaude" "$T/sym/.claude"
    OUT="$(bash "$SRC/setup.sh" "$T/sym" 2>&1)"
    expect_eq "install(.claude がシンボリックリンク): exit 1" 1 "$?"
    expect_eq "install(.claude がシンボリックリンク): リンク先を変えない" "dotfiles" "$(cat "$T/realclaude/mine.txt")"
    expect_missing "install(.claude がシンボリックリンク): 何も配置しない" "$T/sym/.agents"

    # .claude/skills をディレクトリごと .agents/skills へリンクしている場合、原本を消さない
    bash "$SRC/setup.sh" "$T/dirlink" --agent claude >/dev/null 2>&1
    rm -rf "$T/dirlink/.claude/skills"
    ln -s ../.agents/skills "$T/dirlink/.claude/skills"
    bash "$SRC/setup.sh" "$T/dirlink" --relink --links symlink >/dev/null 2>&1
    expect_eq "relink(ディレクトリごとのリンク): exit 0" 0 "$?"
    expect_exists "relink(ディレクトリごとのリンク): 原本の skill を消さない" "$T/dirlink/.agents/skills/prd/SKILL.md"
    [[ ! -L "$T/dirlink/.agents/skills/prd" ]] && ok "relink(ディレクトリごとのリンク): 原本の中にリンクを作らない" || ng "relink(ディレクトリごとのリンク): 原本の中にリンクを作らない" "real directory" "symlink"
    bash "$SRC/setup.sh" "$T/dirlink" --upgrade >/dev/null 2>&1
    expect_exists "upgrade(ディレクトリごとのリンク): 原本の skill を消さない" "$T/dirlink/.agents/skills/plan/SKILL.md"

    # rules のサブディレクトリも Claude Code へつなぐ
    mkdir -p "$T/full/.agents/rules/frontend"
    printf '# react rule\n' > "$T/full/.agents/rules/frontend/react.md"
    bash "$SRC/setup.sh" "$T/full" --relink >/dev/null 2>&1
    [[ -L "$T/full/.claude/rules/frontend" ]] && ok "relink: rules のサブディレクトリをつなぐ" || ng "relink: rules のサブディレクトリをつなぐ" "symlink" "missing"
    expect_exists "relink: サブディレクトリのルールがリンク越しに読める" "$T/full/.claude/rules/frontend/react.md"

    # コピー方式の --relink は .agents/ を正としてコピーを作り直す(ヘルプが案内している手順)
    printf '\n# edited in .agents\n' >> "$T/cp/.agents/skills/plan/SKILL.md"
    OUT="$(bash "$SRC/setup.sh" "$T/cp" --relink 2>&1)"
    expect_eq "relink(copy): exit 0" 0 "$?"
    expect_eq "relink(copy): .agents/ の編集をコピーへ反映する" "$(sha "$T/cp/.agents/skills/plan/SKILL.md")" "$(sha "$T/cp/.claude/skills/plan/SKILL.md")"
    [[ ! -L "$T/cp/.claude/skills/plan" ]] && ok "relink(copy): コピー方式のまま" || ng "relink(copy): コピー方式のまま" "real directory" "symlink"

    # 統合途中の .blueprint-new を黙って上書きしない
    printf 'half merged\n' > "$T/full/CLAUDE.md.blueprint-new"
    bash "$T/tmpl/setup.sh" "$T/full" --upgrade >/dev/null 2>&1
    expect_eq "upgrade: 以前の .blueprint-new は .old に退避する" "half merged" "$(cat "$T/full/CLAUDE.md.blueprint-new.old" 2>/dev/null)"
    expect_eq "upgrade: .blueprint-new は新テンプレートに置き換える" "$(sha "$T/tmpl/.claude/CLAUDE.md")" "$(sha "$T/full/CLAUDE.md.blueprint-new")"

    bash "$SRC/setup.sh" "$T/bad" --agent gemini >/dev/null 2>&1
    expect_eq "install(不正な --agent): exit 1" 1 "$?"
    expect_missing "install(不正な --agent): 何も配置しない" "$T/bad/.agents"

    rm -rf "$T"
done

echo
echo "結果: PASS $PASS / FAIL $FAIL"
if (( FAIL > 0 )); then
    echo "setup.sh の機能テストに失敗があります。"
    exit 1
fi
echo "setup.sh の機能テスト全件 PASS。"
exit 0
