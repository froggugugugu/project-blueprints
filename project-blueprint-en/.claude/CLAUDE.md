# Development Guide (Claude Code)

Tool-agnostic development rules live in `AGENTS.md` (imported on the next line). This file holds only Claude Code-specific mechanisms (skills / teams / subagents / hooks / permissions).

@AGENTS.md

> **Slim "core"** (Pro-plan friendly). Skills / teams / agents read detailed procedures when needed (never via a line-start `@` in a skill, which attaches the file in full).
> Keep a line only if removing it would make Claude make mistakes (official guidance). Tool-agnostic rules go in `AGENTS.md`.

## Skill catalog (all arguments optional)

| Skill | Purpose / trigger |
| ----- | ----------------- |
| `/brainstorm <requirement-note>` | Pre-`/prd` Socratic clarification (read-only) |
| `/prd <file>` | PRD generation from requirement notes (read-only) |
| `/architecture <file>` | System architecture design (read-only) |
| `/plan <description or file>` | Design document generation (read-only) |
| `/adr <decision-title>` | Record design decision rationale |
| `/implementing-features <task>` | Feature implementation / bug fixes via TDD |
| `/ui-ux-design <target>` | Design-system-aware UI/UX implementation |
| `/hig-compliance <target>` | Apple HIG-based system-wide UI consistency |
| `/design-system-audit <target>` | Design token consistency audit |
| `/e2e-testing <feature>` | Playwright E2E test creation |
| `/code-review <target>` | Code review (read-only). The bundled version remains available as `/review` |
| `/security-scan <target>` | Vulnerability scan / OWASP / CVE audit (read-only) |
| `/legal-check <target>` | OSS license / privacy / IP compliance (read-only) |
| `/performance <target>` | Measurement-first performance optimization |
| `/refactoring <target>` | Large-scale restructuring / responsibility migration |
| `/review-fix <PR#>` | Auto-fix CodeRabbit/Copilot review comments (manual invocation only) |
| `/harness-refine <target or instruction>` | Self-score → improve → review the harness scaffolding (manual invocation only / JP-EN mirror parity required) |

Each skill reads details (`pitfalls.md` etc.) when needed and keeps its expected behavior in `evals/evals.json`. Use the bundled skills alongside them:
`/verify` (confirm against the running app) / `/btw` (side question kept out of context) / `/goal <condition>` (keep working until it holds) / `/batch` (parallel change across files).

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

## Rule hierarchy (`.claude/rules/`)

- No `paths:` = loaded in every session (only `git-conventions.md`)
- With `paths:` = loaded only when Claude touches a matching file (`document-management.md` / `workflow-advanced.md` / `harness-authoring.md`)
- Enable language- or layer-specific rules by copying a `.example` and editing its `paths:`
- Task-specific procedures belong in a skill, not in a rule. "Every time, always do X" belongs in a hook, not in an instruction

## Quality gate mechanics

- Each phase skill consults the gate criteria in `.claude/quality-gates.md` when needed
- `verify-gate.sh` detects an unverified stop (Stop) and an unverified completion mark (TaskCompleted) after source edits (standard = warning / strict = refused)
- Every skill ships `evals/evals.json` (typical + boundary). After changing a skill, compare with / without pass rates via `/skill-eval skill=<name>`

## Tool usage

- Research: Glob/Grep for code; for docs 1) `docs/` → 2) WebFetch official → 3) Context7 MCP → 4) WebSearch. Playwright MCP: E2E debugging / visual verification / draw.io MCP: diagrams

## Security (defense in depth)

- **Defense in depth**: sandbox (Layer 0, optional) → hooks (Layer 1) → deny/ask (Layer 2) → allow (Layer 3)
- **`--no-verify` prohibited / pushing with `--force` prohibited in principle**. Keep safety prohibitions here even if `AGENTS.md` repeats them (the docs do not say whether the classifier reads imported files)
- `.env`, private keys and `*.pem` are blocked from being read at all by `Read()` deny rules, and outbound, irreversible operations (push / merge / publish / apply) confirm every time via `ask`
- Even in auto mode (the default on Pro/Max/Team), `ask` always prompts and `deny` applies before the classifier. The classifier also reads this file
- Hooks remain active even with `--dangerously-skip-permissions`. `scan-harness.sh` detects changes to `constitution.md`
- SessionStart hook checks `project-config.md` / `docs/` / `settings.local.json` at session start and injects the head of `output/tasks/PROGRESS.md` when present
- Details (deny lists, protected files, permission design) live in `.claude/guardrails.md` and `.claude/permissions-guide.md`

## Phase-specific output styles

`.claude/output-styles/` ships 4 styles, switched via `/output-style <name>` (all set `keep-coding-instructions: true`): Requirements `phase-prd` / Design `phase-design` /
Implementation `phase-implementation` / Review `phase-review`. `statusLine` (`.claude/statusline.sh`) auto-displays current style and phase.

## Workflow control

### 1. Plan first

Start non-trivial tasks (3+ steps or architectural decisions) in plan mode. Skip planning when the diff can be described in one sentence. Include verification steps in the plan.

### 2. Subagent strategy

Definitions and selection guide: `.claude/agents/README.md` (not imported every session). `scope-guard.sh` enforces the write scope of the 3 write-capable agents.
Use subagents aggressively to avoid main-context bloat. 1 subagent = 1 task. Subagents run in the background by default and return only a summary.
After implementing, have a fresh-context review subagent (`/code-review`) report only gaps that affect correctness or the stated requirements.

### 3. Context preservation

`/rewind` restores files and conversation from a checkpoint (`fileCheckpointingEnabled`). Run `/clear` before an unrelated task.
After correcting the same issue twice, `/clear` and rewrite the prompt. On compaction, PreCompact backs the transcript up and
the marker dropped by PostCompact is collected on the next prompt to re-inject the core rules (see `.claude/guardrails.md`).

### 4. Detailed procedures (loaded only when needed)

Self-improvement loop / pre-completion verification / autonomous bug fixing / task management / long-running task details: `.claude/rules/workflow-advanced.md` (auto-loads when touching source).

## Compact instructions

When compacting, always preserve: the list of modified files / the verification commands run and their results /
unfinished tasks and the next step / design decisions adopted or rejected / the output-location conventions (`output/`). Raw tool output may be dropped.

## Project-specific info (always loaded)

@docs/project.md              <!-- Tech stack, commands, routing -->
@docs/architecture.md          <!-- Directory structure, test list -->
@docs/data-model.md            <!-- Schema, validation -->
@docs/development-patterns.md  <!-- Code conventions, patterns -->
