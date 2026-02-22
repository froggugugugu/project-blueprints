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

# Verify that the target directory exists
if [[ ! -d "$TARGET_DIR" ]]; then
    error "Target directory does not exist: $TARGET_DIR"
    exit 1
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
