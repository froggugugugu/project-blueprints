#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Project Blueprint セットアップスクリプト / setup script
#
# ブループリントをターゲットプロジェクトに導入する。日英ミラーで同一のファイル
# (メッセージだけ t "<ja>" "<en>" で切り替える。validate-harness.sh が一致を検査する)。
#
# 導入後の構成:
#   .agents/   共通の核(skill・フック・ルール・品質ゲート)— Claude Code と Codex が共有する
#   .claude/   Claude Code 用アダプタ(--agent claude | both)
#   .codex/    Codex 用アダプタ(--agent codex | both)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIRROR_LANG="ja"; [[ "$(basename "$SCRIPT_DIR")" == *-en ]] && MIRROR_LANG="en"

# t "<日本語>" "<English>" — ミラーの言語に合う方を返す
t() { if [[ "$MIRROR_LANG" == "en" ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

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
    if [[ "$MIRROR_LANG" == "en" ]]; then
        cat <<'EOF'
Usage:
  bash setup.sh <target-directory> [--agent claude|codex|both] [--profile minimal|standard|full] [--links auto|symlink|copy]
  bash setup.sh <target-directory> --upgrade [--dry-run] [--agent claude|codex|both]
  bash setup.sh <target-directory> --relink

Description:
  Installs the Project Blueprint harness into the target project.

  - .agents/ (shared core: skills, hooks, rules, quality gates — used by both agents)
  - .claude/ (Claude Code adapter: settings, subagents, teams)        with --agent claude | both
  - .codex/  (Codex adapter: config, hook registrations, rules, agents) with --agent codex | both
  - docs/ input/ output/ testreport/ (existing files are kept)
  - project-config.md / AGENTS.md / constitution.md / REVIEW.md -> project root (existing files are kept)
  - CLAUDE.md -> project root (with --agent claude | both)

Agent (--agent, defaults to both):
  claude   Claude Code only
  codex    Codex only
  both     both, as equals (the shared core is installed once)

Profiles (--profile, defaults to full):
  minimal   5 skills / 2 agents / 2 hooks / no teams — fastest way to try it out
  standard  17 skills / 9 agents / 18 hooks / no teams — everything but team mode
  full      17 skills / 9 agents / 18 hooks / 6 teams — default (teams are a Claude Code extension)

  Note: minimal also trims safeguard hooks (e.g. session-start) for a lighter footprint.
  This is a separate axis from the "minimal/recommended/full" guidance in project-config.md.

Links (--links, defaults to auto):
  Claude Code reads skills from .claude/skills/ and rules from .claude/rules/, so setup.sh links those
  entries to .agents/. auto tries symbolic links and falls back to copies where they cannot be created.
  copy always copies (edit .agents/ only, then run --relink). After adding a skill or a rule under .agents/,
  run --relink.

Upgrade (--upgrade):
  Brings an installed project up to this template's version. Files are compared with the per-file
  hashes recorded at install time in .agents/blueprint-manifest.txt: untouched files are overwritten,
  modified files get the new version placed next to them as <path>.blueprint-new.
  project-config.md / docs/ / input/ / output/ / settings.local.json are never touched.
  --dry-run prints the plan only (it works with --upgrade only). Add --agent to add the other agent's adapter.
  An installed project cannot be installed again; use --upgrade, --upgrade --agent both, or --relink.
  A project installed with 0.x (everything under .claude/) is migrated with migrate.sh first.

Examples:
  bash setup.sh /path/to/my-project
  bash setup.sh /path/to/my-project --agent codex
  bash setup.sh . --agent claude --profile standard

After setup:
  1. Fill in project-config.md sections §1-§3 and §6
  2. Run /plan (Claude Code) or $plan (Codex) to verify the setup
EOF
    else
        cat <<'EOF'
使い方:
  bash setup.sh <ターゲットディレクトリ> [--agent claude|codex|both] [--profile minimal|standard|full] [--links auto|symlink|copy]
  bash setup.sh <ターゲットディレクトリ> --upgrade [--dry-run] [--agent claude|codex|both]
  bash setup.sh <ターゲットディレクトリ> --relink

説明:
  Project Blueprint のハーネスをターゲットプロジェクトに導入します。

  - .agents/ (共通の核: skill・フック・ルール・品質ゲート。両エージェントが共有)
  - .claude/ (Claude Code 用アダプタ: 設定・サブエージェント・チーム)        --agent claude | both
  - .codex/  (Codex 用アダプタ: 設定・フック登録・rules・エージェント)      --agent codex | both
  - docs/ input/ output/ testreport/ (既存ファイルは保持)
  - project-config.md / AGENTS.md / constitution.md / REVIEW.md → プロジェクトルート(既存は保持)
  - CLAUDE.md → プロジェクトルート(--agent claude | both)

エージェント(--agent、省略時は both):
  claude   Claude Code だけ
  codex    Codex だけ
  both     両方を対等に(共通の核は 1 つだけ入る)

プロファイル(--profile、省略時は full):
  minimal   skills 5 / agents 2 / hooks 2 / teams なし — 最速で試す軽量構成
  standard  skills 17 / agents 9 / hooks 18 / teams なし — チーム機能以外フル
  full      skills 17 / agents 9 / hooks 18 / teams 6 — デフォルト(teams は Claude Code の拡張)

  ※ minimal はセーフガード系フック(session-start等)も間引く軽量構成です。
     project-config.md の「ミニマル/推奨/フル」(§記入量の目安)とは別の軸です。

リンク(--links、省略時は auto):
  Claude Code は skill を .claude/skills/、ルールを .claude/rules/ から読むため、setup.sh が各項目を
  .agents/ へリンクします。auto はシンボリックリンクを試し、作れない環境ではコピーにします。
  copy は常にコピーです(編集は .agents/ 側だけで行い、--relink で反映)。.agents/ に skill やルールを
  足したあとは --relink を実行してください。

更新(--upgrade):
  導入済みプロジェクトをこのテンプレートの版に追従させる。導入時に記録した
  .agents/blueprint-manifest.txt(ファイルごとのハッシュ)と比べ、手を入れていないファイルだけ上書きし、
  変更済みのファイルは <path>.blueprint-new を横に置いて報告する。project-config.md / docs/ / input/ /
  output/ / settings.local.json は触らない。--dry-run は計画だけ表示する(--upgrade 専用)。--agent を付けると
  もう一方のアダプタを追加できる。導入済みのプロジェクトへの再導入はできない(--upgrade / --upgrade --agent both / --relink を使う)。
  0.x で導入したプロジェクト(すべてが .claude/ 配下)は、先に migrate.sh で移行する。

例:
  bash setup.sh /path/to/my-project
  bash setup.sh /path/to/my-project --agent codex
  bash setup.sh . --agent claude --profile standard

セットアップ後の手順:
  1. project-config.md の §1〜§3, §6 を記入
  2. /plan(Claude Code)または $plan(Codex)を実行して動作確認
EOF
    fi
    exit 1
}

# ── 引数解析 ────────────────────────────────────────────────
PROFILE="full"   # デフォルトは full(剪定なし)
AGENT=""         # 空 = 未指定(導入は both、--upgrade は manifest の値)
LINKS=""         # 空 = 未指定(導入は auto、--upgrade は manifest の値)
MODE="install"
DRY_RUN=0
TARGET_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)   PROFILE="${2:-}"; shift 2 ;;
        --profile=*) PROFILE="${1#*=}"; shift ;;
        --agent)     AGENT="${2:-}"; shift 2 ;;
        --agent=*)   AGENT="${1#*=}"; shift ;;
        --links)     LINKS="${2:-}"; shift 2 ;;
        --links=*)   LINKS="${1#*=}"; shift ;;
        --upgrade)   MODE="upgrade"; shift ;;
        --relink)    MODE="relink"; shift ;;
        --dry-run)   DRY_RUN=1; shift ;;
        -h|--help)   usage ;;
        -*)
            error "$(t "不明なオプション: $1" "Unknown option: $1")"
            usage
            ;;
        *)
            if [[ -n "$TARGET_DIR" ]]; then
                error "$(t "ターゲットディレクトリは1つだけ指定してください: $1" "Specify only one target directory: $1")"
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
        error "$(t "不正なプロファイル: $PROFILE (minimal / standard / full のいずれか)" "Invalid profile: $PROFILE (must be minimal, standard, or full)")"
        usage
        ;;
esac
case "$AGENT" in
    ""|claude|codex|both) ;;
    *)
        error "$(t "不正なエージェント: $AGENT (claude / codex / both のいずれか)" "Invalid agent: $AGENT (must be claude, codex, or both)")"
        usage
        ;;
esac
case "$LINKS" in
    ""|auto|symlink|copy) ;;
    *)
        error "$(t "不正なリンク方式: $LINKS (auto / symlink / copy のいずれか)" "Invalid link mode: $LINKS (must be auto, symlink, or copy)")"
        usage
        ;;
esac
# --dry-run は --upgrade でだけ意味を持つ。導入や --relink に付けても計画表示にはならないため、黙って実行せずに止める
if [[ $DRY_RUN -eq 1 && "$MODE" != "upgrade" ]]; then
    error "$(t "--dry-run は --upgrade と一緒に使ってください(導入と --relink には計画表示がありません)" \
               "--dry-run works only with --upgrade (install and --relink have no plan-only mode)")"
    exit 1
fi

# ── 依存ツールの確認 ─────────────────────────────────────────
# jq は safety-check.sh フックの完全動作に必要。不在時は警告のみ(setup は続行)。
if ! command -v jq &>/dev/null; then
    warn "$(t "jq が未インストールです。safety-check.sh フックが jq 不在時に最重要パターン以外をスキップします。" \
              "jq is not installed. safety-check.sh will skip most checks when jq is absent (only the most critical patterns will be caught).")"
    warn "$(t "インストール" "Install"): macOS → brew install jq  /  Ubuntu → sudo apt-get install jq  /  Alpine → apk add jq"
fi

# ターゲットディレクトリの存在確認(なければ作成。新規プロジェクト想定)
if [[ ! -d "$TARGET_DIR" ]]; then
    if [[ "$MODE" != "install" ]]; then
        error "$(t "ターゲットディレクトリがありません: $TARGET_DIR" "Target directory does not exist: $TARGET_DIR")"
        exit 1
    fi
    info "$(t "ターゲットディレクトリを新規作成: $TARGET_DIR" "Creating new target directory: $TARGET_DIR")"
    mkdir -p "$TARGET_DIR" || { error "$(t "ディレクトリ作成に失敗: $TARGET_DIR" "Failed to create directory: $TARGET_DIR")"; exit 1; }
fi

# 絶対パスに変換
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

info "$(t "ターゲット" "Target"): $TARGET_DIR"

# テンプレート自身を対象にすると、テンプレートの .agents/ .claude/ .codex/ を退避してしまう
if [[ "$TARGET_DIR" -ef "$SCRIPT_DIR" ]]; then
    error "$(t "ターゲットがテンプレート自身です。導入先のプロジェクトを指定してください" "The target is the template itself. Point at the project to install into")"
    exit 1
fi
# ハーネスのディレクトリがシンボリックリンクだと、退避・リンク作成・移動がリンク先の実体を壊す
# (.claude/skills/<名前> の相対リンク ../../.agents/... も実体側からは解決できない)
for d in .agents .claude .codex; do
    if [[ -L "$TARGET_DIR/$d" ]]; then
        error "$(t "$d がシンボリックリンクです。実体のディレクトリにしてから実行してください(リンク先を壊さないため、何も変更していません)" \
                   "$d is a symbolic link. Make it a real directory first (nothing was changed, to keep the link target intact)")"
        exit 1
    fi
done

MANIFEST_REL=".agents/blueprint-manifest.txt"
LEGACY_MANIFEST_REL=".claude/blueprint-manifest.txt"
BLUEPRINT_VERSION="$(tr -d '[:space:]' < "$SCRIPT_DIR/../VERSION" 2>/dev/null || true)"
[[ -z "${BLUEPRINT_VERSION}" ]] && BLUEPRINT_VERSION="unknown"
BLUEPRINT_COMMIT="$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
INSTALLED_VERSION=""
LINK_RESULT=""   # 実際に作れた方式(symlink / copy)。manifest に記録する

# 0.x の配置(すべてが .claude/ 配下)かどうか。manifest か、0.x にしか無い組み合わせで判定する
is_legacy_layout() {
    [[ -f "$TARGET_DIR/$MANIFEST_REL" ]] && return 1
    [[ -f "$TARGET_DIR/$LEGACY_MANIFEST_REL" ]] && return 0
    # migrate.sh と同じ条件にする(片方だけが 0.x と判定すると、どちらのスクリプトでも進めなくなる)
    [[ -f "$TARGET_DIR/.claude/hooks/safety-check.sh" ]] \
        && [[ -d "$TARGET_DIR/.claude/skills" || -f "$TARGET_DIR/.claude/quality-gates.md" ]]
}

legacy_error() {
    error "$(t "このプロジェクトは 0.x の配置(skill・フックが .claude/ 配下)です。先に移行してください:" \
               "This project uses the 0.x layout (skills and hooks under .claude/). Migrate it first:")"
    error "  bash $SCRIPT_DIR/migrate.sh $TARGET_DIR --dry-run"
    error "  bash $SCRIPT_DIR/migrate.sh $TARGET_DIR"
}

manifest_field() {   # <field>
    sed -n "s/^# $1: //p" "$TARGET_DIR/$MANIFEST_REL" | head -1
}

if [[ "$MODE" == "upgrade" || "$MODE" == "relink" ]]; then
    if [[ ! -f "$TARGET_DIR/$MANIFEST_REL" ]]; then
        if is_legacy_layout; then
            legacy_error
        else
            error "$(t ".agents/blueprint-manifest.txt がありません(このテンプレートで導入したプロジェクトではありません)。setup.sh <dir> で導入してください" \
                       "No .agents/blueprint-manifest.txt (this project was not installed with this template). Install it with setup.sh <dir>")"
        fi
        exit 1
    fi
    INSTALLED_VERSION="$(manifest_field version)"
    PROFILE="$(manifest_field profile)"
    case "$PROFILE" in minimal|standard|full) ;; *) PROFILE="full" ;; esac
    if [[ -z "$AGENT" ]]; then
        AGENT="$(manifest_field agent)"
        case "$AGENT" in claude|codex|both) ;; *) AGENT="both" ;; esac
    fi
    if [[ -z "$LINKS" ]]; then
        LINKS="$(manifest_field links)"
        case "$LINKS" in symlink|copy) ;; *) LINKS="auto" ;; esac
    fi
else
    [[ -z "$AGENT" ]] && AGENT="both"
    [[ -z "$LINKS" ]] && LINKS="auto"
    if is_legacy_layout; then
        legacy_error
        exit 1
    fi
    # 導入済みのプロジェクトに導入をやり直すと .agents/ と各アダプタを作り直すことになり、足した skill や編集が退避先に回る。
    # 版の追従もアダプタの追加も --upgrade でできるので、導入は止める
    if [[ -f "$TARGET_DIR/$MANIFEST_REL" ]]; then
        error "$(t "このプロジェクトは導入済みです(.agents/blueprint-manifest.txt があります)。更新は --upgrade、アダプタの追加は --upgrade --agent both、リンクの張り直しは --relink を使ってください" \
                   "This project is already installed (.agents/blueprint-manifest.txt exists). Use --upgrade to update, --upgrade --agent both to add an adapter, or --relink to refresh the links")"
        exit 1
    fi
fi

has_claude() { [[ "$AGENT" == "claude" || "$AGENT" == "both" ]]; }
has_codex()  { [[ "$AGENT" == "codex"  || "$AGENT" == "both" ]]; }

# ── プロファイル別 keep リスト ──────────────────────────────
# "*" は「剪定しない(全部残す)」を意味するセンチネル。
# standard/full は skills/agents/hooks を一切削らないため、
# 将来ファイルが増減しても保守対象は minimal のリストだけで済む。
# agent は拡張子なしの名前で持つ(.claude/agents/<name>.md と .codex/agents/<name>.toml の両方に効かせる)。
case "$PROFILE" in
    minimal)
        KEEP_SKILLS=(brainstorm prd plan implementing-features code-review)
        KEEP_AGENTS=(explorer researcher)
        KEEP_HOOKS=(safety-check.sh protect-files.sh)
        KEEP_TEAMS=0           # 0 = teams/ と workflows/ を丸ごと除外
        ;;
    standard)
        KEEP_SKILLS=("*")
        KEEP_AGENTS=("*")
        KEEP_HOOKS=("*")
        KEEP_TEAMS=0
        ;;
    full)
        KEEP_SKILLS=("*")
        KEEP_AGENTS=("*")
        KEEP_HOOKS=("*")
        KEEP_TEAMS=1
        ;;
esac

in_list() {   # <needle> <list...>  — "*" を含むリストは常に真。bash 3.2 互換(連想配列なし)
    local needle="$1" k
    shift
    for k in "$@"; do
        [[ "$k" == "*" || "$k" == "$needle" ]] && return 0
    done
    return 1
}

sha256_of() {
    if command -v shasum &>/dev/null; then shasum -a 256 "$1" | cut -d' ' -f1
    elif command -v sha256sum &>/dev/null; then sha256sum "$1" | cut -d' ' -f1
    else cksum "$1" | cut -d' ' -f1; fi
}

# エージェントとプロファイルに照らして、テンプレート側の相対パスを採用するか判定する
keep_path() {
    local rel="$1" second
    case "$rel" in
        .claude/*|.github/workflows/claude-*|.github/CLAUDE_*) has_claude || return 1 ;;
        .codex/*|.github/workflows/codex-*|.github/CODEX_*)    has_codex  || return 1 ;;
    esac
    case "$rel" in
        */.DS_Store|.claude/settings.local.json|.agents/blueprint-manifest.txt)
            return 1 ;;
        .agents/skills/*)
            second="${rel#.agents/skills/}"; second="${second%%/*}"
            in_list "$second" "${KEEP_SKILLS[@]}" ;;
        .agents/hooks/lib/*)
            return 0 ;;   # アダプタは全プロファイルで必要
        .agents/hooks/*)
            in_list "${rel#.agents/hooks/}" "${KEEP_HOOKS[@]}" ;;
        .claude/agents/README.md)
            return 0 ;;
        .claude/agents/*)
            second="${rel#.claude/agents/}"
            in_list "${second%.md}" "${KEEP_AGENTS[@]}" ;;
        .codex/agents/*)
            second="${rel#.codex/agents/}"
            in_list "${second%.toml}" "${KEEP_AGENTS[@]}" ;;
        .claude/teams/*|.claude/workflows/*)
            [[ "$KEEP_TEAMS" -eq 1 ]] ;;
        .claude/settings.minimal.json|.codex/hooks.minimal.json)
            [[ "$PROFILE" == "minimal" ]] ;;
        .claude/settings.json|.codex/hooks.json)
            [[ "$PROFILE" != "minimal" ]] ;;
        *) return 0 ;;
    esac
}

# テンプレート相対パス → ターゲット相対パス
target_path() {
    case "$1" in
        .claude/CLAUDE.md) echo "CLAUDE.md" ;;
        .claude/settings.minimal.json) echo ".claude/settings.json" ;;
        .codex/hooks.minimal.json) echo ".codex/hooks.json" ;;
        *) echo "$1" ;;
    esac
}

# 導入 / upgrade / manifest の対象になるテンプレート側の相対パス一覧(エージェントとプロファイルを適用後)
template_files() {
    local rel d
    {
        for d in .agents .claude .codex; do
            if [[ -d "$SCRIPT_DIR/$d" ]]; then (cd "$SCRIPT_DIR" && find "$d" -type f | sed 's#^\./##'); fi
        done
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
        echo "# blueprint-manifest v2 — generated by setup.sh; used by --upgrade. Do not edit by hand"
        echo "# version: ${BLUEPRINT_VERSION}"
        echo "# commit: ${BLUEPRINT_COMMIT}"
        echo "# profile: $2"
        echo "# agent: $AGENT"
        echo "# links: ${LINK_RESULT:-none}"
        echo "# mirror: $MIRROR_LANG"
        echo "# installed: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        template_files | while IFS= read -r rel; do
            tp="$(target_path "$rel")"
            echo "$(sha256_of "$SCRIPT_DIR/$rel")  $tp"
        done
    } > "$1/$MANIFEST_REL.tmp"
    # 途中で止まっても切れた manifest を残さない(切れると次回の --upgrade が profile / agent を既定値に戻してしまう)
    mv "$1/$MANIFEST_REL.tmp" "$1/$MANIFEST_REL"
}

manifest_hash() {   # <manifest> <target-relative-path>
    awk -v p="$2" '$1 !~ /^#/ && $2 == p {print $1; exit}' "$1"
}

# ── .claude/skills/ と .claude/rules/ を .agents/ へつなぐ ─────────────────
# Claude Code は skill を .claude/skills/<name>/、ルールを .claude/rules/*.md から読む(.agents/ は読まない)。
# 原本は .agents/ に 1 つだけ置き、項目ごとにリンクする(skill ディレクトリ単位のリンクと rules のリンクは公式に対応)。
# コピー方式では「コピーが原本と同じだったもの」だけを更新後に作り直す(PRESYNC)。手で変えたコピーは上書きしない。
PRESYNC=""
RELINK_REFRESH=0   # 1 = --relink。コピー方式では .agents/ を正としてコピーを作り直す

same_tree() { diff -rq "$1" "$2" >/dev/null 2>&1; }

# Claude Code へつなぐ項目を "<kind>/<name>" で列挙する。
#   skills: SKILL.md を持つディレクトリ
#   rules : 直下の *.md(README.md は除く。置くと常時 load される)と、サブディレクトリ(Claude Code は再帰的に読む)
#   .example は無効なサンプルなのでつながない
link_items() {
    local src name
    for src in "$TARGET_DIR/.agents/skills"/*/; do
        [[ -f "${src}SKILL.md" ]] || continue
        echo "skills/$(basename "${src%/}")"
    done
    for src in "$TARGET_DIR/.agents/rules"/*; do
        name="$(basename "$src")"
        if [[ -d "$src" ]]; then
            echo "rules/$name"
        elif [[ -f "$src" && "$name" == *.md && "$name" != "README.md" ]]; then
            echo "rules/$name"
        fi
    done
}

# .claude/<kind> そのものが .agents/<kind> と同じ実体(ディレクトリごとリンクしてある)かどうか
shared_dir() {   # <kind>
    [[ -e "$TARGET_DIR/.claude/$1" && "$TARGET_DIR/.claude/$1" -ef "$TARGET_DIR/.agents/$1" ]]
}

collect_presync() {
    local item dst
    PRESYNC=""
    [[ -d "$TARGET_DIR/.claude" ]] || return 0
    while IFS= read -r item; do
        [[ -n "$item" ]] || continue
        dst="$TARGET_DIR/.claude/$item"
        if [[ ! -L "$dst" && -e "$dst" ]] && same_tree "$TARGET_DIR/.agents/$item" "$dst"; then
            PRESYNC="${PRESYNC}${item}"$'\n'
        fi
    done < <(link_items)
}

link_one() {   # <kind/name>
    local item="$1"
    local src="$TARGET_DIR/.agents/$item" dst="$TARGET_DIR/.claude/$item"
    local reltarget="../../.agents/$item"
    # リンク先と原本が同じ実体なら触らない(消すと原本を消すことになる)
    if [[ -e "$dst" && "$dst" -ef "$src" ]]; then
        if [[ -L "$dst" && "$(readlink "$dst")" == "$reltarget" && "$LINKS" != "copy" ]]; then
            LINK_RESULT="${LINK_RESULT:-symlink}"
            return 0
        fi
        if [[ ! -L "$dst" ]]; then
            LINK_RESULT="${LINK_RESULT:-symlink}"
            return 0
        fi
    fi
    if [[ -L "$dst" ]]; then
        rm -f "$dst"
    elif [[ -e "$dst" ]]; then
        # 実体がある = コピー方式の残り、または利用者が直接置いたもの
        if same_tree "$src" "$dst"; then
            if [[ "$LINKS" == "symlink" ]]; then
                if [[ -d "$dst" ]]; then rm -rf "$dst"; else rm -f "$dst"; fi
            else
                LINK_RESULT="copy"
                return 0
            fi
        elif [[ $RELINK_REFRESH -eq 1 && "$LINKS" == "copy" ]]; then
            # コピー方式の --relink: .agents/ が正。「編集は .agents/ 側で行い --relink で反映」の手順どおりにコピーを作り直す
            echo "  refresh  .claude/$item"
            if [[ -d "$dst" ]]; then rm -rf "$dst"; else rm -f "$dst"; fi
        elif printf '%s' "$PRESYNC" | grep -qxF "$item"; then
            if [[ -d "$dst" ]]; then rm -rf "$dst"; else rm -f "$dst"; fi
        else
            warn "$(t ".claude/$item は .agents/$item と内容が違うため触りません。.agents/ 側へ統合してから --relink してください" \
                      ".claude/$item differs from .agents/$item, so it was left alone. Merge it into .agents/ and run --relink")"
            return 0
        fi
    fi
    if [[ "$LINKS" != "copy" ]] && ln -s "$reltarget" "$dst" 2>/dev/null && [[ -L "$dst" ]]; then
        LINK_RESULT="${LINK_RESULT:-symlink}"
    else
        rm -f "$dst" 2>/dev/null || true
        cp -R "$src" "$dst"
        LINK_RESULT="copy"
    fi
}

ensure_links() {
    local kind item entry
    has_claude || return 0
    [[ -d "$TARGET_DIR/.claude" ]] || return 0
    for kind in skills rules; do
        if shared_dir "$kind"; then
            # .claude/<kind> がディレクトリごと .agents/<kind> を指している。既に共有されているので項目ごとのリンクは作らない
            LINK_RESULT="${LINK_RESULT:-symlink}"
            continue
        fi
        mkdir -p "$TARGET_DIR/.claude/$kind"
        # .agents/ 側から消えた項目へのリンクを掃除する
        for entry in "$TARGET_DIR/.claude/$kind"/*; do
            if [[ -L "$entry" && ! -e "$entry" ]]; then
                case "$(readlink "$entry")" in ../../.agents/*) rm -f "$entry" ;; esac
            fi
        done
    done
    while IFS= read -r item; do
        [[ -n "$item" ]] || continue
        if shared_dir "${item%%/*}"; then continue; fi
        link_one "$item"
    done < <(link_items)
    if [[ "$LINK_RESULT" == "copy" ]]; then
        warn "$(t ".claude/skills/ と .claude/rules/ はコピーで配置しました(シンボリックリンクを作れない環境、または --links copy)。編集は .agents/ 側で行い、bash setup.sh <dir> --relink で反映してください" \
                  ".claude/skills/ and .claude/rules/ were placed as copies (symbolic links unavailable, or --links copy). Edit under .agents/ and apply with bash setup.sh <dir> --relink")"
    fi
}

make_executable() {
    chmod +x "$TARGET_DIR/.agents/hooks/"*.sh "$TARGET_DIR/.agents/hooks/lib/"*.sh "$TARGET_DIR/.agents/scripts/"*.sh 2>/dev/null || true
    chmod +x "$TARGET_DIR/.claude/statusline.sh" 2>/dev/null || true
}

# ── .gitignore にローカル状態を追記 ─────────────────────────
# エージェントがリポジトリ内に作るローカル状態を除外する:
#   testreport/                 ツール直接出力 / 観測フックのログ
#   .agents/skills/*-workspace/ skill-creator の eval 作業ディレクトリ
#   .claude/settings.local.json 個人の allow ルール(共有すると権限が漏れる)
#   .claude/worktrees/          --worktree / isolation: worktree の作業木
#   .claude/agent-memory-local/ memory: local の subagent メモリ
# ファイルの末尾が改行で終わっていなければ改行を足す(そのまま追記すると最終行と連結し、.env などの除外が壊れる)
ensure_trailing_newline() {   # <file>
    if [[ -s "$1" && -n "$(tail -c 1 "$1")" ]]; then
        echo "" >> "$1"
    fi
}

ensure_gitignore() {
    local gitignore="$TARGET_DIR/.gitignore" header entry
    local -a entries=(testreport/ ".agents/skills/*-workspace/")
    if has_claude; then
        entries+=(.claude/settings.local.json .claude/worktrees/ .claude/agent-memory-local/ ".claude/skills/*-workspace/")
    fi
    header="$(t "# コーディングエージェントのローカル状態(AI生成の生データ・個人設定)" "# Coding-agent local state (AI-generated data, personal settings)")"
    if [[ ! -f "$gitignore" ]]; then
        printf '%s\n' "$header" > "$gitignore"
    fi
    ensure_trailing_newline "$gitignore"
    for entry in "${entries[@]}"; do
        if ! grep -qxF "$entry" "$gitignore" 2>/dev/null; then
            if [[ "$entry" == "testreport/" ]] && ! grep -q '^# ' "$gitignore"; then
                echo "" >> "$gitignore"
                echo "$header" >> "$gitignore"
            fi
            echo "$entry" >> "$gitignore"
        fi
    done
}

# 個人の allow ルール。gitignore 済みで、SessionStart フックが未作成を警告する対象
ensure_local_settings() {
    has_claude || return 0
    if [[ -f "$TARGET_DIR/.claude/settings.local.json.template" && ! -f "$TARGET_DIR/.claude/settings.local.json" ]]; then
        cp "$TARGET_DIR/.claude/settings.local.json.template" "$TARGET_DIR/.claude/settings.local.json"
        info "$(t ".claude/settings.local.json を雛形から生成(ビルドツールに合わせて allow を調整してください)" \
                  "Generated .claude/settings.local.json from the template (adjust the allow list to your build tools)")"
    fi
}

# ── --upgrade: 導入済みプロジェクトをテンプレートの版に追従させる ──
run_upgrade() {
    local mf="$TARGET_DIR/$MANIFEST_REL" rel tp th ch mh dst s found
    local added=0 updated=0 unchanged=0 conflicts=0 skipped=0 removed=0
    local -a seen=() conflict_lines=()
    info "$(t "更新" "Upgrade"): ${INSTALLED_VERSION} → ${BLUEPRINT_VERSION}(${BLUEPRINT_COMMIT}, profile: ${PROFILE}, agent: ${AGENT})"
    if [[ $DRY_RUN -eq 1 ]]; then warn "$(t "--dry-run: ファイルは変更しません" "--dry-run: no files will be changed")"; fi
    collect_presync
    while IFS= read -r rel; do
        tp="$(target_path "$rel")"
        mh="$(manifest_hash "$mf" "$tp")"
        if [[ "$tp" == "AGENTS.md" && -e "$TARGET_DIR/AGENTS.blueprint.md" ]]; then tp="AGENTS.blueprint.md"; fi
        seen+=("$tp")
        dst="$TARGET_DIR/$tp"
        th="$(sha256_of "$SCRIPT_DIR/$rel")"
        if [[ "$tp" == "project-config.md" ]]; then
            if [[ -n "$mh" && "$mh" != "$th" ]]; then
                warn "$(t "project-config.md のテンプレートが変わっています(人間が記入するファイルなので上書きしません)。差分" \
                          "The template's project-config.md changed (not overwritten: humans own this file). Diff"): diff ${SCRIPT_DIR}/project-config.md ${TARGET_DIR}/project-config.md"
            fi
            continue
        fi
        if [[ ! -e "$dst" ]]; then
            if [[ -n "$mh" ]]; then
                echo "  skip     $tp  $(t "(ローカルで削除済み。復活させるなら手でコピー)" "(deleted locally; copy by hand to restore)")"; skipped=$((skipped + 1))
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
            echo "  conflict $tp  $(t "(手で変更あり。新版を横に置いた: $tp.blueprint-new)" "(modified locally; new version placed next to it: $tp.blueprint-new)")"; conflicts=$((conflicts + 1))
            if [[ $DRY_RUN -eq 0 ]]; then
                # 前回の .blueprint-new が統合途中で残っているかもしれない。内容が違えば退避してから新版を置く
                if [[ -e "$dst.blueprint-new" ]] && ! cmp -s "$SCRIPT_DIR/$rel" "$dst.blueprint-new"; then
                    mv "$dst.blueprint-new" "$dst.blueprint-new.old"
                    echo "           $(t "(以前の $tp.blueprint-new は $tp.blueprint-new.old に退避)" "(the previous $tp.blueprint-new was kept as $tp.blueprint-new.old)")"
                fi
                cp "$SCRIPT_DIR/$rel" "$dst.blueprint-new"
            fi
            if [[ -n "$mh" ]]; then conflict_lines+=("$mh  $tp"); fi
        fi
    done < <(template_files)
    while IFS= read -r tp; do
        [[ -z "$tp" ]] && continue
        found=0
        for s in "${seen[@]}"; do [[ "$s" == "$tp" ]] && { found=1; break; }; done
        if [[ $found -eq 0 && -e "$TARGET_DIR/$tp" ]]; then
            echo "  removed  $tp  $(t "(テンプレートから削除された。不要なら手で消す)" "(removed from the template; delete by hand if unneeded)")"; removed=$((removed + 1))
        fi
    done < <(awk '$1 !~ /^#/ {print $2}' "$mf")
    if [[ $DRY_RUN -eq 0 ]]; then
        ensure_links
        if [[ -z "$LINK_RESULT" ]]; then
            LINK_RESULT="$(manifest_field links)"
        fi
        write_manifest "$TARGET_DIR" "$PROFILE"
        if [[ ${#conflict_lines[@]} -gt 0 ]]; then
            awk -v list="$(printf '%s\n' "${conflict_lines[@]}")" '
                BEGIN { n = split(list, a, "\n"); for (i = 1; i <= n; i++) { split(a[i], b, "  "); keep[b[2]] = b[1] } }
                $1 !~ /^#/ && ($2 in keep) { print keep[$2] "  " $2; next }
                { print }' "$mf" > "$mf.tmp" && mv "$mf.tmp" "$mf"
        fi
        make_executable
        ensure_local_settings
        ensure_gitignore
    fi
    echo ""
    info "$(t "更新完了: 追加 ${added} / 更新 ${updated} / 変更なし ${unchanged} / 競合 ${conflicts} / スキップ ${skipped} / テンプレートから削除 ${removed}" \
              "Upgrade complete: added ${added} / updated ${updated} / unchanged ${unchanged} / conflicts ${conflicts} / skipped ${skipped} / removed from template ${removed}")"
    if [[ ${conflicts} -gt 0 ]]; then
        warn "$(t "次: 競合は diff <path> <path>.blueprint-new で統合して .blueprint-new を消す。その後 /harness-refine(Codex は \$harness-refine)を回す" \
                  "Next: merge each conflict with diff <path> <path>.blueprint-new and delete the .blueprint-new file, then run /harness-refine (\$harness-refine in Codex)")"
    fi
    return 0
}

# --upgrade / --relink はここで分岐する(以降の install 処理は走らない)
if [[ "$MODE" == "upgrade" ]]; then
    run_upgrade
    exit 0
fi
if [[ "$MODE" == "relink" ]]; then
    if ! has_claude; then
        info "$(t "Claude Code 用アダプタが無いためリンクは不要です(Codex は .agents/skills/ を直接読みます)" \
                  "No Claude Code adapter is installed, so no links are needed (Codex reads .agents/skills/ directly)")"
        exit 0
    fi
    RELINK_REFRESH=1
    collect_presync
    ensure_links
    sed "s/^# links: .*/# links: ${LINK_RESULT:-none}/" "$TARGET_DIR/$MANIFEST_REL" > "$TARGET_DIR/$MANIFEST_REL.tmp" \
        && mv "$TARGET_DIR/$MANIFEST_REL.tmp" "$TARGET_DIR/$MANIFEST_REL"
    info "$(t "リンクを更新しました" "Links refreshed") (.claude/skills/, .claude/rules/ → .agents/, ${LINK_RESULT:-none})"
    exit 0
fi

# ── 既存ディレクトリのバックアップ ──────────────────────────
# 導入は .agents/ と各アダプタを作り直す。既存のものは <dir>.bak/ に退避する
for d in .agents .claude .codex; do
    case "$d" in
        .claude) has_claude || continue ;;
        .codex)  has_codex  || continue ;;
    esac
    if [[ -d "$TARGET_DIR/$d" ]]; then
        BACKUP_DIR="$TARGET_DIR/$d.bak"
        if [[ -e "$BACKUP_DIR" ]]; then
            # 以前のバックアップは消さない(まだ統合していない元の設定の、唯一のコピーかもしれない)
            BACKUP_DIR="$TARGET_DIR/$d.bak.$(date -u +%Y%m%dT%H%M%SZ)"
        fi
        warn "$(t "既存の $d/ をバックアップ" "Backing up existing $d/ to"): ${BACKUP_DIR#"$TARGET_DIR"/}/"
        mv "$TARGET_DIR/$d" "$BACKUP_DIR"
    fi
done

# ── ファイルコピー ──────────────────────────────────────────
info "$(t "ブループリントをコピー中..." "Copying blueprint files...") (agent: ${AGENT}, profile: ${PROFILE})"

# 利用者のファイルを上書きしない。無いものだけ置く(既存プロジェクトへの後付けを安全にする)
copy_if_absent() {   # <template-relative> <target-relative>
    if [[ -e "$TARGET_DIR/$2" ]]; then
        return 1
    fi
    mkdir -p "$(dirname "$TARGET_DIR/$2")"
    cp "$SCRIPT_DIR/$1" "$TARGET_DIR/$2"
}

# docs/ input/ output/ testreport/ — プロジェクト固有の領域。既存ファイルは保持する
for d in docs input output testreport; do
    [[ -d "$SCRIPT_DIR/$d" ]] || continue
    (cd "$SCRIPT_DIR" && find "$d" -type d) | while IFS= read -r sub; do mkdir -p "$TARGET_DIR/$sub"; done
    (cd "$SCRIPT_DIR" && find "$d" -type f ! -name .DS_Store) | while IFS= read -r f; do
        copy_if_absent "$f" "$f" || true
    done
done

# ハーネス本体(.agents/ と各アダプタ)とルート直下のファイル
while IFS= read -r rel; do
    tp="$(target_path "$rel")"
    case "$tp" in
        project-config.md)
            if copy_if_absent "$rel" "$tp"; then
                :
            else
                info "$(t "project-config.md は既に存在するため保持(上書きしない)" "project-config.md already exists, kept (no overwrite)")"
            fi
            ;;
        constitution.md)
            # scan-harness.sh / CLAUDE.md が参照する
            if copy_if_absent "$rel" "$tp"; then
                info "$(t "constitution.md(不変原則)を配置" "constitution.md (immutable principles) placed")"
            else
                info "$(t "constitution.md は既に存在するため保持(上書きしない)" "constitution.md already exists, kept (no overwrite)")"
            fi
            ;;
        REVIEW.md)
            if copy_if_absent "$rel" "$tp"; then
                info "$(t "REVIEW.md(Code Review の審査基準)を配置" "REVIEW.md (Code Review criteria) placed")"
            else
                info "$(t "REVIEW.md は既に存在するため保持(上書きしない)" "REVIEW.md already exists, kept (no overwrite)")"
            fi
            ;;
        .mcp.json.template)
            # 利用者が .mcp.json にリネームして有効化する。既存のカスタマイズは保護する
            if copy_if_absent "$rel" "$tp"; then
                info "$(t ".mcp.json.template を配置(有効化するには .mcp.json にリネーム)" "Placed .mcp.json.template (rename to .mcp.json to activate)")"
            else
                info "$(t ".mcp.json.template は既に存在するため保持(上書きしない)" ".mcp.json.template already exists, preserved (not overwritten)")"
            fi
            ;;
        .github/*)
            # ワークフローの雛形(.template を外して有効化)と手順書。既存ファイルは保持する
            copy_if_absent "$rel" "$tp" || true
            ;;
        AGENTS.md)
            # Codex は直接読み、Claude Code は CLAUDE.md の @AGENTS.md で取り込む。
            # 既存の AGENTS.md は上書きせず、テンプレート版を横に置いて統合を促す。
            if [[ -e "$TARGET_DIR/AGENTS.md" ]] && cmp -s "$SCRIPT_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.md"; then
                info "$(t "AGENTS.md はテンプレートと同一のため保持" "AGENTS.md is identical to the template; kept as is")"
            elif [[ -e "$TARGET_DIR/AGENTS.blueprint.md" ]] && ! cmp -s "$SCRIPT_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.blueprint.md"; then
                # 統合作業中の AGENTS.blueprint.md は上書きしない
                warn "$(t "AGENTS.blueprint.md がテンプレートと異なるため上書きしませんでした(統合作業中の内容を保持)。" \
                          "AGENTS.blueprint.md differs from the template, so it was left untouched (keeping your in-progress merge).")"
                warn "  $(t "最新のテンプレート版" "Latest template version"): $SCRIPT_DIR/AGENTS.md"
            elif [[ -e "$TARGET_DIR/AGENTS.md" ]]; then
                cp "$SCRIPT_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.blueprint.md"
                warn "$(t "既存の AGENTS.md を保持し、テンプレート版を AGENTS.blueprint.md として配置しました。" \
                          "Kept the existing AGENTS.md and placed the template version as AGENTS.blueprint.md.")"
                warn "  $(t "内容を AGENTS.md に統合してから AGENTS.blueprint.md を削除してください(エージェントが読むのは AGENTS.md だけです)" \
                           "Merge it into AGENTS.md, then delete AGENTS.blueprint.md (the agents read AGENTS.md only)")"
            else
                cp "$SCRIPT_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.md"
                info "$(t "AGENTS.md(ツール共通ルール)をプロジェクトルートに配置" "Placed AGENTS.md (tool-agnostic rules) at the project root")"
            fi
            ;;
        CLAUDE.md)
            # 既存の CLAUDE.md(利用者自身の指示)は上書きしない。テンプレート版を横に置いて統合を促す
            if [[ -e "$TARGET_DIR/CLAUDE.md" ]] && ! cmp -s "$SCRIPT_DIR/$rel" "$TARGET_DIR/CLAUDE.md"; then
                cp "$SCRIPT_DIR/$rel" "$TARGET_DIR/CLAUDE.md.blueprint-new"
                warn "$(t "既存の CLAUDE.md を保持し、テンプレート版を CLAUDE.md.blueprint-new として配置しました。" \
                          "Kept the existing CLAUDE.md and placed the template version as CLAUDE.md.blueprint-new.")"
                warn "  $(t "内容を CLAUDE.md に統合してから CLAUDE.md.blueprint-new を削除してください(冒頭の @AGENTS.md の取り込みが無いと、Claude Code は AGENTS.md を読みません)" \
                           "Merge it into CLAUDE.md, then delete CLAUDE.md.blueprint-new (without the @AGENTS.md import at the top, Claude Code does not read AGENTS.md)")"
            else
                cp "$SCRIPT_DIR/$rel" "$TARGET_DIR/CLAUDE.md"
            fi
            ;;
        *)
            mkdir -p "$(dirname "$TARGET_DIR/$tp")"
            cp "$SCRIPT_DIR/$rel" "$TARGET_DIR/$tp"
            ;;
    esac
done < <(template_files)

if has_claude; then
    info "$(t "Claude Code 用アダプタを配置: .claude/ と CLAUDE.md" "Placed the Claude Code adapter: .claude/ and CLAUDE.md")"
    ensure_local_settings
fi
if has_codex; then
    info "$(t "Codex 用アダプタを配置: .codex/(config.toml / hooks.json / rules / agents)" \
              "Placed the Codex adapter: .codex/ (config.toml / hooks.json / rules / agents)")"
    if ! git -C "$TARGET_DIR" rev-parse --show-toplevel &>/dev/null; then
        warn "$(t "ターゲットは git リポジトリではありません。Codex のフックは git のルートを基準に呼ぶため、プロジェクトルート以外から起動するとフックが動きません。git init を推奨します" \
                  "The target is not a git repository. Codex hooks resolve from the git root, so they do not run when Codex starts outside the project root. Running git init is recommended")"
    fi
fi

# ── フックスクリプトを実行可能に設定 ─────────────────────────
make_executable
info "$(t "フックスクリプトを実行可能に設定" "Made hook scripts executable")"

# ── .claude/skills/ と .claude/rules/ を .agents/ へつなぐ ────
ensure_links
if has_claude; then
    info "$(t ".claude/skills/ と .claude/rules/ を .agents/ へ接続" "Linked .claude/skills/ and .claude/rules/ to .agents/") (${LINK_RESULT:-none})"
fi

# ── .gitignore にローカル状態を追記 ─────────────────────────
ensure_gitignore
info "$(t ".gitignore にローカル状態の除外を追記" "Added the local-state entries to .gitignore")"

# ── 導入版の記録(--upgrade の基準) ───────────────────────
write_manifest "$TARGET_DIR" "$PROFILE"
info "$(t "導入版を記録: .agents/blueprint-manifest.txt(更新は bash setup.sh <dir> --upgrade)" \
          "Recorded the installed version in .agents/blueprint-manifest.txt (update later with bash setup.sh <dir> --upgrade)")"

# ── 完了メッセージ ──────────────────────────────────────────
echo ""
info "$(t "セットアップ完了!" "Setup complete!") (agent: ${AGENT}, profile: ${PROFILE})"
echo ""
echo "$(t "次のステップ:" "Next steps:")"
echo "  1. $(t "project-config.md を記入(最低 §1〜§3, §6)" "Fill in project-config.md (at minimum §1-§3 and §6)")"
echo "     vi $TARGET_DIR/project-config.md"
echo ""
STEP=2
if has_claude; then
    echo "  $STEP. $(t "Claude Code で動作確認" "Verify the setup in Claude Code")"
    echo "     cd $TARGET_DIR && claude"
    echo "     /plan $(t "プロジェクトの初期セットアップ状況を確認" "Review the initial project setup status")"
    echo ""
    STEP=$((STEP + 1))
fi
if has_codex; then
    echo "  $STEP. $(t "Codex で動作確認(初回はプロジェクトを信頼し、/hooks でフックを確認して信頼する)" \
                      "Verify the setup in Codex (trust the project on first run, then review and trust the hooks with /hooks)")"
    echo "     cd $TARGET_DIR && codex"
    echo "     \$plan $(t "プロジェクトの初期セットアップ状況を確認" "Review the initial project setup status")"
    echo ""
fi
echo "  $(t "詳細" "Details"): https://github.com/your-org/project-blueprints"
