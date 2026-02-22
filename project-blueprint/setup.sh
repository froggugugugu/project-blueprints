#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Project Blueprint セットアップスクリプト
# ブループリントをターゲットプロジェクトにコピーする
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 色付き出力 ──────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── 使い方表示 ──────────────────────────────────────────────
usage() {
    cat <<'EOF'
使い方:
  bash setup.sh <ターゲットディレクトリ>

説明:
  Project Blueprint のファイルをターゲットプロジェクトにコピーします。

  - .claude/ (スキル・チーム・設定)
  - docs/ (技術ドキュメントスタブ)
  - input/ (要求メモ置き場)
  - output/ (AI成果物置き場)
  - testreport/ (ツール直接出力)
  - project-config.md (設定ファイル)
  - CLAUDE.md → プロジェクトルートに配置

例:
  bash setup.sh /path/to/my-project
  bash setup.sh .                      # カレントディレクトリに導入

セットアップ後の手順:
  1. project-config.md の §1〜§3, §6 を記入
  2. Claude Code で /plan を実行して動作確認
EOF
    exit 1
}

# ── 引数チェック ────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
    usage
fi

TARGET_DIR="$1"

# ターゲットディレクトリの存在確認
if [[ ! -d "$TARGET_DIR" ]]; then
    error "ターゲットディレクトリが存在しません: $TARGET_DIR"
    exit 1
fi

# 絶対パスに変換
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

info "ターゲット: $TARGET_DIR"

# ── 既存 .claude/ のバックアップ ────────────────────────────
if [[ -d "$TARGET_DIR/.claude" ]]; then
    BACKUP_DIR="$TARGET_DIR/.claude.bak"
    if [[ -d "$BACKUP_DIR" ]]; then
        warn "既存のバックアップ $BACKUP_DIR を上書きします"
        rm -rf "$BACKUP_DIR"
    fi
    warn "既存の .claude/ をバックアップ: .claude.bak/"
    mv "$TARGET_DIR/.claude" "$BACKUP_DIR"
fi

# ── ファイルコピー ──────────────────────────────────────────
info "ブループリントをコピー中..."

cp -r "$SCRIPT_DIR/.claude"          "$TARGET_DIR/.claude"
cp -r "$SCRIPT_DIR/docs"             "$TARGET_DIR/docs"
cp -r "$SCRIPT_DIR/input"            "$TARGET_DIR/input"
cp -r "$SCRIPT_DIR/output"           "$TARGET_DIR/output"
cp -r "$SCRIPT_DIR/testreport"       "$TARGET_DIR/testreport"
cp    "$SCRIPT_DIR/project-config.md" "$TARGET_DIR/project-config.md"

# ── CLAUDE.md をプロジェクトルートに移動 ────────────────────
if [[ -f "$TARGET_DIR/.claude/CLAUDE.md" ]]; then
    mv "$TARGET_DIR/.claude/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
    info "CLAUDE.md をプロジェクトルートに配置"
fi

# ── .gitignore に testreport/ を追記 ────────────────────────
GITIGNORE="$TARGET_DIR/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
    if ! grep -q '^testreport/' "$GITIGNORE" 2>/dev/null; then
        echo "" >> "$GITIGNORE"
        echo "# ツール直接出力（AI生成の生データ）" >> "$GITIGNORE"
        echo "testreport/" >> "$GITIGNORE"
        info ".gitignore に testreport/ を追記"
    else
        info ".gitignore に testreport/ は既に含まれています"
    fi
else
    cat > "$GITIGNORE" <<'GITIGNORE_EOF'
# ツール直接出力（AI生成の生データ）
testreport/
GITIGNORE_EOF
    info ".gitignore を作成し testreport/ を追記"
fi

# ── 完了メッセージ ──────────────────────────────────────────
echo ""
info "セットアップ完了!"
echo ""
echo "次のステップ:"
echo "  1. project-config.md を記入（最低 §1〜§3, §6）"
echo "     vi $TARGET_DIR/project-config.md"
echo ""
echo "  2. 権限設定をカスタマイズ（任意）"
echo "     cp $TARGET_DIR/.claude/settings.local.json.template $TARGET_DIR/.claude/settings.local.json"
echo ""
echo "  3. Claude Code で動作確認"
echo "     cd $TARGET_DIR && claude"
echo "     /plan プロジェクトの初期セットアップ状況を確認"
echo ""
echo "  詳細: https://github.com/your-org/project-blueprints"
