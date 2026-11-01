#!/usr/bin/env bash
# ==============================================================================
# instructions-log.sh — InstructionsLoaded hook (observe only)
#
# Records the fact that a CLAUDE.md / AGENTS.md (via import) / .claude/rules/*.md file
# entered the context, as JSONL under testreport/instructions/<session>.jsonl. load_reason:
#   - session_start       : files that always load at startup (= the cost paid every session)
#   - path_glob_match     : a rule with paths: was lazily loaded by touching a matching file
#   - nested_traversal    : a subdirectory CLAUDE.md was lazily loaded
#   - include             : pulled in through @import (AGENTS.md shows up here)
#   - compact             : re-loaded after compaction
#
# Purpose: measure which rules actually load. /harness-refine's inventory pass uses it to find
#   - a paths: rule that never loaded in the last N sessions → wrong paths, or not needed
#   - a rule that loads every session → candidate to merge into CLAUDE.md or to narrow its paths:
#   Prose instructions with no activation record are pruning candidates (enforcing hooks / deny
#   rules are a different matter: they cost almost nothing to keep even when they never fire).
#
# InstructionsLoaded has no decision control at all (systemMessage is discarded too). Logging only.
#
# Input:  {"hook_event_name":"InstructionsLoaded","file_path":"...","memory_type":"Project",
#          "load_reason":"session_start|nested_traversal|path_glob_match|include|compact",
#          "globs":[...],"trigger_file_path":"...","parent_file_path":"..."}
# Output: appends one line to testreport/instructions/<session>.jsonl (gitignored)
# Policy: fail-open (exit 0 whatever fails)
# ==============================================================================

set -uo pipefail

PROFILE="${BLUEPRINT_HOOK_PROFILE:-standard}"
[[ "$PROFILE" == "minimal" ]] && exit 0
command -v jq &>/dev/null || exit 0

INPUT="$(cat 2>/dev/null || true)"
[[ -z "$INPUT" ]] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOG_DIR="$PROJECT_DIR/testreport/instructions"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

SID="$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)"
SID="$(printf '%s' "$SID" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-8)"
[[ -z "$SID" ]] && SID="unknown"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Paths are normalized to project-relative; files outside the project (~/.claude/CLAUDE.md etc.)
# keep only their basename, so home-directory paths never land in a shared log
printf '%s' "$INPUT" | jq -c --arg ts "$TS" --arg root "$PROJECT_DIR/" '
    def rel: if type == "string" and length > 0 then
                 (if startswith($root) then .[($root | length):] else ("…/" + (split("/") | last)) end)
             else "" end;
    {
        ts: $ts,
        file: ((.file_path // "") | rel),
        memory_type: (.memory_type // ""),
        load_reason: (.load_reason // ""),
        trigger: ((.trigger_file_path // "") | rel),
        parent: ((.parent_file_path // "") | rel),
        globs: ((.globs // []) | length)
    }' >> "$LOG_DIR/$SID.jsonl" 2>/dev/null

exit 0
