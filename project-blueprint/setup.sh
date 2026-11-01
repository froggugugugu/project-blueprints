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
  bash setup.sh <ターゲットディレクトリ> --upgrade [--dry-run]

説明:
  Project Blueprint のファイルをターゲットプロジェクトにコピーします。

  - .claude/ (スキル・チーム・設定)
  - docs/ (技術ドキュメントスタブ)
  - input/ (要求メモ置き場)
  - output/ (AI成果物置き場)
  - testreport/ (ツール直接出力)
  - project-config.md (設定ファイル)
  - CLAUDE.md / AGENTS.md → プロジェクトルートに配置
  - REVIEW.md(Code Review 用の審査基準)/ constitution.md → 既存が無ければ配置

プロファイル(--profile、省略時は full):
  minimal   skills 5 / agents 2 / hooks 2 / teams なし — 最速で試す軽量構成
  standard  skills 17 / agents 9 / hooks 18 / teams なし — チーム機能以外フル
  full      skills 17 / agents 9 / hooks 18 / teams 6 — デフォルト・現行互換

  ※ minimal はセーフガード系フック(session-start等)も間引く軽量構成です。
     project-config.md の「ミニマル/推奨/フル」(§記入量の目安)とは別の軸です。

更新(--upgrade):
  導入済みプロジェクトをこのテンプレートの版に追従させる。導入時に記録した
  .claude/blueprint-manifest.txt(ファイルごとのハッシュ)と比べ、手を入れていないファイルだけ上書きし、
  変更済みのファイルは <path>.blueprint-new を横に置いて報告する。project-config.md / docs/ / input/ /
  output/ / settings.local.json は触らない。--dry-run は計画だけ表示する。

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
MODE="install"
DRY_RUN=0
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
        --upgrade)
            MODE="upgrade"
            shift
            ;;
        --dry-run)
            DRY_RUN=1
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

MANIFEST_REL=".claude/blueprint-manifest.txt"
BLUEPRINT_VERSION="$(tr -d '[:space:]' < "$SCRIPT_DIR/../VERSION" 2>/dev/null || true)"
[[ -z "${BLUEPRINT_VERSION}" ]] && BLUEPRINT_VERSION="unknown"
BLUEPRINT_COMMIT="$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
MIRROR_LANG="ja"; [[ "$(basename "$SCRIPT_DIR")" == *-en ]] && MIRROR_LANG="en"
INSTALLED_VERSION=""

if [[ "$MODE" == "upgrade" ]]; then
    if [[ ! -f "$TARGET_DIR/$MANIFEST_REL" ]]; then
        error ".claude/blueprint-manifest.txt がありません(0.5.0 より前の setup.sh で導入したか、手動コピー)。一度 setup.sh <dir> で再導入(既存の .claude/ は .claude.bak/ に退避される)してから --upgrade を使ってください"
        exit 1
    fi
    INSTALLED_VERSION="$(sed -n 's/^# version: //p' "$TARGET_DIR/$MANIFEST_REL" | head -1)"
    PROFILE="$(sed -n 's/^# profile: //p' "$TARGET_DIR/$MANIFEST_REL" | head -1)"
    case "$PROFILE" in minimal|standard|full) ;; *) PROFILE="full" ;; esac
fi

# ── 既存 .claude/ のバックアップ ────────────────────────────
# --upgrade では既存 .claude/ をそのまま使う(退避しない)
if [[ "$MODE" == "install" && -d "$TARGET_DIR/.claude" ]]; then
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


# ── --upgrade: 導入済みプロジェクトをテンプレートの版に追従させる ──
sha256_of() {
    if command -v shasum &>/dev/null; then shasum -a 256 "$1" | cut -d' ' -f1
    elif command -v sha256sum &>/dev/null; then sha256sum "$1" | cut -d' ' -f1
    else cksum "$1" | cut -d' ' -f1; fi
}

# keep リストに照らして、テンプレート側の相対パスを採用するか判定する
keep_path() {
    local rel="$1" second k
    case "$rel" in
        .claude/skills/*)
            second="${rel#.claude/skills/}"; second="${second%%/*}"
            [[ "${KEEP_SKILLS[0]:-}" == "*" ]] && return 0
            for k in "${KEEP_SKILLS[@]}"; do [[ "$second" == "$k" ]] && return 0; done
            return 1 ;;
        .claude/agents/*)
            second="${rel#.claude/agents/}"
            [[ "${KEEP_AGENTS[0]:-}" == "*" || "$second" == "README.md" ]] && return 0
            for k in "${KEEP_AGENTS[@]}"; do [[ "$second" == "$k" ]] && return 0; done
            return 1 ;;
        .claude/hooks/*)
            second="${rel#.claude/hooks/}"
            [[ "${KEEP_HOOKS[0]:-}" == "*" ]] && return 0
            for k in "${KEEP_HOOKS[@]}"; do [[ "$second" == "$k" ]] && return 0; done
            return 1 ;;
        .claude/teams/*|.claude/workflows/*)
            [[ "${#KEEP_TEAMS[@]}" -gt 0 ]] ;;
        .claude/settings.minimal.json) [[ "$PROFILE" == "minimal" ]] ;;
        .claude/settings.json) [[ "$PROFILE" != "minimal" ]] ;;
        .claude/blueprint-manifest.txt) return 1 ;;
        *) return 0 ;;
    esac
}

# テンプレート相対パス → ターゲット相対パス
target_path() {
    case "$1" in
        .claude/CLAUDE.md) echo "CLAUDE.md" ;;
        .claude/settings.minimal.json) echo ".claude/settings.json" ;;
        *) echo "$1" ;;
    esac
}

# upgrade / manifest の対象になるテンプレート側の相対パス一覧(剪定適用後)
template_files() {
    local rel
    {
        (cd "$SCRIPT_DIR" && find .claude -type f | sed 's#^\./##')
        for rel in AGENTS.md REVIEW.md constitution.md .mcp.json.template project-config.md; do
            if [[ -f "$SCRIPT_DIR/$rel" ]]; then echo "$rel"; fi
        done
        (cd "$SCRIPT_DIR" && find .github -type f \( -name '*.template' -o -name '*.md' \) 2>/dev/null | sed 's#^\./##')
    } | while IFS= read -r rel; do
        if keep_path "$rel"; then echo "$rel"; fi
    done | LC_ALL=C sort
}

# 導入時のファイルハッシュを記録する。--upgrade はこれと比べて「手を入れていない」ファイルだけ上書きする
write_manifest() {   # <target-dir> <profile>
    local rel tp
    {
        echo "# blueprint-manifest v1 — generated by setup.sh; used by --upgrade. Do not edit by hand"
        echo "# version: ${BLUEPRINT_VERSION}"
        echo "# commit: ${BLUEPRINT_COMMIT}"
        echo "# profile: $2"
        echo "# mirror: $MIRROR_LANG"
        echo "# installed: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        template_files | while IFS= read -r rel; do
            tp="$(target_path "$rel")"
            echo "$(sha256_of "$SCRIPT_DIR/$rel")  $tp"
        done
    } > "$1/$MANIFEST_REL"
}

manifest_hash() {   # <manifest> <target-relative-path>
    awk -v p="$2" '$1 !~ /^#/ && $2 == p {print $1; exit}' "$1"
}

run_upgrade() {
    local mf="$TARGET_DIR/$MANIFEST_REL" rel tp th ch mh dst s found
    local added=0 updated=0 unchanged=0 conflicts=0 skipped=0 removed=0
    local -a seen=() conflict_lines=()
    info "更新: ${INSTALLED_VERSION} → ${BLUEPRINT_VERSION}(${BLUEPRINT_COMMIT}、プロファイル: ${PROFILE})"
    if [[ $DRY_RUN -eq 1 ]]; then warn "--dry-run: ファイルは変更しません"; fi
    while IFS= read -r rel; do
        tp="$(target_path "$rel")"
        mh="$(manifest_hash "$mf" "$tp")"
        if [[ "$tp" == "AGENTS.md" && -e "$TARGET_DIR/AGENTS.blueprint.md" ]]; then tp="AGENTS.blueprint.md"; fi
        seen+=("$tp")
        dst="$TARGET_DIR/$tp"
        th="$(sha256_of "$SCRIPT_DIR/$rel")"
        if [[ "$tp" == "project-config.md" ]]; then
            if [[ -n "$mh" && "$mh" != "$th" ]]; then warn "project-config.md のテンプレートが変わっています(人間が記入するファイルなので上書きしません)。差分: diff ${SCRIPT_DIR}/project-config.md ${TARGET_DIR}/project-config.md"; fi
            continue
        fi
        if [[ ! -e "$dst" ]]; then
            if [[ -n "$mh" ]]; then
                echo "  skip     $tp  (ローカルで削除済み。復活させるなら手でコピー)"; skipped=$((skipped + 1))
            else
                echo "  add      $tp"; added=$((added + 1))
                if [[ $DRY_RUN -eq 0 ]]; then mkdir -p "$(dirname "$dst")"; cp "$SCRIPT_DIR/$rel" "$dst"; fi
            fi
            continue
        fi
        ch="$(sha256_of "$dst")"
        if [[ "$ch" == "$th" ]]; then
            unchanged=$((unchanged + 1))
        elif [[ -n "$mh" && "$ch" == "$mh" ]]; then
            echo "  update   $tp"; updated=$((updated + 1))
            if [[ $DRY_RUN -eq 0 ]]; then cp "$SCRIPT_DIR/$rel" "$dst"; fi
        else
            echo "  conflict $tp  (手で変更あり。新版を横に置いた: $tp.blueprint-new)"; conflicts=$((conflicts + 1))
            if [[ $DRY_RUN -eq 0 ]]; then cp "$SCRIPT_DIR/$rel" "$dst.blueprint-new"; fi
            if [[ -n "$mh" ]]; then conflict_lines+=("$mh  $tp"); fi
        fi
    done < <(template_files)
    while IFS= read -r tp; do
        [[ -z "$tp" ]] && continue
        found=0
        for s in "${seen[@]}"; do [[ "$s" == "$tp" ]] && { found=1; break; }; done
        if [[ $found -eq 0 && -e "$TARGET_DIR/$tp" ]]; then
            echo "  removed  $tp  (テンプレートから削除された。不要なら手で消す)"; removed=$((removed + 1))
        fi
    done < <(awk '$1 !~ /^#/ {print $2}' "$mf")
    if [[ $DRY_RUN -eq 0 ]]; then
        write_manifest "$TARGET_DIR" "$PROFILE"
        if [[ ${#conflict_lines[@]} -gt 0 ]]; then
            awk -v list="$(printf '%s\n' "${conflict_lines[@]}")" '
                BEGIN { n = split(list, a, "\n"); for (i = 1; i <= n; i++) { split(a[i], b, "  "); keep[b[2]] = b[1] } }
                $1 !~ /^#/ && ($2 in keep) { print keep[$2] "  " $2; next }
                { print }' "$mf" > "$mf.tmp" && mv "$mf.tmp" "$mf"
        fi
        chmod +x "$TARGET_DIR/.claude/hooks/"*.sh "$TARGET_DIR/.claude/scripts/"*.sh 2>/dev/null || true
    fi
    echo ""
    info "更新完了: 追加 ${added} / 更新 ${updated} / 変更なし ${unchanged} / 競合 ${conflicts} / スキップ ${skipped} / テンプレートから削除 ${removed}"
    if [[ ${conflicts} -gt 0 ]]; then warn "次: 競合は diff <path> <path>.blueprint-new で統合して .blueprint-new を消す。その後 Claude Code で /harness-refine を回す"; fi
    return 0
}

# --upgrade はここで分岐する(以降の install 処理は走らない)
if [[ "$MODE" == "upgrade" ]]; then
    run_upgrade
    exit 0
fi

# ── ファイルコピー ──────────────────────────────────────────
info "ブループリントをコピー中... (プロファイル: ${PROFILE})"

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
    # saved workflow は team 層(オーケストレーション)なので teams と同じ扱い
    rm -rf "$TARGET_DIR/.claude/workflows"
fi

# ── settings.json の profile 差し替え ────────────────────────
if [[ "$PROFILE" == "minimal" ]]; then
    mv "$TARGET_DIR/.claude/settings.minimal.json" "$TARGET_DIR/.claude/settings.json"
else
    rm -f "$TARGET_DIR/.claude/settings.minimal.json"
fi

# ── settings.local.json を雛形から生成(無ければ) ─────────────
# 個人の allow ルール。gitignore 済みで、SessionStart フックが未作成を警告する対象。
if [[ -f "$TARGET_DIR/.claude/settings.local.json.template" && ! -f "$TARGET_DIR/.claude/settings.local.json" ]]; then
    cp "$TARGET_DIR/.claude/settings.local.json.template" "$TARGET_DIR/.claude/settings.local.json"
    info ".claude/settings.local.json を雛形から生成(ビルドツールに合わせて allow を調整してください)"
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

# REVIEW.md(Claude の Code Review 用のレビュー指示)を配置 — 既存ファイルは保持
if [[ -f "$SCRIPT_DIR/REVIEW.md" ]]; then
    if [[ -e "$TARGET_DIR/REVIEW.md" ]]; then
        info "REVIEW.md は既に存在するため保持(上書きしない)"
    else
        cp "$SCRIPT_DIR/REVIEW.md" "$TARGET_DIR/REVIEW.md"
        info "REVIEW.md(Code Review の審査基準)を配置"
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
    chmod +x "$TARGET_DIR/.claude/scripts/"*.sh 2>/dev/null || true
    info "フックスクリプトを実行可能に設定"
fi

# ── CLAUDE.md をプロジェクトルートに移動 ────────────────────
if [[ -f "$TARGET_DIR/.claude/CLAUDE.md" ]]; then
    mv "$TARGET_DIR/.claude/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
    info "CLAUDE.md をプロジェクトルートに配置"
fi

# ── AGENTS.md(ツール共通ルール)を配置 ──────────────────────
# Codex / Cursor / Copilot 等は直接読み、Claude Code は CLAUDE.md の @AGENTS.md で取り込む。
# 既存の AGENTS.md は上書きせず、テンプレート版を横に置いて統合を促す。
if [[ -f "$SCRIPT_DIR/AGENTS.md" ]]; then
    if [[ -e "$TARGET_DIR/AGENTS.md" ]] && cmp -s "$SCRIPT_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.md"; then
        info "AGENTS.md はテンプレートと同一のため保持"
    elif [[ -e "$TARGET_DIR/AGENTS.blueprint.md" ]] && ! cmp -s "$SCRIPT_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.blueprint.md"; then
        # 統合作業中の AGENTS.blueprint.md は上書きしない
        warn "AGENTS.blueprint.md がテンプレートと異なるため上書きしませんでした(統合作業中の内容を保持)。"
        warn "  最新のテンプレート版: $SCRIPT_DIR/AGENTS.md"
    elif [[ -e "$TARGET_DIR/AGENTS.md" ]]; then
        cp "$SCRIPT_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.blueprint.md"
        warn "既存の AGENTS.md を保持し、テンプレート版を AGENTS.blueprint.md として配置しました。"
        warn "  内容を AGENTS.md に統合してから AGENTS.blueprint.md を削除してください(CLAUDE.md は AGENTS.md だけを取り込みます)"
    else
        cp "$SCRIPT_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.md"
        info "AGENTS.md(ツール共通ルール)をプロジェクトルートに配置"
    fi
    info "  Claude Code 以外のエージェントを併用する場合は project-config.md §13.7 に役割と書込範囲を記入"
fi

# ── .gitignore に testreport/ を追記 ────────────────────────

GITIGNORE="$TARGET_DIR/.gitignore"
# Claude Code がリポジトリ内に作るローカル状態も一緒に除外する:
#   testreport/                 ツール直接出力 / 観測フックのログ
#   .claude/settings.local.json 個人の allow ルール(共有すると権限が漏れる)
#   .claude/worktrees/          --worktree / isolation: worktree の作業木
#   .claude/agent-memory-local/ memory: local の subagent メモリ
#   .claude/skills/*-workspace/ skill-creator の eval 作業ディレクトリ
GITIGNORE_ENTRIES=(testreport/ .claude/settings.local.json .claude/worktrees/ .claude/agent-memory-local/ .claude/skills/*-workspace/)
if [[ ! -f "$GITIGNORE" ]]; then
    printf '%s\n' "# Claude Code ローカル状態（AI生成の生データ・個人設定）" > "$GITIGNORE"
    info ".gitignore を作成"
fi
for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if ! grep -qxF "$entry" "$GITIGNORE" 2>/dev/null; then
        if [[ "$entry" == "testreport/" ]] && ! grep -q '^# ' "$GITIGNORE"; then
            echo "" >> "$GITIGNORE"
            echo "# Claude Code ローカル状態（AI生成の生データ・個人設定）" >> "$GITIGNORE"
        fi
        echo "$entry" >> "$GITIGNORE"
        info ".gitignore に追記: $entry"
    else
        info ".gitignore に既に含まれています: $entry"
    fi
done

# ── 導入版の記録(--upgrade の基準) ───────────────────────
write_manifest "$TARGET_DIR" "$PROFILE"
info "導入版を記録: .claude/blueprint-manifest.txt(更新は bash setup.sh <dir> --upgrade)"

# ── 完了メッセージ ──────────────────────────────────────────
echo ""
info "セットアップ完了! (プロファイル: ${PROFILE})"
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
