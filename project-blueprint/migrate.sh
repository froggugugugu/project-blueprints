#!/usr/bin/env bash
# -E: ERR トラップ(失敗時の自動 rollback)を関数の中でも効かせる
set -Eeuo pipefail

# ==============================================================================
# migrate.sh — 0.x の配置(すべて .claude/ 配下)を 1.0 の配置へ移行する / 0.x → 1.0 layout migration
#
# 1.0 は Claude Code と Codex が共有する部分を .agents/ に出し、.claude/ と .codex/ を薄いアダプタにした。
# 0.x で導入したプロジェクトは setup.sh --upgrade では更新できないため、先にこのスクリプトで配置を移す。
# 日英ミラーで同一のファイル(メッセージだけ t "<ja>" "<en>" で切り替える)。
#
# 行うこと(順に):
#   1. 判定      0.x の配置か / 移行済みか / 前回の移行が途中で止まっていないか
#   2. 分類      各ファイルが「テンプレートのまま」か「手で変更あり」かを決める
#                  - 0.x 末期の manifest(.claude/blueprint-manifest.txt)があればそのハッシュ
#                  - 無ければ、このテンプレートの git 履歴にある blob と内容を照合する
#                    (リリース済みの 0.x は manifest を持たないため、これが主経路)
#   3. 退避      .blueprint-migrate-backup/ に .claude/ と書き換えるファイルを保存する
#   4. 移動      .claude/{skills,hooks,rules,scripts,learnings,tasks} と共有文書 → .agents/
#                  利用者が足した skill やフックも一緒に動かす。移動先に同名があれば動かさずに報告する
#   5. 参照修正  移したパスへの参照(.claude/hooks/... など)を .agents/... に書き換える
#                  対象: .agents/ .claude/ CLAUDE.md AGENTS.md project-config.md constitution.md docs/ .github/ .gitignore など
#   6. manifest  新しい形式(.agents/blueprint-manifest.txt)を書く。「テンプレートのまま」のファイルだけ
#                  ハッシュを記録するので、続く更新で上書きされるのはそれらだけになる
#   7. 更新      setup.sh --upgrade を呼ぶ。未変更ファイルを 1.0 の内容に置き換え、Codex 用アダプタなどの
#                  新規ファイルを足し、手で変えたファイルには <path>.blueprint-new を横に置く
#
# 失敗したら自動で元に戻す。成功後も --rollback で戻せる(バックアップを消すまで)。
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIRROR_LANG="ja"; [[ "$(basename "$SCRIPT_DIR")" == *-en ]] && MIRROR_LANG="en"

t() { if [[ "$MIRROR_LANG" == "en" ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    if [[ "$MIRROR_LANG" == "en" ]]; then
        cat <<'EOF'
Usage:
  bash migrate.sh <target-directory> [--dry-run] [--agent claude|codex|both] [--links auto|symlink|copy]
                                     [--assume-pristine] [--allow-dirty]
  bash migrate.sh <target-directory> --rollback

Description:
  Migrates a project installed with Project Blueprint 0.x (everything under .claude/) to the 1.0 layout:
  the shared core moves to .agents/, and .claude/ and .codex/ become thin adapters.

  Run it from a clone of the 1.0 template. The clone needs its git history (not a shallow clone or a zip),
  because files are matched against the template's history to tell untouched files from modified ones.

Options:
  --dry-run          Run the whole migration on a temporary copy and print the result. The project is not changed
  --agent <a>        Which adapters to have after the migration (default: both)
                       claude  keep Claude Code only / codex  Codex only / both  Claude Code and Codex as equals
  --links <mode>     How .claude/skills/ and .claude/rules/ point at .agents/ (default: auto; see setup.sh --help)
  --assume-pristine  Treat every blueprint file as untouched (overwrite all with 1.0). Use only when you never
                     edited the harness, or when the template clone has no history. Your versions stay in the backup
  --allow-dirty      Proceed even though the target has uncommitted changes (not recommended: the migration is
                     easiest to review and to undo as one clean git diff)
  --rollback         Restore the state saved in .blueprint-migrate-backup/ and remove what the migration added

After the migration:
  1. Review the result (git status / git diff)
  2. Merge each <path>.blueprint-new into your modified file, then delete the .blueprint-new file
  3. Run the validation your project uses, then commit
  4. Delete .blueprint-migrate-backup/ once you are sure (it may hold personal settings; it is gitignored)
EOF
    else
        cat <<'EOF'
使い方:
  bash migrate.sh <ターゲットディレクトリ> [--dry-run] [--agent claude|codex|both] [--links auto|symlink|copy]
                                           [--assume-pristine] [--allow-dirty]
  bash migrate.sh <ターゲットディレクトリ> --rollback

説明:
  Project Blueprint 0.x で導入したプロジェクト(すべてが .claude/ 配下)を 1.0 の配置へ移行します。
  共通の核を .agents/ へ移し、.claude/ と .codex/ を薄いアダプタにします。

  1.0 のテンプレートを clone した場所から実行します。clone には git の履歴が必要です(shallow clone や zip は不可)。
  「手を入れていないファイル」と「変更したファイル」を、テンプレートの履歴との照合で見分けるためです。

オプション:
  --dry-run          一時コピー上で移行を最後まで実行し、結果を表示する。プロジェクトは変更しない
  --agent <a>        移行後に持つアダプタ(既定: both)
                       claude  Claude Code だけを維持 / codex  Codex だけ / both  Claude Code と Codex を対等に
  --links <mode>     .claude/skills/ と .claude/rules/ を .agents/ へつなぐ方式(既定: auto。setup.sh --help 参照)
  --assume-pristine  ブループリントのファイルをすべて「未変更」とみなす(全部を 1.0 で上書きする)。ハーネスを
                     一度も編集していない場合か、テンプレートの clone に履歴が無い場合だけ使う。元の版はバックアップに残る
  --allow-dirty      未コミットの変更があっても進める(非推奨。移行は 1 つのきれいな git 差分にしておくと、
                     確認も取り消しも簡単になる)
  --rollback         .blueprint-migrate-backup/ に保存した状態へ戻し、移行で増えたものを取り除く

移行後の手順:
  1. 結果を確認する(git status / git diff)
  2. <path>.blueprint-new を、変更していた元ファイルへ統合してから .blueprint-new を消す
  3. プロジェクトの検証を実行してからコミットする
  4. 問題が無いと確認できたら .blueprint-migrate-backup/ を消す(個人設定を含みうる。gitignore 済み)
EOF
    fi
    exit 1
}

# ── 引数解析 ────────────────────────────────────────────────
AGENT="both"
LINKS=""
DRY_RUN=0
ASSUME_PRISTINE=0
ALLOW_DIRTY=0
ROLLBACK=0
TARGET_DIR=""
INNER="${BLUEPRINT_MIGRATE_INNER:-0}"   # 1 = --dry-run が一時コピー上で呼び直した実行

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent)           AGENT="${2:-}"; shift 2 ;;
        --agent=*)         AGENT="${1#*=}"; shift ;;
        --links)           LINKS="${2:-}"; shift 2 ;;
        --links=*)         LINKS="${1#*=}"; shift ;;
        --dry-run)         DRY_RUN=1; shift ;;
        --assume-pristine) ASSUME_PRISTINE=1; shift ;;
        --allow-dirty)     ALLOW_DIRTY=1; shift ;;
        --rollback)        ROLLBACK=1; shift ;;
        -h|--help)         usage ;;
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

[[ -n "$TARGET_DIR" ]] || usage
case "$AGENT" in
    claude|codex|both) ;;
    *) error "$(t "不正なエージェント: $AGENT (claude / codex / both のいずれか)" "Invalid agent: $AGENT (must be claude, codex, or both)")"; usage ;;
esac
case "$LINKS" in
    ""|auto|symlink|copy) ;;
    *) error "$(t "不正なリンク方式: $LINKS (auto / symlink / copy のいずれか)" "Invalid link mode: $LINKS (must be auto, symlink, or copy)")"; usage ;;
esac
if [[ ! -d "$TARGET_DIR" ]]; then
    error "$(t "ターゲットディレクトリがありません: $TARGET_DIR" "Target directory does not exist: $TARGET_DIR")"
    exit 1
fi
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# --rollback は実際に戻す操作で、計画表示は無い。--dry-run と一緒に指定されたら黙って実行せずに止める
if [[ $ROLLBACK -eq 1 && $DRY_RUN -eq 1 ]]; then
    error "$(t "--rollback と --dry-run は一緒に使えません(--rollback は実際に元へ戻します)" "--rollback and --dry-run cannot be combined (--rollback really restores the project)")"
    exit 1
fi
if [[ "$TARGET_DIR" -ef "$SCRIPT_DIR" ]]; then
    error "$(t "ターゲットがテンプレート自身です。移行するプロジェクトを指定してください" "The target is the template itself. Point at the project to migrate")"
    exit 1
fi
# ハーネスのディレクトリがシンボリックリンクだと、退避はリンクだけを写し、移動はリンク先の実体から中身を抜いてしまう
# (dotfiles 管理などで .claude をリンクにしている場合)。リンク先を壊さないよう、何もせずに止める
for d in .claude .agents .codex; do
    if [[ -L "$TARGET_DIR/$d" ]]; then
        error "$(t "$d がシンボリックリンクです。実体のディレクトリにしてから実行してください(リンク先を壊さないため、何も変更していません)" \
                   "$d is a symbolic link. Make it a real directory first (nothing was changed, to keep the link target intact)")"
        exit 1
    fi
done

BACKUP_REL=".blueprint-migrate-backup"
BACKUP_DIR="$TARGET_DIR/$BACKUP_REL"
JOURNAL="$BACKUP_DIR/journal"
NEW_MANIFEST_REL=".agents/blueprint-manifest.txt"
OLD_MANIFEST_REL=".claude/blueprint-manifest.txt"

# 移すもの: .claude/<これ> → .agents/<これ>
MOVE_DIRS=(skills hooks rules scripts learnings tasks)
MOVE_FILES=(guardrails.md quality-gates.md pitfalls.md .constitution.sha256)
# 参照を書き換える sed 式(移したパスだけを対象にする。.claude/settings.json や .claude/agents/ は動かない)
SED_DIR_SLASH='s#\.claude/(skills|hooks|rules|scripts|learnings|tasks)/#.agents/\1/#g'
SED_DIR_END='s#\.claude/(skills|hooks|rules|scripts|learnings|tasks)([^A-Za-z0-9_/-]|$)#.agents/\1\2#g'
SED_FILES='s#\.claude/(guardrails\.md|quality-gates\.md|pitfalls\.md|\.constitution\.sha256|blueprint-manifest\.txt)#.agents/\1#g'
# ホームディレクトリ側の Claude Code 設定(~/.claude/skills/ など)はプロジェクトの移動対象ではない。
# 書き換えの前に目印へ退避し、あとで戻す
SED_HOME_HIDE='s#(~|\$HOME|\$\{HOME\})/\.claude/#\1/.@@BLUEPRINT_HOME_CLAUDE@@/#g'
SED_HOME_SHOW='s#/\.@@BLUEPRINT_HOME_CLAUDE@@/#/.claude/#g'
REF_RE='\.claude/(skills|hooks|rules|scripts|learnings|tasks|guardrails\.md|quality-gates\.md|pitfalls\.md|\.constitution\.sha256|blueprint-manifest\.txt)'
# ルート直下で参照を書き換える対象
ROOT_FILES=(CLAUDE.md CLAUDE.local.md AGENTS.md AGENTS.blueprint.md REVIEW.md project-config.md constitution.md .gitignore .mcp.json .mcp.json.template)

# ファイルの末尾が改行で終わっていなければ改行を足す(そのまま追記すると最終行と連結し、.env などの除外が壊れる)
ensure_trailing_newline() {   # <file>
    if [[ -s "$1" && -n "$(tail -c 1 "$1")" ]]; then
        echo "" >> "$1"
    fi
}

sha256_of() {
    if command -v shasum &>/dev/null; then shasum -a 256 "$1" | cut -d' ' -f1
    elif command -v sha256sum &>/dev/null; then sha256sum "$1" | cut -d' ' -f1
    else cksum "$1" | cut -d' ' -f1; fi
}

# ── --rollback ──────────────────────────────────────────────
# journal の形式(1 行 1 件):
#   had <dir>        移行前に存在したディレクトリ(.claude / .agents / .codex)。バックアップから丸ごと戻す
#   saved <path>     移行が変えうるファイル(.claude/ .agents/ .codex/ の外)。backup/files/<path> から戻す
#   created <path>   移行で新しくできたファイル(同上の外)。消す
#   newdir <dir>     移行前に無かったディレクトリ(.github など)。空になっていたら消す
#
# この関数は `do_rollback || ...` の形でも呼ばれる。その文脈では set -e が効かないので、各操作の失敗を
# 自分で数える。1 つでも失敗したらバックアップを消さずに戻る(唯一の元データを失わないため)
do_rollback() {
    local d line kind path failed=0
    if [[ ! -f "$JOURNAL" ]]; then
        error "$(t "バックアップがありません: $BACKUP_REL/journal(移行前か、既に消されています)" "No backup found: $BACKUP_REL/journal (not migrated yet, or already deleted)")"
        return 1
    fi
    info "$(t "移行前の状態へ戻します" "Restoring the pre-migration state")"
    for d in .claude .agents .codex; do
        if [[ -e "$TARGET_DIR/$d" || -L "$TARGET_DIR/$d" ]]; then
            rm -rf "${TARGET_DIR:?}/$d" || failed=1
        fi
        if grep -qxF "had $d" "$JOURNAL"; then
            if [[ -e "$TARGET_DIR/$d" ]]; then
                failed=1   # 消し切れなかった場所へ cp -R すると <dir>/<dir> の入れ子になる
            else
                cp -R "$BACKUP_DIR/$d" "$TARGET_DIR/$d" || failed=1
            fi
        fi
    done
    while IFS= read -r line; do
        kind="${line%% *}"
        path="${line#* }"
        case "$kind" in
            saved)
                if [[ -f "$BACKUP_DIR/files/$path" ]]; then
                    { mkdir -p "$(dirname "$TARGET_DIR/$path")" && cp -p "$BACKUP_DIR/files/$path" "$TARGET_DIR/$path"; } || failed=1
                fi
                ;;
            created)
                rm -f "$TARGET_DIR/$path" || failed=1
                ;;
        esac
    done < "$JOURNAL"
    while IFS= read -r line; do
        if [[ "${line%% *}" == "newdir" ]]; then rmdir "$TARGET_DIR/${line#* }" 2>/dev/null || true; fi
    done < "$JOURNAL"
    if [[ $failed -ne 0 ]]; then
        error "$(t "一部を戻せませんでした。バックアップ($BACKUP_REL/)は残しています。原因(権限・空き容量)を解消してから、もう一度 --rollback を実行してください" \
                   "Some items could not be restored. The backup ($BACKUP_REL/) was kept. Fix the cause (permissions, disk space) and run --rollback again")"
        return 1
    fi
    rm -rf "${BACKUP_DIR:?}"
    info "$(t "戻しました。バックアップ($BACKUP_REL/)は削除しました" "Restored. The backup ($BACKUP_REL/) was removed")"
    return 0
}

if [[ $ROLLBACK -eq 1 ]]; then
    do_rollback
    exit $?
fi

# ── 1. 判定 ──────────────────────────────────────────────────
if [[ -f "$TARGET_DIR/$NEW_MANIFEST_REL" && -d "$BACKUP_DIR" ]] \
    && grep -qxF "# commit: migrated" "$TARGET_DIR/$NEW_MANIFEST_REL"; then
    # 新しい manifest は書いたが、続く更新(setup.sh --upgrade)が終わる前に止まった状態
    error "$(t "前回の移行が途中で止まっています(配置は移したが、1.0 の内容への更新が終わっていません)。先に元へ戻してください:" \
               "A previous migration stopped midway (the layout was moved but the update to 1.0 did not finish). Restore the project first:")"
    error "  bash $SCRIPT_DIR/migrate.sh $TARGET_DIR --rollback"
    exit 1
fi
if [[ -f "$TARGET_DIR/$NEW_MANIFEST_REL" ]]; then
    info "$(t "このプロジェクトは移行済みです(.agents/blueprint-manifest.txt があります)。以後の更新は setup.sh --upgrade を使ってください" \
              "This project is already migrated (.agents/blueprint-manifest.txt exists). Use setup.sh --upgrade from now on")"
    if [[ -d "$BACKUP_DIR" ]]; then
        info "$(t "移行前のバックアップが残っています: $BACKUP_REL/(戻すなら --rollback、不要なら削除)" \
                  "The pre-migration backup is still there: $BACKUP_REL/ (--rollback to restore, or delete it)")"
    fi
    exit 0
fi
if [[ -d "$BACKUP_DIR" ]]; then
    error "$(t "前回の移行が途中で止まっています($BACKUP_REL/ が残っています)。先に元へ戻してください:" \
               "A previous migration stopped midway ($BACKUP_REL/ is present). Restore the project first:")"
    error "  bash $SCRIPT_DIR/migrate.sh $TARGET_DIR --rollback"
    exit 1
fi
# setup.sh の is_legacy_layout と同じ条件にする(片方だけが 0.x と判定すると、どちらのスクリプトでも進めなくなる)
is_legacy_layout() {
    [[ -f "$TARGET_DIR/$OLD_MANIFEST_REL" ]] && return 0
    [[ -f "$TARGET_DIR/.claude/hooks/safety-check.sh" ]] \
        && [[ -d "$TARGET_DIR/.claude/skills" || -f "$TARGET_DIR/.claude/quality-gates.md" ]]
}
if ! is_legacy_layout; then
    error "$(t "0.x のブループリントが見つかりません(.claude/hooks/safety-check.sh と、.claude/skills/ か .claude/quality-gates.md が必要)。新規導入は setup.sh を使ってください" \
               "No 0.x blueprint found (.claude/hooks/safety-check.sh plus .claude/skills/ or .claude/quality-gates.md are required). Use setup.sh for a fresh install")"
    exit 1
fi
if [[ ! -f "$SCRIPT_DIR/setup.sh" || ! -d "$SCRIPT_DIR/.agents" ]]; then
    error "$(t "テンプレートが 1.0 の配置ではありません($SCRIPT_DIR に .agents/ がありません)" "The template is not in the 1.0 layout (no .agents/ in $SCRIPT_DIR)")"
    exit 1
fi

IS_GIT=0
if git -C "$TARGET_DIR" rev-parse --is-inside-work-tree &>/dev/null; then IS_GIT=1; fi
if [[ $INNER -eq 0 ]]; then
    if [[ $IS_GIT -eq 1 ]]; then
        if [[ -n "$(git -C "$TARGET_DIR" status --porcelain 2>/dev/null)" ]]; then
            if [[ $ALLOW_DIRTY -eq 1 || $DRY_RUN -eq 1 ]]; then
                warn "$(t "未コミットの変更があります。移行の差分と混ざります" "The target has uncommitted changes. They will be mixed with the migration diff")"
            else
                error "$(t "未コミットの変更があります。コミットか stash してから実行してください(そのまま進めるなら --allow-dirty)" \
                           "The target has uncommitted changes. Commit or stash them first (or pass --allow-dirty to proceed anyway)")"
                exit 1
            fi
        fi
    else
        warn "$(t "ターゲットは git リポジトリではありません。取り消しは --rollback だけになります" \
                  "The target is not a git repository. --rollback is the only way to undo")"
    fi
fi

# ── --dry-run: 一時コピー上で最後まで実行する ───────────────
# 計画を「予測」で表示すると実際の結果とずれる。関係するファイルだけを一時ディレクトリへ写し、
# そこで本物の移行を走らせて出力を見せる。プロジェクト本体には触らない
if [[ $DRY_RUN -eq 1 ]]; then
    TMP_ROOT="$(mktemp -d)"
    TMP_PROJ="$TMP_ROOT/project"
    mkdir -p "$TMP_PROJ"
    for item in .claude .agents .codex .github docs "${ROOT_FILES[@]}"; do
        if [[ -e "$TARGET_DIR/$item" ]]; then cp -R "$TARGET_DIR/$item" "$TMP_PROJ/$item"; fi
    done
    warn "$(t "--dry-run: 一時コピー上で移行を実行します。プロジェクトは変更しません" "--dry-run: running the migration on a temporary copy. The project is not changed")"
    INNER_ARGS=("$TMP_PROJ" --agent "$AGENT")
    [[ -n "$LINKS" ]] && INNER_ARGS+=(--links "$LINKS")
    [[ $ASSUME_PRISTINE -eq 1 ]] && INNER_ARGS+=(--assume-pristine)
    set +e
    BLUEPRINT_MIGRATE_INNER=1 bash "${BASH_SOURCE[0]}" "${INNER_ARGS[@]}" 2>&1 | while IFS= read -r line; do
        printf '%s\n' "${line//"$TMP_PROJ"/$TARGET_DIR}"
    done
    RC=${PIPESTATUS[0]}
    set -e
    rm -rf "${TMP_ROOT:?}"
    echo ""
    warn "$(t "--dry-run 終了: 上は一時コピーでの結果です。実行するには --dry-run を外してください" \
              "--dry-run finished: the output above comes from the temporary copy. Drop --dry-run to apply it")"
    exit "$RC"
fi

WORK="$(mktemp -d)"
cleanup() { rm -rf "${WORK:?}"; }
trap cleanup EXIT

# ── 2. 分類: テンプレートのまま(pristine)か、手で変更あり(modified)か ──────────
# 候補 = ブループリントが配ったファイルがありうる場所。利用者の独自ファイルも含まれるが、
# それらはテンプレートの履歴に無いので modified 扱いになり、上書きされない
(
    cd "$TARGET_DIR"
    find .claude -type f \
        ! -path '.claude/worktrees/*' ! -path '.claude/agent-memory*' ! -name 'settings.local.json' ! -name '.DS_Store' \
        ! -name 'blueprint-manifest.txt' 2>/dev/null || true
    for f in CLAUDE.md AGENTS.md REVIEW.md constitution.md .mcp.json.template; do
        if [[ -f "$f" ]]; then echo "$f"; fi
    done
    if [[ -d .github ]]; then find .github -type f \( -name '*.template' -o -name '*.md' \) 2>/dev/null || true; fi
) | sed 's#^\./##' | LC_ALL=C sort > "$WORK/candidates.txt"
CAND_COUNT="$(wc -l < "$WORK/candidates.txt" | tr -d ' ')"
: > "$WORK/pristine.txt"

# 旧 manifest は参照修正で書き換わり、最後に消える。分類と新 manifest への引き継ぎには、移行前の写しを使う
OLD_MANIFEST=""
if [[ -f "$TARGET_DIR/$OLD_MANIFEST_REL" ]]; then
    OLD_MANIFEST="$WORK/old-manifest.txt"
    cp "$TARGET_DIR/$OLD_MANIFEST_REL" "$OLD_MANIFEST"
fi

OLD_VERSION="0.x"
CLASSIFY_BY=""
wrong_mirror() {   # <other-mirror-dir-name>
    error "$(t "このプロジェクトはもう一方のミラー($1)から導入されています。そちらの migrate.sh を使ってください:" \
               "This project was installed from the other mirror ($1). Use that mirror's migrate.sh:")"
    error "  bash $(cd "$SCRIPT_DIR/.." && pwd)/$1/migrate.sh $TARGET_DIR"
    exit 1
}
if [[ $ASSUME_PRISTINE -eq 1 ]]; then
    cp "$WORK/candidates.txt" "$WORK/pristine.txt"
    CLASSIFY_BY="$(t "--assume-pristine(すべて未変更とみなす)" "--assume-pristine (everything treated as untouched)")"
elif [[ -n "$OLD_MANIFEST" ]]; then
    # 0.x 末期の manifest: 記録時のハッシュと今の内容が同じなら未変更
    OLD_VERSION="$(sed -n 's/^# version: //p' "$OLD_MANIFEST" | head -1)"
    [[ -n "$OLD_VERSION" ]] || OLD_VERSION="0.x"
    OLD_MIRROR="$(sed -n 's/^# mirror: //p' "$OLD_MANIFEST" | head -1)"
    if [[ -n "$OLD_MIRROR" && "$OLD_MIRROR" != "$MIRROR_LANG" && $ASSUME_PRISTINE -eq 0 ]]; then
        if [[ "$OLD_MIRROR" == "en" ]]; then wrong_mirror "project-blueprint-en"; else wrong_mirror "project-blueprint"; fi
    fi
    while IFS= read -r rel; do
        mh="$(awk -v p="$rel" '$1 !~ /^#/ && $2 == p {print $1; exit}' "$OLD_MANIFEST")"
        if [[ -n "$mh" && "$mh" == "$(sha256_of "$TARGET_DIR/$rel")" ]]; then echo "$rel" >> "$WORK/pristine.txt"; fi
    done < "$WORK/candidates.txt"
    CLASSIFY_BY="$(t "導入時の manifest(.claude/blueprint-manifest.txt)" "the install-time manifest (.claude/blueprint-manifest.txt)")"
else
    # manifest が無い(リリース済みの 0.x)。テンプレートの git 履歴に現れた「blob とパスの組」と照合する。
    # 過去のどの版でも、同じパスに同じ内容があれば「テンプレートのまま」とみなせる。パスも見るのは、空にしたフックのような
    # 利用者のファイルが、履歴中の別のファイル(空の .gitkeep など)と内容だけ一致して上書きされるのを防ぐため
    template_pairs() {   # <mirror-dir> → "<blob>\t<path>"(パスはミラーのルートからの相対)
        git -C "$1" log --all --format= --raw --no-abbrev --no-renames --relative -- . 2>/dev/null \
            | awk -F'\t' '/^:/ { split($1, m, " "); print m[4] "\t" $2; print m[3] "\t" $2 }' | LC_ALL=C sort -u
    }
    # 候補(blob\tパス)のうち、テンプレートの同じパスに同じ blob があるものを出す。
    # 導入時に名前が変わる 2 つを読み替える: CLAUDE.md ← .claude/CLAUDE.md、settings.json ← settings.minimal.json(minimal プロファイル)
    match_pairs() {   # <pairs-file> <cand-map-file>
        awk -F'\t' 'NR == FNR { known[$0] = 1; next }
            {
                tp = $2
                if ($2 == "CLAUDE.md") tp = ".claude/CLAUDE.md"
                if (($1 "\t" tp) in known || ($2 == ".claude/settings.json" && ($1 "\t.claude/settings.minimal.json") in known)) print $2
            }' "$1" "$2"
    }
    HAVE_HISTORY=0
    if command -v git &>/dev/null && git -C "$SCRIPT_DIR" rev-parse --git-dir &>/dev/null; then
        template_pairs "$SCRIPT_DIR" > "$WORK/pairs.txt" || true
        if [[ -s "$WORK/pairs.txt" ]]; then HAVE_HISTORY=1; fi
    fi
    if [[ $HAVE_HISTORY -eq 1 && $CAND_COUNT -gt 0 ]]; then
        (cd "$TARGET_DIR" && git hash-object --stdin-paths < "$WORK/candidates.txt") > "$WORK/cand-blobs.txt"
        paste "$WORK/cand-blobs.txt" "$WORK/candidates.txt" > "$WORK/cand-map.txt"
        match_pairs "$WORK/pairs.txt" "$WORK/cand-map.txt" > "$WORK/pristine.txt"
        CLASSIFY_BY="$(t "テンプレートの git 履歴との照合" "matching against the template's git history")"
        # 日英で内容が同じファイル(JSON やスクリプト)は両方に一致する。もう一方のミラーへの一致の方が多ければ、
        # そちらから導入したプロジェクトなので、このミラーで移行すると全ファイルが「変更あり」になってしまう
        OTHER="project-blueprint-en"; [[ "$MIRROR_LANG" == "en" ]] && OTHER="project-blueprint"
        if [[ -d "$SCRIPT_DIR/../$OTHER" ]]; then
            template_pairs "$SCRIPT_DIR/../$OTHER" > "$WORK/other-pairs.txt" || true
            OTHER_HITS="$(match_pairs "$WORK/other-pairs.txt" "$WORK/cand-map.txt" | wc -l | tr -d ' ')"
            OWN_HITS="$(wc -l < "$WORK/pristine.txt" | tr -d ' ')"
            if [[ "$OTHER_HITS" -gt "$OWN_HITS" ]]; then
                wrong_mirror "$OTHER"
            fi
        fi
    else
        CLASSIFY_BY="$(t "判定不能(テンプレートの git 履歴が無い)" "not possible (the template clone has no git history)")"
        warn "$(t "テンプレートの git 履歴を読めないため、どのファイルが未変更かを判定できません。すべて「変更あり」として扱い、新版を <path>.blueprint-new に置きます。" \
                  "The template's git history is unavailable, so untouched files cannot be told apart. Every file is treated as modified and the new versions go to <path>.blueprint-new.")"
        warn "$(t "  履歴つきで clone し直すか、ハーネスを編集していないなら --assume-pristine を付けてください" \
                  "  Clone the template with its history, or pass --assume-pristine if you never edited the harness")"
    fi
fi
PRISTINE_COUNT="$(wc -l < "$WORK/pristine.txt" | tr -d ' ')"
MODIFIED_COUNT=$((CAND_COUNT - PRISTINE_COUNT))

is_pristine() { grep -qxF "$1" "$WORK/pristine.txt"; }

# プロファイル: manifest があればその値、無ければ残っているファイルから推定する
PROFILE=""
if [[ -n "$OLD_MANIFEST" ]]; then
    PROFILE="$(sed -n 's/^# profile: //p' "$OLD_MANIFEST" | head -1)"
fi
case "$PROFILE" in
    minimal|standard|full) ;;
    *)
        SKILL_COUNT="$( { find "$TARGET_DIR/.claude/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true; } | wc -l | tr -d ' ')"
        if [[ -d "$TARGET_DIR/.claude/teams" ]]; then
            PROFILE="full"
        elif [[ "$SKILL_COUNT" -le 5 && ! -d "$TARGET_DIR/.claude/skills/security-scan" ]]; then
            PROFILE="minimal"
        else
            PROFILE="standard"
        fi
        ;;
esac

info "$(t "移行: $OLD_VERSION の配置 → 1.0 の配置" "Migration: $OLD_VERSION layout → 1.0 layout") (profile: $PROFILE, agent: $AGENT)"
info "$(t "ターゲット" "Target"): $TARGET_DIR"
info "$(t "未変更の判定" "Untouched-file detection"): $CLASSIFY_BY"
info "$(t "  対象 ${CAND_COUNT} 件 = テンプレートのまま ${PRISTINE_COUNT} 件(1.0 で上書き)/ 変更あり・独自 ${MODIFIED_COUNT} 件(保持)" \
          "  ${CAND_COUNT} files = ${PRISTINE_COUNT} untouched (overwritten with 1.0) / ${MODIFIED_COUNT} modified or your own (kept)")"

# ── 3. 退避 ──────────────────────────────────────────────────
# ここから先で失敗したら自動で元に戻す
on_error() {
    local rc=$?
    # サブシェル内の失敗はそのまま親へ返す(rollback は親で 1 回だけ行う)
    if [[ $BASH_SUBSHELL -gt 0 ]]; then exit "$rc"; fi
    trap - ERR
    journal_created || true
    error "$(t "移行に失敗しました(exit $rc)。元の状態へ戻します" "The migration failed (exit $rc). Restoring the previous state")"
    do_rollback || error "$(t "自動で戻せませんでした。$BACKUP_REL/ から手で復元してください" "Automatic restore failed. Restore by hand from $BACKUP_REL/")"
    exit 1
}
trap on_error ERR
# Ctrl-C・kill・端末を閉じたときも同じように戻す(ERR トラップはシグナルでは動かない)
on_signal() {
    trap - ERR INT TERM HUP
    echo ""
    error "$(t "中断されました。元の状態へ戻します" "Interrupted. Restoring the previous state")"
    journal_created || true
    do_rollback || error "$(t "自動で戻せませんでした。bash migrate.sh <dir> --rollback を実行してください" "Automatic restore failed. Run bash migrate.sh <dir> --rollback")"
    exit 130
}
trap on_signal INT TERM HUP

mkdir -p "$BACKUP_DIR/files"
: > "$JOURNAL"
# 移行(続く更新)が作るかもしれないディレクトリ。移行前に無ければ、rollback で空になったときに消す
for d in .github/workflows .github; do
    if [[ ! -d "$TARGET_DIR/$d" ]]; then echo "newdir $d" >> "$JOURNAL"; fi
done
for d in .claude .agents .codex; do
    if [[ -d "$TARGET_DIR/$d" ]]; then
        cp -R "$TARGET_DIR/$d" "$BACKUP_DIR/$d"
        echo "had $d" >> "$JOURNAL"
    fi
done
cat > "$BACKUP_DIR/README.txt" <<EOF
$(t "Project Blueprint の移行前バックアップ(migrate.sh が作成)。" "Pre-migration backup created by Project Blueprint migrate.sh.")
$(t "戻す" "Restore"): bash <template>/migrate.sh <project> --rollback
$(t "移行結果を確認できたら、このディレクトリは削除してよい(個人設定を含みうるためコミットしない)。" "Delete this directory once the migration is confirmed (it may hold personal settings; do not commit it).")
EOF

# .claude/ .agents/ .codex/ の外にあるファイルを変える前に呼ぶ(初回だけ退避する)
backup_file() {   # <target-relative-path>
    case "$1" in .claude/*|.agents/*|.codex/*) return 0 ;; esac
    [[ -f "$TARGET_DIR/$1" ]] || return 0
    if grep -qxF "saved $1" "$JOURNAL"; then return 0; fi
    mkdir -p "$(dirname "$BACKUP_DIR/files/$1")"
    cp -p "$TARGET_DIR/$1" "$BACKUP_DIR/files/$1"
    echo "saved $1" >> "$JOURNAL"
}
# ルート直下と .github/ のテンプレート由来ファイルは、参照修正が無くても続く更新で上書きされうる。先に退避する
while IFS= read -r rel; do
    backup_file "$rel"
done < "$WORK/candidates.txt"

# 更新で増えるファイルを rollback で消せるよう、移行前に存在したファイルの一覧を取っておく
snapshot_outside() {
    (
        cd "$TARGET_DIR"
        find . -maxdepth 1 -type f 2>/dev/null || true
        if [[ -d .github ]]; then find .github -type f 2>/dev/null || true; fi
    ) | sed 's#^\./##' | LC_ALL=C sort
}
snapshot_outside > "$WORK/before.txt"
# 以前の更新が置いた <path>.blueprint-new(統合途中かもしれない)も、続く更新で置き換わりうるので退避する
while IFS= read -r rel; do
    case "$rel" in *.blueprint-new) backup_file "$rel" ;; esac
done < "$WORK/before.txt"
journal_created() {
    snapshot_outside > "$WORK/after.txt"
    LC_ALL=C comm -13 "$WORK/before.txt" "$WORK/after.txt" | while IFS= read -r rel; do
        if ! grep -qxF "created $rel" "$JOURNAL"; then echo "created $rel" >> "$JOURNAL"; fi
    done
}

# バックアップは個人設定(settings.local.json)を含みうる。誤ってコミットされないよう先に除外する
if [[ -f "$TARGET_DIR/.gitignore" ]]; then
    backup_file .gitignore
else
    : > "$TARGET_DIR/.gitignore"
fi
ensure_trailing_newline "$TARGET_DIR/.gitignore"
if ! grep -qxF "$BACKUP_REL/" "$TARGET_DIR/.gitignore"; then
    echo "$BACKUP_REL/" >> "$TARGET_DIR/.gitignore"
fi

# constitution.md のハッシュが移行前に一致していたか(一致していた場合だけ、書き換え後に取り直す)
CONSTITUTION_OK=0
if [[ -f "$TARGET_DIR/constitution.md" && -f "$TARGET_DIR/.claude/.constitution.sha256" ]] \
    && [[ "$(sha256_of "$TARGET_DIR/constitution.md")" == "$(tr -d '[:space:]' < "$TARGET_DIR/.claude/.constitution.sha256")" ]]; then
    CONSTITUTION_OK=1
fi

# ── 4. 移動 ──────────────────────────────────────────────────
MOVED=0
MOVE_CONFLICTS=0
: > "$WORK/move-conflicts.txt"
: > "$WORK/unmoved.txt"

move_one() {   # <old-relative> <new-relative>
    if [[ -e "$TARGET_DIR/$2" || -L "$TARGET_DIR/$2" ]]; then
        echo "$1 → $2" >> "$WORK/move-conflicts.txt"
        echo "$1" >> "$WORK/unmoved.txt"
        MOVE_CONFLICTS=$((MOVE_CONFLICTS + 1))
        return 0
    fi
    mkdir -p "$(dirname "$TARGET_DIR/$2")"
    mv "$TARGET_DIR/$1" "$TARGET_DIR/$2"
    MOVED=$((MOVED + 1))
}

for d in "${MOVE_DIRS[@]}"; do
    [[ -d "$TARGET_DIR/.claude/$d" && ! -L "$TARGET_DIR/.claude/$d" ]] || continue
    while IFS= read -r rel; do
        move_one ".claude/$d/$rel" ".agents/$d/$rel"
    done < <(cd "$TARGET_DIR/.claude/$d" && find . \( -type f -o -type l \) | sed 's#^\./##' | LC_ALL=C sort)
    # 空になったディレクトリを片付ける(移動先に同名があって残したファイルがあれば、その親は残る)
    find "$TARGET_DIR/.claude/$d" -depth -type d -empty -exec rmdir {} \; 2>/dev/null || true
done
for f in "${MOVE_FILES[@]}"; do
    if [[ -f "$TARGET_DIR/.claude/$f" ]]; then move_one ".claude/$f" ".agents/$f"; fi
done
mkdir -p "$TARGET_DIR/.agents"
info "$(t "移動" "Moved"): ${MOVED} $(t "件" "files") (.claude/{$(IFS=,; echo "${MOVE_DIRS[*]}")} + $(t "共有文書" "shared documents") → .agents/)"

# 旧パス → 新パス(manifest の変換と分類の引き当てに使う)
new_path() {
    local p="$1" d f
    for d in "${MOVE_DIRS[@]}"; do
        case "$p" in ".claude/$d/"*) echo ".agents/${p#.claude/}"; return 0 ;; esac
    done
    for f in "${MOVE_FILES[@]}"; do
        if [[ "$p" == ".claude/$f" ]]; then echo ".agents/$f"; return 0; fi
    done
    echo "$p"
}

# ── 5. 参照修正 ──────────────────────────────────────────────
REWRITTEN=0
: > "$WORK/rewritten.txt"
rewrite_refs() {   # <target-relative-path>
    local f="$TARGET_DIR/$1"
    [[ -f "$f" && ! -L "$f" ]] || return 0
    # バイナリは対象外(grep -I はバイナリを一致なしとして扱う)
    LC_ALL=C grep -IqE "$REF_RE" "$f" 2>/dev/null || return 0
    # LC_ALL=C: バイト単位で処理する(UTF-8 でないファイルがあっても sed が「不正なバイト列」で止まらない)
    LC_ALL=C sed -E -e "$SED_HOME_HIDE" -e "$SED_DIR_SLASH" -e "$SED_DIR_END" -e "$SED_FILES" -e "$SED_HOME_SHOW" "$f" > "$WORK/rewrite.tmp"
    # ホーム側の参照しか無かったファイルは変わらない。変わるときだけ退避して書き戻す
    if cmp -s "$WORK/rewrite.tmp" "$f"; then return 0; fi
    backup_file "$1"
    # cat で書き戻す(実行権限とファイル自体を保つ)
    cat "$WORK/rewrite.tmp" > "$f"
    echo "$1" >> "$WORK/rewritten.txt"
    REWRITTEN=$((REWRITTEN + 1))
}

{
    (
        cd "$TARGET_DIR"
        find .agents .claude -type f ! -path '.claude/worktrees/*' ! -path '.claude/agent-memory*' \
            ! -path '.claude/blueprint-manifest.txt' 2>/dev/null || true
        if [[ -d docs ]]; then find docs -type f -name '*.md' 2>/dev/null || true; fi
        if [[ -d .github ]]; then find .github -type f \( -name '*.yml' -o -name '*.yaml' -o -name '*.md' -o -name '*.template' \) 2>/dev/null || true; fi
    ) | sed 's#^\./##'
    printf '%s\n' "${ROOT_FILES[@]}"
} | LC_ALL=C sort -u > "$WORK/rewrite-targets.txt"
while IFS= read -r rel; do
    rewrite_refs "$rel"
done < "$WORK/rewrite-targets.txt"
info "$(t "参照を修正" "References rewritten"): ${REWRITTEN} $(t "ファイル" "files") (.claude/<moved> → .agents/<moved>)"

# constitution.md を書き換えた場合は、対になるハッシュを取り直す(移行前に一致していたときだけ)
if [[ $CONSTITUTION_OK -eq 1 && -f "$TARGET_DIR/.agents/.constitution.sha256" ]] && grep -qxF "constitution.md" "$WORK/rewritten.txt"; then
    sha256_of "$TARGET_DIR/constitution.md" > "$TARGET_DIR/.agents/.constitution.sha256"
fi

# ── 6. manifest(新形式)──────────────────────────────────────
# 「テンプレートのまま」だったファイルは、書き換え後の今のハッシュを記録する → 続く更新で 1.0 の内容に置き換わる。
# 「変更あり」のファイルは、旧 manifest にハッシュがあればそれを引き継ぐ(更新は競合として扱う)。無ければ記録しない
{
    echo "# blueprint-manifest v2 — generated by migrate.sh from a ${OLD_VERSION} install; used by --upgrade. Do not edit by hand"
    echo "# version: ${OLD_VERSION}"
    echo "# commit: migrated"
    echo "# profile: ${PROFILE}"
    echo "# agent: claude"
    echo "# links: none"
    echo "# mirror: ${MIRROR_LANG}"
    echo "# installed: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    while IFS= read -r rel; do
        # 移動先に利用者のファイルが既にあって動かさなかったものは記録しない。記録すると、移動先にある
        # 利用者のファイルを「テンプレートのまま」と誤認して、続く更新が上書きしてしまう
        if grep -qxF "$rel" "$WORK/unmoved.txt"; then continue; fi
        np="$(new_path "$rel")"
        [[ -f "$TARGET_DIR/$np" ]] || continue
        if is_pristine "$rel"; then
            echo "$(sha256_of "$TARGET_DIR/$np")  $np"
        elif [[ -n "$OLD_MANIFEST" ]]; then
            mh="$(awk -v p="$rel" '$1 !~ /^#/ && $2 == p {print $1; exit}' "$OLD_MANIFEST")"
            if [[ -n "$mh" ]]; then echo "$mh  $np"; fi
        fi
    done < "$WORK/candidates.txt"
} > "$TARGET_DIR/$NEW_MANIFEST_REL"
rm -f "$TARGET_DIR/$OLD_MANIFEST_REL"

# ── 7. 更新(1.0 の内容へ)────────────────────────────────────
echo ""
info "$(t "1.0 の内容へ更新します(setup.sh --upgrade)" "Updating the content to 1.0 (setup.sh --upgrade)")"
UPGRADE_ARGS=("$TARGET_DIR" --upgrade --agent "$AGENT")
[[ -n "$LINKS" ]] && UPGRADE_ARGS+=(--links "$LINKS")
bash "$SCRIPT_DIR/setup.sh" "${UPGRADE_ARGS[@]}"

# 更新で .claude/ .agents/ .codex/ の外に増えたファイルを journal に残す(rollback で消す)
journal_created

# .gitignore: 1.0 のローカル状態の除外を足す(既存の行は消さない)
ensure_trailing_newline "$TARGET_DIR/.gitignore"
for entry in ".agents/skills/*-workspace/" ".claude/skills/*-workspace/"; do
    case "$entry" in .claude/*) [[ "$AGENT" == "codex" ]] && continue ;; esac
    if ! grep -qxF "$entry" "$TARGET_DIR/.gitignore"; then echo "$entry" >> "$TARGET_DIR/.gitignore"; fi
done

trap - ERR INT TERM HUP

# 書き換えの対象外に残った参照を探す(package.json・Makefile・git フックの設定・README などから
# .claude/scripts/ や .claude/hooks/ を呼んでいると、移動後は存在しないパスを指す)。自動では直さず、知らせる
LEFT_REFS=""
if [[ $IS_GIT -eq 1 ]]; then
    LEFT_REFS="$( { git -C "$TARGET_DIR" grep -IE "$REF_RE" -- . ':!.agents' ':!.claude' ':!.codex' ':!output' ':!input' ":!$BACKUP_REL" 2>/dev/null || true; } \
        | { grep -vE '(~|\$HOME|\$\{HOME\})/\.claude/' || true; } | cut -d: -f1 | LC_ALL=C sort -u | sed -n '1,20p')"
fi

# ── 結果 ────────────────────────────────────────────────────
NEW_FILES="$( (cd "$TARGET_DIR" && find . -name '*.blueprint-new' ! -path "./$BACKUP_REL/*" ! -path './.git/*' 2>/dev/null) | sed 's#^\./##' | LC_ALL=C sort)"
NEW_COUNT=0
[[ -n "$NEW_FILES" ]] && NEW_COUNT="$(printf '%s\n' "$NEW_FILES" | wc -l | tr -d ' ')"

echo ""
info "$(t "移行完了" "Migration complete"): $(t "移動" "moved") ${MOVED} / $(t "参照修正" "references rewritten") ${REWRITTEN} / $(t "統合待ち(.blueprint-new)" "to merge (.blueprint-new)") ${NEW_COUNT} / $(t "移動できず" "not moved") ${MOVE_CONFLICTS}"
if [[ $MOVE_CONFLICTS -gt 0 ]]; then
    warn "$(t "移動先に同名のファイルがあったため動かしていません(.claude/ 側に残っています)。手で統合してください:" \
              "These were not moved because the destination already existed (they remain under .claude/). Merge them by hand:")"
    sed 's/^/    /' "$WORK/move-conflicts.txt"
fi
if [[ $NEW_COUNT -gt 0 ]]; then
    warn "$(t "手で変更していたファイルは上書きしていません。横に置いた新版と統合してください:" \
              "Files you had modified were not overwritten. Merge the new versions placed next to them:")"
    printf '%s\n' "$NEW_FILES" | sed 's/^/    /'
fi
if [[ -n "$LEFT_REFS" ]]; then
    warn "$(t "移したパス(.claude/hooks/ .claude/scripts/ など)への参照が、自動修正の対象外のファイルに残っています。.agents/ へ直す必要が無いか確認してください:" \
              "References to moved paths (.claude/hooks/, .claude/scripts/, ...) remain in files outside the automatic rewrite. Check whether they should point to .agents/:")"
    printf '%s\n' "$LEFT_REFS" | sed 's/^/    /'
fi
echo ""
echo "$(t "次のステップ:" "Next steps:")"
if [[ $IS_GIT -eq 1 ]]; then
    echo "  1. $(t "結果を確認する" "Review the result"): git -C $TARGET_DIR status && git -C $TARGET_DIR diff --stat"
else
    echo "  1. $(t "結果を確認する(.agents/ .claude/ .codex/ と CLAUDE.md / AGENTS.md)" "Review the result (.agents/ .claude/ .codex/ and CLAUDE.md / AGENTS.md)")"
fi
echo "  2. $(t ".blueprint-new を元ファイルへ統合し、.blueprint-new を消す" "Merge each .blueprint-new into its file, then delete the .blueprint-new file")"
STEP=3
if [[ "$AGENT" != "codex" ]]; then
    echo "  $STEP. $(t "Claude Code を起動し直す(フックのパスが変わったため)。/hooks でフックの登録を確認できる" "Restart Claude Code (the hook paths changed). /hooks shows the registered hooks")"
    STEP=$((STEP + 1))
fi
if [[ "$AGENT" != "claude" ]]; then
    echo "  $STEP. $(t "Codex でプロジェクトを信頼し、/hooks でフックを確認して信頼する(信頼するまでフックは動かない)" "In Codex, trust the project, then review and trust the hooks with /hooks (hooks do not run until trusted)")"
    STEP=$((STEP + 1))
fi
echo "  $STEP. $(t "問題が無ければ $BACKUP_REL/ を消す。戻すなら" "Delete $BACKUP_REL/ once you are sure. To undo"): bash $SCRIPT_DIR/migrate.sh $TARGET_DIR --rollback"
