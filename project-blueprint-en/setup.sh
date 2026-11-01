#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Project Blueprint Setup Script
# Copies the blueprint files to the target project
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -- Colored output ------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# -- Usage ---------------------------------------------------------
usage() {
    cat <<'EOF'
Usage:
  bash setup.sh <target-directory> [--profile minimal|standard|full]
  bash setup.sh <target-directory> --upgrade [--dry-run]

Description:
  Copies the Project Blueprint files to the target project.

  - .claude/ (skills, teams, settings)
  - docs/ (technical documentation stubs)
  - input/ (requirements memo directory)
  - output/ (AI artifact directory)
  - testreport/ (raw tool output)
  - project-config.md (configuration file)
  - CLAUDE.md / AGENTS.md -> placed at the project root
  - REVIEW.md (review criteria for Code Review) / constitution.md -> placed unless they already exist

Profiles (--profile, defaults to full):
  minimal   5 skills / 2 agents / 2 hooks / no teams — fastest way to try it out
  standard  17 skills / 9 agents / 18 hooks / no teams — everything but team mode
  full      17 skills / 9 agents / 18 hooks / 6 teams — default, matches current behavior

  Note: minimal also trims safeguard hooks (e.g. session-start) for a lighter footprint.
  This is a separate axis from the "minimal/recommended/full" guidance in project-config.md
  (which is about how much of project-config.md to fill in).

Upgrade (--upgrade):
  Brings an installed project up to this template's version. Files are compared with the
  per-file hashes recorded at install time in .claude/blueprint-manifest.txt: untouched files are
  overwritten, modified files get the new version placed next to them as <path>.blueprint-new.
  project-config.md / docs/ / input/ / output/ / settings.local.json are never touched.
  --dry-run prints the plan only.

Examples:
  bash setup.sh /path/to/my-project
  bash setup.sh /path/to/my-project --profile minimal
  bash setup.sh . --profile standard   # Install into the current directory

After setup:
  1. Fill in project-config.md sections S1-S3 and S6
  2. Run /plan in Claude Code to verify setup
EOF
    exit 1
}

# -- Argument parsing ------------------------------------------------
PROFILE="full"   # Defaults to full (no pruning) for backward compatibility
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
            error "Unknown option: $1"
            usage
            ;;
        *)
            if [[ -n "$TARGET_DIR" ]]; then
                error "Specify only one target directory: $1"
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
        error "Invalid profile: $PROFILE (must be minimal, standard, or full)"
        usage
        ;;
esac

# -- Dependency check -----------------------------------------------
# jq is required for safety-check.sh to function fully. Warn if absent (setup continues).
if ! command -v jq &>/dev/null; then
    warn "jq is not installed. safety-check.sh will skip most checks when jq is absent (only the most critical patterns will be caught)."
    warn "Install: macOS → brew install jq  /  Ubuntu → sudo apt-get install jq  /  Alpine → apk add jq"
fi

# Verify that the target directory exists (create it if missing — new-project case)
if [[ ! -d "$TARGET_DIR" ]]; then
    info "Creating new target directory: $TARGET_DIR"
    mkdir -p "$TARGET_DIR" || { error "Failed to create directory: $TARGET_DIR"; exit 1; }
fi

# Convert to absolute path
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

info "Target: $TARGET_DIR"

MANIFEST_REL=".claude/blueprint-manifest.txt"
BLUEPRINT_VERSION="$(tr -d '[:space:]' < "$SCRIPT_DIR/../VERSION" 2>/dev/null || true)"
[[ -z "${BLUEPRINT_VERSION}" ]] && BLUEPRINT_VERSION="unknown"
BLUEPRINT_COMMIT="$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
MIRROR_LANG="ja"; [[ "$(basename "$SCRIPT_DIR")" == *-en ]] && MIRROR_LANG="en"
INSTALLED_VERSION=""

if [[ "$MODE" == "upgrade" ]]; then
    if [[ ! -f "$TARGET_DIR/$MANIFEST_REL" ]]; then
        error "No .claude/blueprint-manifest.txt (installed with a setup.sh older than 0.5.0, or copied by hand). Re-run setup.sh <dir> once (the existing .claude/ is moved to .claude.bak/) and then use --upgrade"
        exit 1
    fi
    INSTALLED_VERSION="$(sed -n 's/^# version: //p' "$TARGET_DIR/$MANIFEST_REL" | head -1)"
    PROFILE="$(sed -n 's/^# profile: //p' "$TARGET_DIR/$MANIFEST_REL" | head -1)"
    case "$PROFILE" in minimal|standard|full) ;; *) PROFILE="full" ;; esac
fi

# -- Back up existing .claude/ -------------------------------------
# --upgrade keeps the existing .claude/ in place (no backup/move)
if [[ "$MODE" == "install" && -d "$TARGET_DIR/.claude" ]]; then
    BACKUP_DIR="$TARGET_DIR/.claude.bak"
    if [[ -d "$BACKUP_DIR" ]]; then
        warn "Overwriting existing backup at $BACKUP_DIR"
        rm -rf "$BACKUP_DIR"
    fi
    warn "Backing up existing .claude/ to .claude.bak/"
    mv "$TARGET_DIR/.claude" "$BACKUP_DIR"
fi

# -- Profile keep lists ----------------------------------------------
# "*" is a sentinel meaning "keep everything, prune nothing".
# standard/full never trim skills/agents/hooks, so the only list that
# needs maintenance as files are added/removed is minimal's.
case "$PROFILE" in
    minimal)
        KEEP_SKILLS=(brainstorm prd plan implementing-features code-review)
        KEEP_AGENTS=(explorer.md researcher.md)
        KEEP_HOOKS=(safety-check.sh protect-files.sh)
        KEEP_TEAMS=()          # empty = exclude teams/ entirely
        ;;
    standard)
        KEEP_SKILLS=("*")
        KEEP_AGENTS=("*")
        KEEP_HOOKS=("*")
        KEEP_TEAMS=()          # empty = exclude teams/ entirely
        ;;
    full)
        KEEP_SKILLS=("*")
        KEEP_AGENTS=("*")
        KEEP_HOOKS=("*")
        KEEP_TEAMS=("*")
        ;;
esac

# Prune a directory's immediate children based on a keep list.
# Uses plain indexed arrays (no associative arrays) for bash 3.2 (macOS default) compatibility.
prune_dir() {
    local dir="$1"; shift
    local -a keep=("$@")
    [[ "${keep[0]:-}" == "*" ]] && return 0   # sentinel: no-op
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


# -- --upgrade: bring an installed project up to this template's version --
sha256_of() {
    if command -v shasum &>/dev/null; then shasum -a 256 "$1" | cut -d' ' -f1
    elif command -v sha256sum &>/dev/null; then sha256sum "$1" | cut -d' ' -f1
    else cksum "$1" | cut -d' ' -f1; fi
}

# Decide, from the keep lists, whether a template-relative path is part of this profile
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

# Template-relative path -> target-relative path
target_path() {
    case "$1" in
        .claude/CLAUDE.md) echo "CLAUDE.md" ;;
        .claude/settings.minimal.json) echo ".claude/settings.json" ;;
        *) echo "$1" ;;
    esac
}

# Template-relative paths covered by upgrade / manifest (after pruning)
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

# Records per-file hashes at install time; --upgrade overwrites only files that still match them
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
    info "Upgrade: ${INSTALLED_VERSION} → ${BLUEPRINT_VERSION} (${BLUEPRINT_COMMIT}, profile: ${PROFILE})"
    if [[ $DRY_RUN -eq 1 ]]; then warn "--dry-run: no files will be changed"; fi
    while IFS= read -r rel; do
        tp="$(target_path "$rel")"
        mh="$(manifest_hash "$mf" "$tp")"
        if [[ "$tp" == "AGENTS.md" && -e "$TARGET_DIR/AGENTS.blueprint.md" ]]; then tp="AGENTS.blueprint.md"; fi
        seen+=("$tp")
        dst="$TARGET_DIR/$tp"
        th="$(sha256_of "$SCRIPT_DIR/$rel")"
        if [[ "$tp" == "project-config.md" ]]; then
            if [[ -n "$mh" && "$mh" != "$th" ]]; then warn "The template's project-config.md changed (not overwritten: humans own this file). Diff: diff ${SCRIPT_DIR}/project-config.md ${TARGET_DIR}/project-config.md"; fi
            continue
        fi
        if [[ ! -e "$dst" ]]; then
            if [[ -n "$mh" ]]; then
                echo "  skip     $tp  (deleted locally; copy by hand to restore)"; skipped=$((skipped + 1))
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
            echo "  conflict $tp  (modified locally; new version placed next to it: $tp.blueprint-new)"; conflicts=$((conflicts + 1))
            if [[ $DRY_RUN -eq 0 ]]; then cp "$SCRIPT_DIR/$rel" "$dst.blueprint-new"; fi
            if [[ -n "$mh" ]]; then conflict_lines+=("$mh  $tp"); fi
        fi
    done < <(template_files)
    while IFS= read -r tp; do
        [[ -z "$tp" ]] && continue
        found=0
        for s in "${seen[@]}"; do [[ "$s" == "$tp" ]] && { found=1; break; }; done
        if [[ $found -eq 0 && -e "$TARGET_DIR/$tp" ]]; then
            echo "  removed  $tp  (removed from the template; delete by hand if unneeded)"; removed=$((removed + 1))
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
    info "Upgrade complete: added ${added} / updated ${updated} / unchanged ${unchanged} / conflicts ${conflicts} / skipped ${skipped} / removed from template ${removed}"
    if [[ ${conflicts} -gt 0 ]]; then warn "Next: merge each conflict with diff <path> <path>.blueprint-new and delete the .blueprint-new file, then run /harness-refine in Claude Code"; fi
    return 0
}

# --upgrade branches here (the install steps below do not run)
if [[ "$MODE" == "upgrade" ]]; then
    run_upgrade
    exit 0
fi

# -- Copy files ----------------------------------------------------
info "Copying blueprint files... (profile: ${PROFILE})"

cp -r "$SCRIPT_DIR/.claude"          "$TARGET_DIR/.claude"
cp -r "$SCRIPT_DIR/docs"             "$TARGET_DIR/docs"
cp -r "$SCRIPT_DIR/input"            "$TARGET_DIR/input"
cp -r "$SCRIPT_DIR/output"           "$TARGET_DIR/output"
cp -r "$SCRIPT_DIR/testreport"       "$TARGET_DIR/testreport"
cp    "$SCRIPT_DIR/project-config.md" "$TARGET_DIR/project-config.md"

# -- Prune .claude/ according to the selected profile -----------------
prune_dir "$TARGET_DIR/.claude/skills" "${KEEP_SKILLS[@]}"
prune_dir "$TARGET_DIR/.claude/agents" "${KEEP_AGENTS[@]}" "README.md"
prune_dir "$TARGET_DIR/.claude/hooks"  "${KEEP_HOOKS[@]}"

if [[ "${#KEEP_TEAMS[@]}" -eq 0 ]]; then
    rm -rf "$TARGET_DIR/.claude/teams"
    # Saved workflows belong to the team (orchestration) layer, so they follow teams
    rm -rf "$TARGET_DIR/.claude/workflows"
fi

# -- Swap in the profile-specific settings.json ------------------------
if [[ "$PROFILE" == "minimal" ]]; then
    mv "$TARGET_DIR/.claude/settings.minimal.json" "$TARGET_DIR/.claude/settings.json"
else
    rm -f "$TARGET_DIR/.claude/settings.minimal.json"
fi

# -- Generate settings.local.json from the template (if missing) ----------
# Personal allow rules. Gitignored; the SessionStart hook warns when it is missing.
if [[ -f "$TARGET_DIR/.claude/settings.local.json.template" && ! -f "$TARGET_DIR/.claude/settings.local.json" ]]; then
    cp "$TARGET_DIR/.claude/settings.local.json.template" "$TARGET_DIR/.claude/settings.local.json"
    info "Generated .claude/settings.local.json from the template (adjust the allow list to your build tools)"
fi
# constitution.md (immutable principles) — referenced by scan-harness.sh / CLAUDE.md
# Note: avoid SC2015 (`&& A || B`) since `cp -n` returns 0 even when it skips —
#       use an explicit existence check instead.
if [[ -f "$SCRIPT_DIR/constitution.md" ]]; then
    if [[ -e "$TARGET_DIR/constitution.md" ]]; then
        info "constitution.md already exists, kept (no overwrite)"
    else
        cp "$SCRIPT_DIR/constitution.md" "$TARGET_DIR/constitution.md"
        info "constitution.md (immutable principles) placed"
    fi
fi

# REVIEW.md (review instructions for Claude's Code Review) — existing files are kept
if [[ -f "$SCRIPT_DIR/REVIEW.md" ]]; then
    if [[ -e "$TARGET_DIR/REVIEW.md" ]]; then
        info "REVIEW.md already exists, kept (no overwrite)"
    else
        cp "$SCRIPT_DIR/REVIEW.md" "$TARGET_DIR/REVIEW.md"
        info "REVIEW.md (Code Review criteria) placed"
    fi
fi

# -- Place .mcp.json.template (rename to .mcp.json to activate) ----
# Preserve existing .mcp.json.template in the target (protects user customizations).
if [[ -f "$SCRIPT_DIR/.mcp.json.template" ]]; then
    if cp -n "$SCRIPT_DIR/.mcp.json.template" "$TARGET_DIR/.mcp.json.template" 2>/dev/null; then
        info "Placed .mcp.json.template (rename to .mcp.json to activate)"
    else
        info ".mcp.json.template already exists, preserved (not overwritten)"
    fi
fi

# -- Place .github/ workflow templates -----------------------------
# Merge scope (when .github/ already exists):
#   - workflows/*.template (blueprint-supplied workflow templates)
#   - top-level *.md (e.g., CLAUDE_REVIEW_SETUP.md)
# Existing files are preserved via `cp -n`.
# If the blueprint later adds .github/ISSUE_TEMPLATE/, PULL_REQUEST_TEMPLATE.md,
# dependabot.yml, etc., this branch must be extended to copy them explicitly.
if [[ -d "$SCRIPT_DIR/.github" ]]; then
    if [[ -d "$TARGET_DIR/.github" ]]; then
        mkdir -p "$TARGET_DIR/.github/workflows"
        # shellcheck disable=SC2086
        cp -n "$SCRIPT_DIR"/.github/workflows/*.template \
              "$TARGET_DIR/.github/workflows/" 2>/dev/null || true
        # shellcheck disable=SC2086
        cp -n "$SCRIPT_DIR"/.github/*.md \
              "$TARGET_DIR/.github/" 2>/dev/null || true
        info "Merged .github/ workflow templates (existing files preserved)"
    else
        cp -r "$SCRIPT_DIR/.github" "$TARGET_DIR/.github"
        info "Placed .github/ (remove .template extension to activate workflows)"
    fi
fi

# -- Make hook scripts executable -----------------------------------
if [[ -d "$TARGET_DIR/.claude/hooks" ]]; then
    chmod +x "$TARGET_DIR/.claude/hooks/"*.sh 2>/dev/null || true
    chmod +x "$TARGET_DIR/.claude/scripts/"*.sh 2>/dev/null || true
    info "Made hook scripts executable"
fi

# -- Move CLAUDE.md to the project root ----------------------------
if [[ -f "$TARGET_DIR/.claude/CLAUDE.md" ]]; then
    mv "$TARGET_DIR/.claude/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
    info "Placed CLAUDE.md at the project root"
fi

# -- Place AGENTS.md (tool-agnostic rules) --------------------------------
# Codex / Cursor / Copilot etc. read it directly; Claude Code imports it via @AGENTS.md in CLAUDE.md.
# An existing AGENTS.md is never overwritten; the template version goes next to it for merging.
if [[ -f "$SCRIPT_DIR/AGENTS.md" ]]; then
    if [[ -e "$TARGET_DIR/AGENTS.md" ]] && cmp -s "$SCRIPT_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.md"; then
        info "AGENTS.md is identical to the template; kept as is"
    elif [[ -e "$TARGET_DIR/AGENTS.blueprint.md" ]] && ! cmp -s "$SCRIPT_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.blueprint.md"; then
        # Never overwrite an AGENTS.blueprint.md that is being merged
        warn "AGENTS.blueprint.md differs from the template, so it was left untouched (keeping your in-progress merge)."
        warn "  Latest template version: $SCRIPT_DIR/AGENTS.md"
    elif [[ -e "$TARGET_DIR/AGENTS.md" ]]; then
        cp "$SCRIPT_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.blueprint.md"
        warn "Kept the existing AGENTS.md and placed the template version as AGENTS.blueprint.md."
        warn "  Merge it into AGENTS.md, then delete AGENTS.blueprint.md (CLAUDE.md imports AGENTS.md only)"
    else
        cp "$SCRIPT_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.md"
        info "Placed AGENTS.md (tool-agnostic rules) at the project root"
    fi
    info "  If you use agents other than Claude Code, fill in their roles and write scopes in project-config.md §13.7"
fi

# -- Add testreport/ to .gitignore ---------------------------------

GITIGNORE="$TARGET_DIR/.gitignore"
# Also exclude the local state Claude Code writes inside the repository:
#   testreport/                 raw tool output / observation-hook logs
#   .claude/settings.local.json personal allow rules (sharing them leaks permissions)
#   .claude/worktrees/          worktrees from --worktree / isolation: worktree
#   .claude/agent-memory-local/ subagent memory for memory: local
#   .claude/skills/*-workspace/ skill-creator eval workspaces
GITIGNORE_ENTRIES=(testreport/ .claude/settings.local.json .claude/worktrees/ .claude/agent-memory-local/ .claude/skills/*-workspace/)
if [[ ! -f "$GITIGNORE" ]]; then
    printf '%s\n' "# Claude Code local state (AI-generated data, personal settings)" > "$GITIGNORE"
    info "Created .gitignore"
fi
for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if ! grep -qxF "$entry" "$GITIGNORE" 2>/dev/null; then
        if [[ "$entry" == "testreport/" ]] && ! grep -q '^# ' "$GITIGNORE"; then
            echo "" >> "$GITIGNORE"
            echo "# Claude Code local state (AI-generated data, personal settings)" >> "$GITIGNORE"
        fi
        echo "$entry" >> "$GITIGNORE"
        info "Added to .gitignore: $entry"
    else
        info "Already in .gitignore: $entry"
    fi
done

# -- Record the installed version (baseline for --upgrade) ----------
write_manifest "$TARGET_DIR" "$PROFILE"
info "Recorded the installed version in .claude/blueprint-manifest.txt (update later with bash setup.sh <dir> --upgrade)"

# -- Done ----------------------------------------------------------
echo ""
info "Setup complete! (profile: ${PROFILE})"
echo ""
echo "Next steps:"
echo "  1. Fill in project-config.md (at minimum S1-S3 and S6)"
echo "     vi $TARGET_DIR/project-config.md"
echo ""
echo "  2. Customize permission settings (optional)"
echo "     cp $TARGET_DIR/.claude/settings.local.json.template $TARGET_DIR/.claude/settings.local.json"
echo ""
echo "  3. Verify setup in Claude Code"
echo "     cd $TARGET_DIR && claude"
echo "     /plan Review the initial project setup status"
echo ""
echo "  Details: https://github.com/your-org/project-blueprints"
