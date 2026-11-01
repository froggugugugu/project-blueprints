#!/usr/bin/env bash
# ==============================================================================
# test_setup.sh — setup.sh の機能テスト(日英ミラー両方)
#
# 導入(profile 別の剪定・配置・manifest)と --upgrade(未変更ファイルの更新、手で変えた
# ファイルの競合、テンプレートに増えたファイルの追加、project-config.md 不干渉、冪等性、
# manifest 不在のエラー)を仮ディレクトリで検証する。
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

manifest_field() { sed -n "s/^# $2: //p" "$1/.claude/blueprint-manifest.txt" | head -1; }
manifest_hash()  { awk -v p="$2" '$1 !~ /^#/ && $2 == p {print $1; exit}' "$1/.claude/blueprint-manifest.txt"; }
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
    expect_exists "install(full): manifest が書かれる" "$T/full/.claude/blueprint-manifest.txt"
    expect_eq "install(full): manifest の profile" "full" "$(manifest_field "$T/full" profile)"
    expect_eq "install(full): manifest の version が VERSION と一致" "$(tr -d '[:space:]' < "$REPO/VERSION")" "$(manifest_field "$T/full" version)"
    expect_eq "install(full): manifest の CLAUDE.md ハッシュはテンプレートの .claude/CLAUDE.md" "$(sha "$SRC/.claude/CLAUDE.md")" "$(manifest_hash "$T/full" CLAUDE.md)"
    expect_eq "install(full): manifest に settings.local.json を含めない" "" "$(manifest_hash "$T/full" .claude/settings.local.json)"
    expect_eq "install(full): manifest に docs/ を含めない" "" "$(awk '$1 !~ /^#/ && $2 ~ /^docs\// {print; exit}' "$T/full/.claude/blueprint-manifest.txt")"
    N_SKILLS="$(find "$T/full/.claude/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
    expect_eq "install(full): skill 数がテンプレートと一致" "$(find "$SRC/.claude/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" "$N_SKILLS"
    [[ -x "$T/full/.claude/scripts/harness-stats.sh" ]] && ok "install(full): scripts/*.sh に実行権限" || ng "install(full): scripts/*.sh に実行権限" "executable" "not executable"

    # ── 導入(minimal)─────────────────────────────────────────────
    bash "$SRC/setup.sh" "$T/min" --profile minimal >/dev/null 2>&1
    expect_eq "install(minimal): exit 0" 0 "$?"
    expect_eq "install(minimal): skill は 5 本" 5 "$(find "$T/min/.claude/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
    expect_missing "install(minimal): teams/ は無い" "$T/min/.claude/teams"
    expect_eq "install(minimal): settings.json は settings.minimal.json 由来" "$(sha "$SRC/.claude/settings.minimal.json")" "$(sha "$T/min/.claude/settings.json")"
    expect_eq "install(minimal): manifest の settings.json ハッシュも minimal 版" "$(sha "$SRC/.claude/settings.minimal.json")" "$(manifest_hash "$T/min" .claude/settings.json)"
    expect_eq "install(minimal): manifest に剪定済み skill を含めない" "" "$(awk '$1 !~ /^#/ && $2 ~ /^\.claude\/skills\/security-scan\// {print; exit}' "$T/min/.claude/blueprint-manifest.txt")"

    # ── --upgrade ───────────────────────────────────────────────────
    # 新しいテンプレートを作る: skill を更新、CLAUDE.md を更新、hook を追加、project-config.md を変更
    cp -r "$SRC" "$T/tmpl"
    printf '\n# newer template\n' >> "$T/tmpl/.claude/skills/plan/SKILL.md"
    printf '\n# newer guide\n' >> "$T/tmpl/.claude/CLAUDE.md"
    printf '#!/usr/bin/env bash\necho hi\n' > "$T/tmpl/.claude/hooks/new-hook.sh"
    printf '\n<!-- template changed -->\n' >> "$T/tmpl/project-config.md"
    echo "9.9.9" > "$T/VERSION"
    # 利用者側の変更: CLAUDE.md と project-config.md を編集、ある hook を削除
    printf '\n# local edit\n' >> "$T/full/CLAUDE.md"
    printf '\n| プロジェクト名 | my-app |\n' >> "$T/full/project-config.md"
    rm -f "$T/full/.claude/hooks/console-warn.sh"

    OUT="$(bash "$T/tmpl/setup.sh" "$T/full" --upgrade --dry-run 2>&1)"
    expect_eq "upgrade(--dry-run): exit 0" 0 "$?"
    expect_contains "upgrade(--dry-run): 更新対象を列挙" "update   .claude/skills/plan/SKILL.md" "$OUT"
    expect_eq "upgrade(--dry-run): ファイルを変えない" "$(sha "$SRC/.claude/skills/plan/SKILL.md")" "$(sha "$T/full/.claude/skills/plan/SKILL.md")"
    expect_missing "upgrade(--dry-run): .blueprint-new を作らない" "$T/full/CLAUDE.md.blueprint-new"

    OUT="$(bash "$T/tmpl/setup.sh" "$T/full" --upgrade 2>&1)"
    expect_eq "upgrade: exit 0" 0 "$?"
    expect_eq "upgrade: 未変更の skill は新版で上書き" "$(sha "$T/tmpl/.claude/skills/plan/SKILL.md")" "$(sha "$T/full/.claude/skills/plan/SKILL.md")"
    expect_exists "upgrade: テンプレートに増えた hook を追加" "$T/full/.claude/hooks/new-hook.sh"
    [[ -x "$T/full/.claude/hooks/new-hook.sh" ]] && ok "upgrade: 追加した hook に実行権限" || ng "upgrade: 追加した hook に実行権限" "executable" "not executable"
    expect_eq "upgrade: 手で変えた CLAUDE.md は上書きしない" 1 "$(grep -c 'local edit' "$T/full/CLAUDE.md")"
    expect_exists "upgrade: 競合は CLAUDE.md.blueprint-new を横に置く" "$T/full/CLAUDE.md.blueprint-new"
    expect_eq "upgrade: .blueprint-new の中身は新テンプレート" "$(sha "$T/tmpl/.claude/CLAUDE.md")" "$(sha "$T/full/CLAUDE.md.blueprint-new")"
    expect_contains "upgrade: 競合を報告" "conflict CLAUDE.md" "$OUT"
    expect_eq "upgrade: project-config.md は触らない" 1 "$(grep -c 'my-app' "$T/full/project-config.md")"
    expect_eq "upgrade: project-config.md にテンプレート側の変更を混ぜない" 0 "$(grep -c 'template changed' "$T/full/project-config.md")"
    expect_contains "upgrade: project-config.md の変更を警告" "project-config.md" "$OUT"
    expect_missing "upgrade: ローカルで消した hook は復活させない" "$T/full/.claude/hooks/console-warn.sh"
    expect_contains "upgrade: ローカル削除をスキップとして報告" "skip     .claude/hooks/console-warn.sh" "$OUT"
    expect_eq "upgrade: manifest の version が新テンプレート" "9.9.9" "$(manifest_field "$T/full" version)"
    expect_eq "upgrade: 競合ファイルの manifest ハッシュは旧版のまま(次回も競合として扱う)" "$(sha "$SRC/.claude/CLAUDE.md")" "$(manifest_hash "$T/full" CLAUDE.md)"
    expect_eq "upgrade: 更新した skill の manifest ハッシュは新版" "$(sha "$T/tmpl/.claude/skills/plan/SKILL.md")" "$(manifest_hash "$T/full" .claude/skills/plan/SKILL.md)"
    expect_missing "upgrade: docs/ を触らない(stub のまま新規ファイル無し)" "$T/full/docs/.blueprint-new"

    OUT="$(bash "$T/tmpl/setup.sh" "$T/full" --upgrade 2>&1)"
    if [[ "$OUT" == *"更新 0 /"* || "$OUT" == *"updated 0 /"* ]]; then ok "upgrade(2 回目): 更新 0 で冪等"; else ng "upgrade(2 回目): 更新 0 で冪等" "updated 0" "$OUT"; fi
    expect_contains "upgrade(2 回目): 競合は再報告される" "conflict CLAUDE.md" "$OUT"

    # ── minimal プロファイルの upgrade は剪定を維持する ──────────────
    OUT="$(bash "$T/tmpl/setup.sh" "$T/min" --upgrade 2>&1)"
    expect_eq "upgrade(minimal): exit 0" 0 "$?"
    expect_missing "upgrade(minimal): 剪定済み skill を持ち込まない" "$T/min/.claude/skills/security-scan"
    expect_missing "upgrade(minimal): teams/ を持ち込まない" "$T/min/.claude/teams"
    expect_eq "upgrade(minimal): settings.json は minimal 版のまま" "$(sha "$T/tmpl/.claude/settings.minimal.json")" "$(sha "$T/min/.claude/settings.json")"

    # ── manifest が無いと失敗する ──────────────────────────────────
    mkdir -p "$T/bare/.claude"
    bash "$SRC/setup.sh" "$T/bare" --upgrade >/dev/null 2>&1
    expect_eq "upgrade: manifest 不在は exit 1" 1 "$?"
    expect_missing "upgrade: manifest 不在では何も配置しない" "$T/bare/CLAUDE.md"

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
