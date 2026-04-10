#!/usr/bin/env bash
# ==============================================================================
# session-start.sh — SessionStart hook
#
# Runs at the beginning of each Claude Code session.
# Checks project readiness and outputs warnings to stderr
# so Claude can inform the user of any setup issues.
#
# Output: stderr warnings are fed back to Claude as context
# Exit:   always 0 (informational only, never blocks)
# ==============================================================================

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
warnings=()

# --- Check project-config.md exists ---
if [[ ! -f "$PROJECT_DIR/project-config.md" ]]; then
    warnings+=("project-config.md not found. Copy project-config.sample.md to create it.")
fi

# --- Check docs/ directory exists ---
if [[ ! -d "$PROJECT_DIR/docs" ]]; then
    warnings+=("docs/ directory does not exist. Please check the setup steps.")
fi

# --- Check docs/ stubs ---
for doc in project.md architecture.md data-model.md development-patterns.md; do
    doc_path="$PROJECT_DIR/docs/$doc"
    if [[ -f "$doc_path" ]]; then
        # Check if still a stub (< 5 non-empty lines = likely stub)
        content_lines=$(grep -c '[^[:space:]]' "$doc_path" 2>/dev/null || true)
        content_lines=${content_lines:-0}
        if [[ "$content_lines" -lt 5 ]]; then
            warnings+=("docs/$doc is still a stub. Generate content as implementation progresses.")
        fi
    fi
done

# --- Check settings.local.json exists ---
if [[ ! -f "$PROJECT_DIR/.claude/settings.local.json" ]]; then
    warnings+=("settings.local.json not created. Use settings.local.json.template as a reference.")
fi

# --- Output warnings ---
if [[ ${#warnings[@]} -gt 0 ]]; then
    echo "=== Session Start: Project Readiness Check ===" >&2
    for w in "${warnings[@]}"; do
        echo "  - $w" >&2
    done
    echo "================================================" >&2
fi

exit 0
