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
  bash setup.sh <target-directory>

Description:
  Copies the Project Blueprint files to the target project.

  - .claude/ (skills, teams, settings)
  - docs/ (technical documentation stubs)
  - input/ (requirements memo directory)
  - output/ (AI artifact directory)
  - testreport/ (raw tool output)
  - project-config.md (configuration file)
  - CLAUDE.md -> placed at the project root

Examples:
  bash setup.sh /path/to/my-project
  bash setup.sh .                      # Install into the current directory

After setup:
  1. Fill in project-config.md sections S1-S3 and S6
  2. Run /plan in Claude Code to verify setup
EOF
    exit 1
}

# -- Argument check ------------------------------------------------
if [[ $# -lt 1 ]]; then
    usage
fi

TARGET_DIR="$1"

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

# -- Copy files ----------------------------------------------------
info "Copying blueprint files..."

cp -r "$SCRIPT_DIR/.claude"          "$TARGET_DIR/.claude"
cp -r "$SCRIPT_DIR/docs"             "$TARGET_DIR/docs"
cp -r "$SCRIPT_DIR/input"            "$TARGET_DIR/input"
cp -r "$SCRIPT_DIR/output"           "$TARGET_DIR/output"
cp -r "$SCRIPT_DIR/testreport"       "$TARGET_DIR/testreport"
cp    "$SCRIPT_DIR/project-config.md" "$TARGET_DIR/project-config.md"
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
info "Setup complete!"
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
