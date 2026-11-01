#!/usr/bin/env bash
# ==============================================================================
# release.sh — VERSION / CHANGELOG / git tag / GitHub Release を 1 手順で揃える
#
# main は branch protection で直接 push できないため 2 段階:
#   bash scripts/release.sh prepare 0.5.0   # ブランチを切り、CHANGELOG の Unreleased を版にし、VERSION を上げてコミット → PR を作る
#   bash scripts/release.sh publish 0.5.0   # マージ済みの main 上で検証し、v0.5.0 タグと GitHub Release(CHANGELOG の該当節を本文)を作る
#
# どちらも --dry-run で変更内容だけ表示する。validate-harness.sh が VERSION と CHANGELOG の整合を検査する。
# ==============================================================================

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

CMD="${1:-}"; VER="${2:-}"; DRY=0
[[ "${3:-}" == "--dry-run" || "${2:-}" == "--dry-run" ]] && DRY=1
[[ "$VER" == "--dry-run" ]] && VER=""
[[ -z "$CMD" || -z "$VER" ]] && usage
[[ "$VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: バージョンは x.y.z 形式で指定してください: $VER" >&2; exit 1; }

TODAY="$(date -u +%Y-%m-%d)"
REMOTE_URL="$(git config --get remote.origin.url | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
COMPARE="https://github.com/${REMOTE_URL}/compare"

case "$CMD" in
  prepare)
    CUR="$(cat VERSION)"
    [[ "$CUR" == "$VER" ]] && { echo "ERROR: VERSION は既に $VER です" >&2; exit 1; }
    grep -q '^## \[Unreleased\]' CHANGELOG.md || { echo "ERROR: CHANGELOG.md に ## [Unreleased] がありません" >&2; exit 1; }
    [[ -z "$(git status --porcelain)" ]] || { echo "ERROR: 作業ツリーが汚れています。コミットか stash してから実行してください" >&2; exit 1; }
    echo "prepare: $CUR → $VER ($TODAY)"
    echo "  - CHANGELOG.md: '## [Unreleased]' の直後に '## [$VER] — $TODAY' を挿入し、比較リンクを更新"
    echo "  - VERSION: $VER"
    echo "  - ブランチ chore/release-$VER にコミット"
    [[ $DRY -eq 1 ]] && exit 0
    git checkout -b "chore/release-$VER"
    python3 - "$VER" "$TODAY" "$CUR" "$COMPARE" <<'PY'
import re, sys
from pathlib import Path
ver, today, cur, compare = sys.argv[1:5]
p = Path("CHANGELOG.md"); s = p.read_text(encoding="utf-8")
s = s.replace("## [Unreleased]\n", f"## [Unreleased]\n\n## [{ver}] — {today}\n", 1)
s = re.sub(r"^\[Unreleased\]: .*$",
           f"[Unreleased]: {compare}/v{ver}...HEAD\n[{ver}]: {compare}/v{cur}...v{ver}", s, count=1, flags=re.M)
p.write_text(s, encoding="utf-8")
Path("VERSION").write_text(ver + "\n", encoding="utf-8")
PY
    bash scripts/validate-harness.sh >/dev/null || { echo "ERROR: validate-harness.sh が失敗しました" >&2; exit 1; }
    git add CHANGELOG.md VERSION
    git commit -q -m "chore(release): v$VER"
    echo "done. 次: git push -u origin chore/release-$VER && gh pr create --fill"
    ;;
  publish)
    [[ "$(git branch --show-current)" == "main" ]] || { echo "ERROR: main 上で実行してください(マージ後に git checkout main && git pull)" >&2; exit 1; }
    [[ "$(cat VERSION)" == "$VER" ]] || { echo "ERROR: VERSION($(cat VERSION))が $VER と一致しません。先に prepare をマージしてください" >&2; exit 1; }
    grep -q "^## \[$VER\]" CHANGELOG.md || { echo "ERROR: CHANGELOG.md に ## [$VER] がありません" >&2; exit 1; }
    git fetch -q origin main
    [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || { echo "ERROR: ローカル main が origin/main と異なります" >&2; exit 1; }
    git rev-parse -q --verify "refs/tags/v$VER" >/dev/null && { echo "ERROR: タグ v$VER は既に存在します" >&2; exit 1; }
    NOTES="$(awk -v h="## [$VER]" 'index($0, h) == 1 {on=1; next} on && /^## \[/ {exit} on' CHANGELOG.md)"
    echo "publish: v$VER を $(git rev-parse --short HEAD) に打ち、GitHub Release を作成"
    echo "--- release notes ---"; printf '%s\n' "$NOTES" | head -20; echo "..."
    [[ $DRY -eq 1 ]] && exit 0
    git tag -a "v$VER" -m "v$VER"
    git push origin "v$VER"
    printf '%s\n' "$NOTES" | gh release create "v$VER" --title "v$VER" --notes-file -
    echo "done: https://github.com/${REMOTE_URL}/releases/tag/v$VER"
    ;;
  *) usage ;;
esac
