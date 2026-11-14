# Development Guide (Claude Code)

Tool-agnostic development rules live in `AGENTS.md` (imported on the next line). This file holds only Claude Code-specific mechanisms (skills / teams / subagents / hooks / permissions).

@AGENTS.md

> **Slim "core"** (Pro-plan friendly). Skills / teams / agents read detailed procedures when needed (never via a line-start `@` in a skill, which attaches the file in full).
> Keep a line only if removing it would make Claude make mistakes (official guidance). Tool-agnostic rules go in `AGENTS.md`.

## Skills (descriptions and arguments appear in the skill listing, so this section holds only the order and the exceptions)

- Standard flow: `/brainstorm` → `/prd` → `/architecture` → `/plan` → `/implementing-features` →
  `/code-review` + `/security-scan` + `/legal-check` + `/e2e-testing` + `/performance` + `/refactoring`
- Auxiliary: `/ui-ux-design` / `/hig-compliance` / `/design-system-audit` / `/adr`. Manual invocation only: `/review-fix <PR#>` / `/harness-refine` (JP-EN mirror parity required)
- `/code-review` means this template's read-only skill. Call the bundled version as `/review`

Each skill reads details (`pitfalls.md` etc.) when needed and keeps its expected behavior in `evals/evals.json`. Use the bundled skills alongside them:
`/verify` (confirm against the running app) / `/btw` (side question kept out of context) / `/goal <condition>` (keep working until it holds) / `/batch` (parallel change across files) / `/loop` (default prompt in `.claude/loop.md`).

## Team templates

Run a `TEAM_*.md` from `.claude/teams/` to launch a multi-agent team:

- Full lifecycle: `TEAM_PJM.md` (recommended)
- Feature dev: `TEAM_FEATURE.md` / QA: `TEAM_QA.md`
- Planning: `TEAM_PLANNING.md` / Design: `TEAM_DESIGN.md` / Refactor: `TEAM_REFACTOR.md`

A team reads `.claude/teams/README.md` and `.claude/agents/README.md` at launch. For an exhaustive diff review, run the saved workflow `/review-sweep`.
`.claude/teams/` ships only with the `full` profile (the `setup.sh` default). `minimal` / `standard` profiles get individual skills only.

- Enable Agent Teams with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (off by default)
- `teammateMode` selects where teammates are **displayed** (`in-process` / `auto` / `tmux` / `iterm2`).
  To isolate the repository, use a subagent's `isolation: worktree`
- PJM team reads `input/`, generates deliverables in `output/`; PL handles task breakdown / assignment

## Rule hierarchy (source in `.agents/rules/`, loaded through the links in `.claude/rules/`)

- No `paths:` = loaded in every session (only `git-conventions.md`)
- With `paths:` = loaded only when Claude touches a matching file (`document-management.md` / `workflow-advanced.md` / `harness-authoring.md`)
- Enable language- or layer-specific rules by copying a `.example`, editing its `paths:` and running `setup.sh --relink` (the same after adding a skill)
- Task-specific procedures belong in a skill, not in a rule. "Every time, always do X" belongs in a hook, not in an instruction

## Quality gate mechanics

- Each phase skill consults the gate criteria in `.agents/quality-gates.md` when needed
- `verify-gate.sh` detects an unverified stop (Stop) and an unverified completion mark (TaskCompleted; the Task tools are enabled through `env` in `settings.json`) after source edits (standard = warning / strict = refused)
- Every skill ships `evals/evals.json` (typical + boundary). After changing a skill, compare with / without pass rates via `/skill-eval skill=<name>`; inventory the instruction files with `/doctor prompt-audit` and `/skill-doctor`

## Tool usage

- Research: Glob/Grep for code; for docs 1) `docs/` → 2) WebFetch official → 3) Context7 MCP → 4) WebSearch. Playwright MCP: E2E debugging / visual verification. Diagrams in mermaid (charts via the bundled `/dataviz`)

## Security (defense in depth)

- **Defense in depth**: sandbox (Layer 0, optional) → hooks (Layer 1) → deny/ask (Layer 2) → allow (Layer 3)
- **`--no-verify` prohibited / pushing with `--force` prohibited in principle**. Keep safety prohibitions here even if `AGENTS.md` repeats them (the docs do not say whether the classifier reads imported files)
- `.env`, private keys and `*.pem` are blocked from being read at all by `Read()` deny rules, and outbound, irreversible operations (push / merge / publish / apply) confirm every time via `ask`
- Even in auto mode (the default on every plan since v2.1.283), `ask` always prompts and `deny` applies before the classifier. The classifier also reads this file
- Hooks remain active even with `--dangerously-skip-permissions`. `scan-harness.sh` detects changes to `constitution.md`
- SessionStart hook checks `project-config.md` / `docs/` / `settings.local.json` at session start and injects the head of `output/tasks/PROGRESS.md` when present
- Details (deny lists, protected files, permission design) live in `.agents/guardrails.md` and `.claude/permissions-guide.md`

## Phase-specific output styles

`.claude/output-styles/` ships 4 styles, switched via `/output-style <name>` (all set `keep-coding-instructions: true`): Requirements `phase-prd` / Design `phase-design` /
Implementation `phase-implementation` / Review `phase-review`. `statusLine` (`.claude/statusline.sh`) auto-displays current style and phase.

## Workflow control

### 1. Plan first

Start non-trivial tasks (3+ steps or architectural decisions) in plan mode. Skip planning when the diff can be described in one sentence. Include verification steps in the plan.

### 2. Subagent strategy

Definitions and selection guide: `.claude/agents/README.md` (not imported every session). `scope-guard.sh` enforces the write scope of the 3 write-capable agents.
Delegate only work that is independent and parallelizable, reads a lot, or needs isolated verification. Do work that takes a handful of tool calls yourself (spawn depth is pinned to 1 in `settings.json`).
Right before declaring completion, run fresh-context `/code-review` (bugs) and the `verifier` agent (spec conformance) once each, have them report every finding, and act only on the MUSTs that affect correctness or the stated requirements.

### 3. Context preservation

`/rewind` restores files and conversation from a checkpoint (`fileCheckpointingEnabled`). Run `/clear` before an unrelated task.
After correcting the same issue twice, `/clear` and rewrite the prompt. On compaction, PreCompact backs the transcript up and
SessionStart (`compact`) re-injects the core rules right away. Rules with `paths:` and skill bodies fade in the summary (see `.agents/guardrails.md`).

### 4. Detailed procedures (loaded only when needed)

Self-improvement loop / pre-completion verification / autonomous bug fixing / task management / long-running task details: `.agents/rules/workflow-advanced.md` (auto-loads when touching source).

## Compact instructions

When compacting, always preserve: the list of modified files / the verification commands run and their results / unfinished tasks and the next step /
design decisions adopted or rejected and constraints the user stated (verbatim) / blockers hit and workarounds tried / the output-location conventions (`output/`). Raw tool output may be dropped.

## Project-specific info

Load every session only what the code cannot show (commands, conventions, gotchas). Importing does not reduce context cost (official memory guide).

@docs/project.md              <!-- Tech stack, commands, routing -->
@docs/development-patterns.md  <!-- Code conventions, patterns, past problems -->

Claude can read the structure and schema from the repository, so they are not loaded every session. Read them when needed:
`docs/architecture.md` — before a change that crosses layers or dependency direction, or before creating a new directory /
`docs/data-model.md` — before changing the schema, persistence, or validation
