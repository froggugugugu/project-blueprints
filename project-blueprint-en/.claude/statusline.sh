#!/usr/bin/env bash
# .claude/statusline.sh — Claude Code custom status line
#
# Displays: model name / git branch / inferred phase / output-style
# Claude Code pipes JSON via stdin and renders the first line of stdout.
# Official spec: https://code.claude.com/docs/en/statusline
#
# Phase is inferred from the most recently modified subdir of output/:
#   prd      → 📝 PRD
#   design   → 🎨 Design
#   tasks    → ✅ Tasks
#   reports  → 🔍 Review
#
# Fail-open policy: on any error, exit 0 with an empty line (never break the status bar).

set -uo pipefail
trap 'echo ""; exit 0' ERR

input=$(cat)

# Extract values from JSON without jq (POSIX-ish).
extract() {
  printf '%s' "$1" | grep -oE "\"$2\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 | sed 's/.*"\([^"]*\)"$/\1/'
}

model=$(extract "$input" "display_name")
project_dir=$(extract "$input" "project_dir")
output_style=$(extract "$input" "name")
[ -z "$project_dir" ] && project_dir=$(extract "$input" "current_dir")

branch=""
if [ -n "$project_dir" ] && [ -d "$project_dir/.git" ]; then
  branch=$(git -C "$project_dir" symbolic-ref --short HEAD 2>/dev/null || echo "")
fi

phase=""
if [ -n "$project_dir" ] && [ -d "$project_dir/output" ]; then
  # Restrict to directories only. `find -printf` is GNU-only; macOS BSD find does
  # not support it, so we use stat with portable fallbacks instead.
  latest=$(
    for d in "$project_dir/output"/*/; do
      [ -d "$d" ] || continue
      mtime=$(stat -c '%Y' "$d" 2>/dev/null || stat -f '%m' "$d" 2>/dev/null || echo 0)
      printf '%s %s\n' "$mtime" "$(basename "$d")"
    done | sort -rn | head -1 | cut -d' ' -f2-
  )
  case "$latest" in
    brainstorm) phase="🌱 Brainstorm" ;;
    prd)        phase="📝 PRD" ;;
    design)     phase="🎨 Design" ;;
    tasks)      phase="✅ Tasks" ;;
    reports)    phase="🔍 Review" ;;
  esac
fi

style_disp=""
case "$output_style" in
  phase-*) style_disp="🎯 ${output_style#phase-}" ;;
esac

sep=" · "
out=""
[ -n "$model" ]      && out="${out:+$out$sep}[$model]"
[ -n "$branch" ]     && out="${out:+$out$sep}⎇ $branch"
[ -n "$phase" ]      && out="${out:+$out$sep}$phase"
[ -n "$style_disp" ] && out="${out:+$out$sep}$style_disp"

printf '%s\n' "${out:-Claude Code}"
