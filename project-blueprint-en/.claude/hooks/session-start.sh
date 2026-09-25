#!/usr/bin/env bash
# ==============================================================================
# session-start.sh — SessionStart hook
#
# Runs at the beginning of each Claude Code session (source: startup / resume / clear /
# compact / fork). Checks project readiness and reports findings to Claude.
# On source == "compact" it re-injects the core rules instead: the official way to
# restore context after compaction is a SessionStart hook with the `compact` matcher,
# whose output is added to the compacted context right away (PostCompact cannot inject).
#
# Output: stdout JSON hookSpecificOutput.additionalContext (SessionStart)
#         NOTE: stderr on exit 0 never reaches Claude (official spec)
# Exit:   always 0 (informational only, never blocks)
# ==============================================================================

set -uo pipefail

# ── Shared emitter that actually reaches Claude ───────────────────────
# Official spec: on exit 0, stderr only reaches the debug log — neither Claude nor
# the user sees it. To tell Claude, print hookSpecificOutput.additionalContext on stdout.
emit_context() {
    local event="$1"; shift
    local text="$*"
    [[ -z "$text" ]] && return 0
    if command -v jq &>/dev/null; then
        jq -nc --arg e "$event" --arg t "$text" \
            '{hookSpecificOutput:{hookEventName:$e, additionalContext:$t}}'
    else
        local esc
        esc="$(printf '%s' "$text" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}')"
        printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$event" "$esc"
    fi
}

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
warnings=()

# --- Read the start reason (source) from the stdin JSON (string search when jq is missing) ---
INPUT="$(cat 2>/dev/null || true)"
SOURCE="startup"
if command -v jq &>/dev/null; then
    SOURCE="$(printf '%s' "$INPUT" | jq -r '.source // "startup"' 2>/dev/null || echo startup)"
elif printf '%s' "$INPUT" | grep -q '"source"[[:space:]]*:[[:space:]]*"compact"'; then
    SOURCE="compact"
fi
IS_COMPACT=0
[[ "$SOURCE" == "compact" ]] && IS_COMPACT=1

# ── Right after a compact, skip the readiness checks (they were reported before) ──
if [[ "$IS_COMPACT" -eq 0 && ! -f "$PROJECT_DIR/project-config.md" ]]; then
    warnings+=("project-config.md not found. Copy project-config.sample.md to create it.")
fi

# --- Check docs/ directory exists ---
if [[ "$IS_COMPACT" -eq 0 && ! -d "$PROJECT_DIR/docs" ]]; then
    warnings+=("docs/ directory does not exist. Please check the setup steps.")
fi

# --- Check docs/ stubs ---
for doc in project.md architecture.md data-model.md development-patterns.md; do
    [[ "$IS_COMPACT" -eq 1 ]] && break
    doc_path="$PROJECT_DIR/docs/$doc"
    if [[ -f "$doc_path" ]]; then
        # Check if still a stub (< 5 non-empty lines = likely stub)
        content_lines=$(grep -c '[^[:space:]]' "$doc_path" 2>/dev/null || true)
        content_lines=${content_lines:-0}
        if [[ "$content_lines" -lt 5 ]]; then
            warnings+=("docs/$doc is still a stub. Generate content as implementation progresses.")
        elif [[ "$content_lines" -gt 300 ]]; then
            # docs/*.md are @imported by CLAUDE.md in every session, so growth becomes startup cost
            warnings+=("docs/$doc has ${content_lines} lines (guideline: 300). It loads in every session; move details into a skill's references/ or a path-scoped rule.")
        fi
    fi
done

# --- Check settings.local.json exists ---
if [[ "$IS_COMPACT" -eq 0 && ! -f "$PROJECT_DIR/.claude/settings.local.json" ]]; then
    warnings+=("settings.local.json not created. Use settings.local.json.template as a reference.")
fi

# --- Progress handoff note (resuming multi-session work) ---
# If output/tasks/PROGRESS.md exists, inject its head (state + feature list + next steps).
# Official long-running-agent finding: a fresh context starts from git log and a progress note.
HANDOFF=""
PROGRESS="$PROJECT_DIR/output/tasks/PROGRESS.md"
if [[ -f "$PROGRESS" ]]; then
    EXCERPT="$(head -n 60 "$PROGRESS" 2>/dev/null | head -c 3500 || true)"
    if [[ -n "$EXCERPT" ]]; then
        HANDOFF="[progress handoff] output/tasks/PROGRESS.md detected. Before resuming work:
  1. Read \`git log --oneline -10\` and the note below to see where the last session stopped
  2. Run the recorded smoke test; if anything is broken, fix it before starting a new feature
  3. Pick only the highest-priority unfinished feature (passes=❌) from the feature list
  4. Finish with tests green + a commit + PROGRESS.md updated (append a session log entry)
--- PROGRESS.md (first 60 lines) ---
$EXCERPT"
    fi
fi

# --- Report state to Claude ---
MSG=""
if [[ "$IS_COMPACT" -eq 1 ]]; then
    MSG="[post-compact recovery] The context was just compacted. CLAUDE.md, AGENTS.md and rules without paths were re-injected from disk. Re-check what a summary does not keep:
  - Rules with paths (.claude/rules/) reload only when you Read a matching file again
  - Work in flight: the newest files under output/, unfinished tasks, and the last verification command with its result
  - Constraints the user stated and decisions taken or rejected: trust the summary and do not redesign on your own
  - The pre-compact summary is preserved under testreport/transcripts/ (Read it if needed)"
fi
if [[ ${#warnings[@]} -gt 0 ]]; then
    MSG="Project readiness check (project-blueprint SessionStart):"
    for w in "${warnings[@]}"; do
        MSG="$MSG"$'\n'"  - $w"
    done
fi
if [[ -n "$HANDOFF" ]]; then
    [[ -n "$MSG" ]] && MSG="$MSG"$'\n\n'
    MSG="$MSG$HANDOFF"
fi
[[ -n "$MSG" ]] && emit_context SessionStart "$MSG"

exit 0
