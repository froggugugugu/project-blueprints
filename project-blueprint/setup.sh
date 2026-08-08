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
  bash setup.sh <ターゲットディレクトリ> [--profile minimal|standard|full]

説明:
  Project Blueprint のファイルをターゲットプロジェクトにコピーします。

  - .claude/ (スキル・チーム・設定)
  - docs/ (技術ドキュメントスタブ)
  - input/ (要求メモ置き場)
  - output/ (AI成果物置き場)
  - testreport/ (ツール直接出力)
  - project-config.md (設定ファイル)
  - CLAUDE.md → プロジェクトルートに配置

プロファイル(--profile、省略時は full):
  minimal   skills 5 / agents 2 / hooks 2 / teams なし — 最速で試す軽量構成
  standard  skills 17 / agents 8 / hooks 12 / teams なし — チーム機能以外フル
  full      skills 17 / agents 8 / hooks 12 / teams 6 — デフォルト・現行互換

  ※ minimal はセーフガード系フック(session-start等)も間引く軽量構成です。
     project-config.md の「ミニマル/推奨/フル」(§記入量の目安)とは別の軸です。

例:
  bash setup.sh /path/to/my-project
  bash setup.sh /path/to/my-project --profile minimal
  bash setup.sh . --profile standard   # カレントディレクトリに導入

セットアップ後の手順:
  1. project-config.md の §1〜§3, §6 を記入
  2. Claude Code で /plan を実行して動作確認
EOF
    exit 1
}

# ── 引数解析 ────────────────────────────────────────────────
PROFILE="full"   # デフォルトは後方互換のため full(剪定なし)
TARGET_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            PROFILE="${2:-}"
            shift 2
            ;;
        --profile=*)
            PROFILE="${1#*=}"
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            error "不明なオプション: $1"
            usage
            ;;
        *)
            if [[ -n "$TARGET_DIR" ]]; then
                error "ターゲットディレクトリは1つだけ指定してください: $1"
                usage
            fi
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

if [[ -z "$TARGET_DIR" ]]; then
    usage
fi

case "$PROFILE" in
    minimal|standard|full) ;;
    *)
        error "不正なプロファイル: $PROFILE (minimal / standard / full のいずれか)"
        usage
        ;;
esac

# ── 依存ツールの確認 ─────────────────────────────────────────
# jq は safety-check.sh フックの完全動作に必要。不在時は警告のみ(setup は続行)。
if ! command -v jq &>/dev/null; then
    warn "jq が未インストールです。safety-check.sh フックが jq 不在時に rm -rf / 等の最重要パターン以外をスキップします。"
    warn "インストール: macOS → brew install jq  /  Ubuntu → sudo apt-get install jq  /  Alpine → apk add jq"
fi

# ターゲットディレクトリの存在確認(なければ作成。新規プロジェクト想定)
if [[ ! -d "$TARGET_DIR" ]]; then
    info "ターゲットディレクトリを新規作成: $TARGET_DIR"
    mkdir -p "$TARGET_DIR" || { error "ディレクトリ作成に失敗: $TARGET_DIR"; exit 1; }
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

# ── プロファイル別 keep リスト ──────────────────────────────
# "*" は「剪定しない(全部残す)」を意味するセンチネル。
# standard/full は skills/agents/hooks を一切削らないため、
# 将来ファイルが増減しても保守対象は minimal のリストだけで済む。
case "$PROFILE" in
    minimal)
        KEEP_SKILLS=(brainstorm prd plan implementing-features code-review)
        KEEP_AGENTS=(explorer.md researcher.md)
        KEEP_HOOKS=(safety-check.sh protect-files.sh)
        KEEP_TEAMS=()          # 空 = teams/ を丸ごと除外
        ;;
    standard)
        KEEP_SKILLS=("*")
        KEEP_AGENTS=("*")
        KEEP_HOOKS=("*")
        KEEP_TEAMS=()          # 空 = teams/ を丸ごと除外
        ;;
    full)
        KEEP_SKILLS=("*")
        KEEP_AGENTS=("*")
        KEEP_HOOKS=("*")
        KEEP_TEAMS=("*")
        ;;
esac

# 与えられたディレクトリ直下を keep リストに基づいて剪定する。
# bash 3.2(macOS標準)互換のため連想配列は使わない。
prune_dir() {
    local dir="$1"; shift
    local -a keep=("$@")
    [[ "${keep[0]:-}" == "*" ]] && return 0   # センチネル: 何もしない
    local entry base found k
    for entry in "$dir"/*; do
        [[ -e "$entry" ]] || continue
        base="$(basename "$entry")"
        found=0
        for k in "${keep[@]}"; do
            [[ "$base" == "$k" ]] && { found=1; break; }
        done
        [[ "$found" -eq 0 ]] && rm -rf "$entry"
    done
}

# ── ファイルコピー ──────────────────────────────────────────
info "ブループリントをコピー中... (プロファイル: $PROFILE)"

cp -r "$SCRIPT_DIR/.claude"          "$TARGET_DIR/.claude"
cp -r "$SCRIPT_DIR/docs"             "$TARGET_DIR/docs"
cp -r "$SCRIPT_DIR/input"            "$TARGET_DIR/input"
cp -r "$SCRIPT_DIR/output"           "$TARGET_DIR/output"
cp -r "$SCRIPT_DIR/testreport"       "$TARGET_DIR/testreport"
cp    "$SCRIPT_DIR/project-config.md" "$TARGET_DIR/project-config.md"

# ── プロファイルに応じた .claude/ の剪定 ─────────────────────
prune_dir "$TARGET_DIR/.claude/skills" "${KEEP_SKILLS[@]}"
prune_dir "$TARGET_DIR/.claude/agents" "${KEEP_AGENTS[@]}" "README.md"
prune_dir "$TARGET_DIR/.claude/hooks"  "${KEEP_HOOKS[@]}"

if [[ "${#KEEP_TEAMS[@]}" -eq 0 ]]; then
    rm -rf "$TARGET_DIR/.claude/teams"
fi

# ── settings.json の profile 差し替え ────────────────────────
if [[ "$PROFILE" == "minimal" ]]; then
    mv "$TARGET_DIR/.claude/settings.minimal.json" "$TARGET_DIR/.claude/settings.json"
else
    rm -f "$TARGET_DIR/.claude/settings.minimal.json"
fi
# constitution.md(不変原則)を配置 — scan-harness.sh / CLAUDE.md が参照する
# 注: SC2015 回避のため `&& A || B` ではなく明示的な if 分岐を使用する
#     (cp -n は上書きしないが exit 0 を返すので、存在チェックで判定する)
if [[ -f "$SCRIPT_DIR/constitution.md" ]]; then
    if [[ -e "$TARGET_DIR/constitution.md" ]]; then
        info "constitution.md は既に存在するため保持(上書きしない)"
    else
        cp "$SCRIPT_DIR/constitution.md" "$TARGET_DIR/constitution.md"
        info "constitution.md(不変原則)を配置"
    fi
fi

# ── .mcp.json.template の配置（利用者が .mcp.json にリネームして有効化）────
# 既存の .mcp.json.template がターゲットにある場合は保持する（利用者のカスタマイズ保護）
if [[ -f "$SCRIPT_DIR/.mcp.json.template" ]]; then
    if cp -n "$SCRIPT_DIR/.mcp.json.template" "$TARGET_DIR/.mcp.json.template" 2>/dev/null; then
        info ".mcp.json.template を配置（有効化するには .mcp.json にリネーム）"
    else
        info ".mcp.json.template は既に存在するため保持（上書きしない）"
    fi
fi

# ── .github/ ワークフローテンプレートの配置 ──────────────────
# マージ範囲（既存 .github/ がある場合）:
#   - workflows/*.template（ブループリント提供のワークフローテンプレート）
#   - トップレベルの *.md（CLAUDE_REVIEW_SETUP.md 等）
# 既存ファイルは `cp -n` で保持される。
# .github/ISSUE_TEMPLATE/, PULL_REQUEST_TEMPLATE.md, dependabot.yml 等を
# 将来ブループリント側に追加する場合、この分岐に対応コピーの追加が必要。
if [[ -d "$SCRIPT_DIR/.github" ]]; then
    if [[ -d "$TARGET_DIR/.github" ]]; then
        mkdir -p "$TARGET_DIR/.github/workflows"
        # shellcheck disable=SC2086
        cp -n "$SCRIPT_DIR"/.github/workflows/*.template \
              "$TARGET_DIR/.github/workflows/" 2>/dev/null || true
        # shellcheck disable=SC2086
        cp -n "$SCRIPT_DIR"/.github/*.md \
              "$TARGET_DIR/.github/" 2>/dev/null || true
        info ".github/ にワークフローテンプレートをマージ（既存ファイルは保持）"
    else
        cp -r "$SCRIPT_DIR/.github" "$TARGET_DIR/.github"
        info ".github/ を配置（ワークフロー有効化には .template 拡張子を外す）"
    fi
fi

# ── フックスクリプトを実行可能に設定 ─────────────────────────
if [[ -d "$TARGET_DIR/.claude/hooks" ]]; then
    chmod +x "$TARGET_DIR/.claude/hooks/"*.sh 2>/dev/null || true
    info "フックスクリプトを実行可能に設定"
fi

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
info "セットアップ完了! (プロファイル: $PROFILE)"
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
