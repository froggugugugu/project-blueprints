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

Description:
  Copies the Project Blueprint files to the target project.

  - .claude/ (skills, teams, settings)
  - docs/ (technical documentation stubs)
  - input/ (requirements memo directory)
  - output/ (AI artifact directory)
  - testreport/ (raw tool output)
  - project-config.md (configuration file)
  - CLAUDE.md -> placed at the project root

Profiles (--profile, defaults to full):
  minimal   5 skills / 2 agents / 2 hooks / no teams — fastest way to try it out
  standard  17 skills / 8 agents / 13 hooks / no teams — everything but team mode
  full      17 skills / 8 agents / 13 hooks / 6 teams — default, matches current behavior

  Note: minimal also trims safeguard hooks (e.g. session-start) for a lighter footprint.
  This is a separate axis from the "minimal/recommended/full" guidance in project-config.md
  (which is about how much of project-config.md to fill in).

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

# -- Back up existing .claude/ -------------------------------------
if [[ -d "$TARGET_DIR/.claude" ]]; then
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

# -- Copy files ----------------------------------------------------
info "Copying blueprint files... (profile: $PROFILE)"

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
fi

# -- Swap in the profile-specific settings.json ------------------------
if [[ "$PROFILE" == "minimal" ]]; then
    mv "$TARGET_DIR/.claude/settings.minimal.json" "$TARGET_DIR/.claude/settings.json"
else
    rm -f "$TARGET_DIR/.claude/settings.minimal.json"
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
    info "Made hook scripts executable"
fi

# -- Move CLAUDE.md to the project root ----------------------------
if [[ -f "$TARGET_DIR/.claude/CLAUDE.md" ]]; then
    mv "$TARGET_DIR/.claude/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
    info "Placed CLAUDE.md at the project root"
fi

# -- Add testreport/ to .gitignore ---------------------------------
GITIGNORE="$TARGET_DIR/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
    if ! grep -q '^testreport/' "$GITIGNORE" 2>/dev/null; then
        echo "" >> "$GITIGNORE"
        echo "# Raw tool output (AI-generated data)" >> "$GITIGNORE"
        echo "testreport/" >> "$GITIGNORE"
        info "Added testreport/ to .gitignore"
    else
        info "testreport/ is already in .gitignore"
    fi
else
    cat > "$GITIGNORE" <<'GITIGNORE_EOF'
# Raw tool output (AI-generated data)
testreport/
GITIGNORE_EOF
    info "Created .gitignore with testreport/"
fi

# -- Done ----------------------------------------------------------
echo ""
info "Setup complete! (profile: $PROFILE)"
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
