#!/usr/bin/env bash
# ==============================================================================
# harness-stats.sh — aggregate the JSONL the observability hooks leave under testreport/
#
# Role: one Markdown page with guardrail firings, denials, failures, settings changes,
#       rule-load records and subagent launches. It is the measured input for the
#       "Control inventory" step of `/harness-refine` Round 0 and for the guardrails.md rules
#       "keep an enforcement even when it never fires / judge an instruction by its load record".
#
# Usage:
#   bash .claude/scripts/harness-stats.sh                # whole history
#   bash .claude/scripts/harness-stats.sh --since 30     # last 30 days
#   bash .claude/scripts/harness-stats.sh --json         # machine-readable (aggregates only)
#   bash .claude/scripts/harness-stats.sh --project /path/to/project
#
# Input (JSONL written by the hooks; a missing directory counts as 0):
#   testreport/denials/*.jsonl         permission-denied-log.sh  {ts, kind, tool, reason, permission_mode, input}
#   testreport/failures/*.jsonl        post-failure-log.sh       {timestamp, tool, error, is_interrupt}
#   testreport/config-changes/*.jsonl  config-guard.sh / scan-harness.sh  {ts, source, decision, violations[]}
#   testreport/instructions/*.jsonl    instructions-log.sh       {ts, file, memory_type, load_reason}
#   testreport/agents/*.jsonl          subagent-audit.sh         {timestamp, event, agent_name}
#   output/reports/sessions/*.md       session-end.sh            one line per session
#
# Requires jq. Exit code: 0 = report written / 2 = jq missing
# ==============================================================================

set -uo pipefail

PROJECT="${CLAUDE_PROJECT_DIR:-.}"
SINCE_DAYS=""
FORMAT="md"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --since) SINCE_DAYS="${2:-}"; shift 2 ;;
        --since=*) SINCE_DAYS="${1#*=}"; shift ;;
        --json) FORMAT="json"; shift ;;
        --project) PROJECT="${2:-.}"; shift 2 ;;
        -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

command -v jq &>/dev/null || { echo "harness-stats: jq is required" >&2; exit 2; }

TR="$PROJECT/testreport"
SINCE=""
if [[ -n "$SINCE_DAYS" ]]; then
    # Works with both BSD date (macOS) and GNU date
    SINCE="$(date -u -v-"${SINCE_DAYS}"d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "-${SINCE_DAYS} days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)"
fi

# load <dir> → one JSON object per line inside the window (compares ts or timestamp)
load() {
    local dir="$TR/$1"
    [[ -d "$dir" ]] || return 0
    cat "$dir"/*.jsonl 2>/dev/null | jq -c --arg since "$SINCE" \
        'select(type == "object") | select($since == "" or ((.ts // .timestamp // "") >= $since))' 2>/dev/null
}

DENIALS="$(load denials)"
FAILURES="$(load failures)"
CONFIG="$(load config-changes)"
INSTR="$(load instructions)"
AGENTS="$(load agents)"
SESSIONS=0
if [[ -d "$PROJECT/output/reports/sessions" ]]; then
    SESSIONS="$(cat "$PROJECT/output/reports/sessions"/*.md 2>/dev/null | grep -c '^| ' || true)"
fi

# Aggregate with jq (slurp into arrays, then group_by)
summary_json() {
    jq -n \
        --arg since "${SINCE:-all}" \
        --argjson sessions "${SESSIONS:-0}" \
        --slurpfile denials <(printf '%s\n' "$DENIALS" | jq -c 'select(. != null)' 2>/dev/null; true) \
        --slurpfile failures <(printf '%s\n' "$FAILURES" | jq -c 'select(. != null)' 2>/dev/null; true) \
        --slurpfile config <(printf '%s\n' "$CONFIG" | jq -c 'select(. != null)' 2>/dev/null; true) \
        --slurpfile instr <(printf '%s\n' "$INSTR" | jq -c 'select(. != null)' 2>/dev/null; true) \
        --slurpfile agents <(printf '%s\n' "$AGENTS" | jq -c 'select(. != null)' 2>/dev/null; true) \
        '
        def top(f): group_by(f) | map({key: (.[0] | f), count: length}) | sort_by(-.count) | .[0:10];
        {
          since: $since,
          sessions: $sessions,
          denials: {
            total: ($denials | length),
            by_kind: ($denials | group_by(.kind) | map({key: .[0].kind, count: length})),
            by_tool: ($denials | top(.tool))
          },
          failures: {
            total: ($failures | length),
            interrupts: ($failures | map(select(.is_interrupt == "true")) | length),
            by_tool: ($failures | top(.tool))
          },
          config_changes: {
            total: ($config | length),
            blocked: ($config | map(select(.decision == "block")) | length),
            warned: ($config | map(select(.decision == "warn")) | length),
            violations: ($config | map(.violations[]?) | top(.))
          },
          instructions: {
            total: ($instr | length),
            by_file: ($instr | top(.file)),
            by_reason: ($instr | group_by(.load_reason) | map({key: .[0].load_reason, count: length}))
          },
          subagents: {
            starts: ($agents | map(select(.event == "SubagentStart")) | length),
            stops: ($agents | map(select(.event == "SubagentStop")) | length),
            by_agent: ($agents | map(select(.event == "SubagentStart")) | top(.agent_name))
          }
        }'
}

JSON="$(summary_json)"

if [[ "$FORMAT" == "json" ]]; then
    printf '%s\n' "$JSON"
    exit 0
fi

table() { # table <json-array of {key,count}> <header>
    local rows="$1" header="$2"
    if [[ "$(printf '%s' "$rows" | jq 'length')" == "0" ]]; then
        echo "(no records)"
        return
    fi
    echo "| $header | count |"
    echo "| --- | --- |"
    printf '%s' "$rows" | jq -r '.[] | "| `\(.key | tostring | .[0:80])` | \(.count) |"'
}

echo "# Harness observability summary (${SINCE_DAYS:+last ${SINCE_DAYS} days / }$(date -u +%Y-%m-%d))"
echo
echo "- sessions (output/reports/sessions): $SESSIONS"
echo "- denials and permission dialogs (denials): $(printf '%s' "$JSON" | jq '.denials.total')"
echo "- tool failures / API errors (failures): $(printf '%s' "$JSON" | jq '.failures.total') (interrupted $(printf '%s' "$JSON" | jq '.failures.interrupts'))"
echo "- settings changes (config-changes): $(printf '%s' "$JSON" | jq '.config_changes.total') (blocked $(printf '%s' "$JSON" | jq '.config_changes.blocked') / warned $(printf '%s' "$JSON" | jq '.config_changes.warned'))"
echo "- instruction-file loads (instructions): $(printf '%s' "$JSON" | jq '.instructions.total')"
echo "- subagent launches (agents): $(printf '%s' "$JSON" | jq '.subagents.starts')"
echo
echo "## Denials and dialogs (by tool)"
echo
table "$(printf '%s' "$JSON" | jq '.denials.by_tool')" "tool"
echo
echo "## Tool failures (by tool)"
echo
table "$(printf '%s' "$JSON" | jq '.failures.by_tool')" "tool"
echo
echo "## Settings-change violations"
echo
table "$(printf '%s' "$JSON" | jq '.config_changes.violations')" "violation"
echo
echo "## Instruction-file loads (evidence for the rule inventory; a \`paths:\` rule with 0 loads is a pruning candidate)"
echo
table "$(printf '%s' "$JSON" | jq '.instructions.by_file')" "file"
echo
echo "## Subagent launches (by agent)"
echo
table "$(printf '%s' "$JSON" | jq '.subagents.by_agent')" "agent"
echo
echo "> Criteria: the \"Control inventory\" section of \`.claude/guardrails.md\`. Never delete an enforcement (hook / deny) for firing 0 times. An instruction with 0 loads is a candidate for removal."
exit 0
