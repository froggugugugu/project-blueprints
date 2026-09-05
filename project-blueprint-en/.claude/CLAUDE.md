# Development Guide

Cross-project development rules, quality standards, and workflows.
Referenced by all roles (PM / PdM / Developer / Reviewer / Tester).

> **This file is the slim "core"** (Pro-plan friendly).
> Each skill / team / agent loads its own details via `@import` when invoked.
> Project-specific parameters live in `project-config.md`.
> Keep a line only if removing it would make Claude make mistakes (official guidance).

## General

- Always respond in English
- Use subagents for research and debugging to conserve context
- Record important decisions periodically in markdown files
- CLAUDE.md contains only cross-cutting rules; details delegated to skills
- **Attach evidence to every completion report** (test output, the command run and its result, screenshots). A "done" without evidence is not allowed

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

Each skill loads its own details (`pitfalls.md`, `guardrails.md`, etc.) at invocation time. Use the bundled skills alongside them:
`/verify` (confirm against the running app) / `/btw` (side question kept out of context) / `/goal <condition>` (keep working until it holds) / `/batch` (parallel change across files).

## Team templates

Run a `TEAM_*.md` from `.claude/teams/` to launch a multi-agent team:

- Full lifecycle: `TEAM_PJM.md` (recommended)
- Feature dev: `TEAM_FEATURE.md` / QA: `TEAM_QA.md`
- Planning: `TEAM_PLANNING.md` / Design: `TEAM_DESIGN.md` / Refactor: `TEAM_REFACTOR.md`

Team launch auto-loads `.claude/teams/README.md` and `.claude/agents/README.md`.
`.claude/teams/` ships only with the `full` profile (the `setup.sh` default). `minimal` / `standard` profiles get individual skills only.

## Development principles

- For ambiguous specs, never proceed by guessing — present 1-2 options and confirm
- Delete or overwrite user data only when explicitly required by spec
- Separate stored vs displayed values in data model and UI when they differ
- Be deterministic (define rounding, formatting, aggregation scope)
- Avoid over-engineering — implement the minimum complexity needed
- Don't duplicate in docs what can be read from code

## Document management (short)

- **Human-managed**: `project-config.md` (13 sections) / `input/requirements/` / `constitution.md` (repo root)
- **AI-managed**: `docs/*.md` (project-derived info) / `output/` (deliverables) / `testreport/` (raw tool data)
- **AI-mutable sections**: `project-config.md` §2 (Tech Stack) / §3 (Commands) / §11 (Known Pitfalls) only. §1 / §4-§10 / §12 / §13 are human-decision areas (immutable to AI)
- **Primary owner**: `docs/*.md` and `project-config.md` §2/§3 are consolidated by `/implementing-features`. Other skills only report findings
- **Details** (conflict-prevention tables / docs update rules): `/implementing-features` loads `@.claude/rules/document-management.md` at invocation

## Rule hierarchy (`.claude/rules/`)

- No `paths:` = loaded in every session (only `git-conventions.md`)
- With `paths:` = loaded only when Claude touches a matching file (`document-management.md` / `workflow-advanced.md`)
- Enable language- or layer-specific rules by copying a `.example` and editing its `paths:`
- Task-specific procedures belong in a skill, not in a rule. "Every time, always do X" belongs in a hook, not in an instruction

## Architecture governance

- Restrict dependency direction between layers; details in `project-config.md` §4.4
- Verify violations with the detection command (in `project-config.md`)
- Circular dependencies are prohibited

## Quality standards / gates

- TDD (when enabled in `project-config.md` §6), unit + E2E
- Coverage targets in `project-config.md` §6
- **5 quality gates**: PRD / Design / Task breakdown / Implementation / Verification (each is an optional human intervention point)
- Each phase skill loads `@.claude/quality-gates.md` at invocation to consult gate criteria
- **Set up the verification first**: before starting, decide on a check that returns pass/fail (tests / build / lint / screenshot comparison) and paste its result when done
- The Stop hook `verify-gate.sh` detects a turn ending after source edits without a verification command (standard = warning / strict = sent back once)

## Concurrent development

- Same-file simultaneous edits prohibited
- Shared-layer changes done sequentially
- Enable Agent Teams with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (off by default)
- `teammateMode` selects where teammates are **displayed** (`in-process` / `auto` / `tmux` / `iterm2`).
  To isolate the repository, use a subagent's `isolation: worktree`
- PJM team reads `input/`, generates deliverables in `output/`; PL handles task breakdown / assignment

## Implementation workflow

Requirements → Impact analysis → Test design → **🚏 Design Gate** → Implementation → Refactor → **🚏 Implementation Gate** → Self-review → **🚏 Final Gate**

## Implementation checklist (before submission)

- [ ] Data model/schema changes documented; UI behavior (editable vs read-only) defined
- [ ] Core algorithms (rounding/formatting/aggregation) clarified
- [ ] Acceptance-criteria correspondence shown / existing tests intact / edge cases considered
- [ ] `docs/` updated to reflect implementation, no dependency-direction violations, no `--no-verify`
- [ ] Verification command results (pass/fail counts, error counts) attached to the report

## Communication standards

- Always provide rationale for technical decisions / present impact scope before starting spec changes
- Reply to review feedback with both fix and reason / mark uncertain assumptions as "[Assumption]"

## Tool usage

- Documentation lookup: 1) `docs/` → 2) WebFetch official → 3) Context7 MCP → 4) WebSearch
- Playwright MCP: E2E debugging / visual verification / draw.io MCP: diagrams
- Prefer CLI tools (`gh` / `aws` / `gcloud` etc.) for external services (the most context-efficient path)

## Security

- Always validate user input / regularly check dependency CVEs
- **Defense in depth**: sandbox (Layer 0, optional) → hooks (Layer 1) → deny/ask (Layer 2) → allow (Layer 3)
- `.env`, private keys and `*.pem` are blocked from being read at all by `Read()` deny rules
- Outbound, irreversible operations (push / merge / publish / apply) confirm every time via `ask`
- Even in auto mode (the default on Pro/Max/Team), `ask` always prompts and `deny` applies before the classifier. The classifier also reads this file
- Hooks remain active even with `--dangerously-skip-permissions`
- SessionStart hook checks `project-config.md` / `docs/` / `settings.local.json` at session start and injects the head of `output/tasks/PROGRESS.md` when present
- Detailed deny lists, protected files, and permissions guide are loaded by security-related skills (`/security-scan`, etc.)
- Project-specific policy in `project-config.md` §10

> **Inviolable principles** (full text in `constitution.md` / `scan-harness.sh` blocks violations):
> ①Human↔AI separation / ②JP/EN mirror parity / ③5 quality gates preserved / ④3-layer separation (skill/team/agent) /
> ⑤3-layer defense preserved / ⑥CLAUDE.md ≤200 lines / ⑦No secrets committed

## Git operations

- `--no-verify` prohibited / `--force` prohibited in principle / on hook failure, fix the cause (don't disable hooks)
- Conventional Commits required (details loaded by `/review-fix` / `/implementing-features` from `@.claude/rules/git-conventions.md`)

## Phase-specific output styles

`.claude/output-styles/` ships 4 styles (switch via `/output-style phase-prd` etc.; all set `keep-coding-instructions: true`):

- Requirements: `phase-prd` / Design: `phase-design` / Implementation: `phase-implementation` / Review: `phase-review`

`statusLine` (`.claude/statusline.sh`) auto-displays current style and phase.

## Workflow control

### 1. Plan first

Start non-trivial tasks (3+ steps or architectural decisions) in plan mode. Skip planning when the diff can be described in one sentence. Include verification steps in the plan.

### 2. Research first

Check existing code, patterns, and official docs before implementing. Priority: Glob/Grep → WebFetch → Context7.

### 3. Subagent strategy

@.claude/agents/README.md  <!-- Project default subagent definitions and selection guide -->

Use subagents aggressively to avoid main-context bloat. 1 subagent = 1 task. Subagents run in the background by default and return only a summary.
After implementing, have a fresh-context review subagent (`/code-review`) report only gaps that affect correctness or the stated requirements.

### 4. Context preservation

`/rewind` restores files and conversation from a checkpoint (`fileCheckpointingEnabled`). Run `/clear` before an unrelated task.
After correcting the same issue twice, `/clear` and rewrite the prompt. On compaction, PreCompact backs the transcript up and
the marker dropped by PostCompact is collected on the next prompt to re-inject the core rules (see `@.claude/guardrails.md`).

### 5. Long-running task handoff

Work spanning multiple sessions is handed over through `output/tasks/PROGRESS.md` (template: `.claude/tasks/PROGRESS_TEMPLATE.md`).
One feature per session, smoke-test before starting, and finish with tests green + a commit + PROGRESS updated.

### 6. Detailed procedures (loaded only when needed)

Self-improvement loop / pre-completion verification / autonomous bug fixing / task management / long-running task details are loaded by individual skills from `.claude/rules/workflow-advanced.md`.

## Compact instructions

When compacting, always preserve: the list of modified files / the verification commands run and their results /
unfinished tasks and the next step / design decisions adopted or rejected / the output-location conventions (`output/`). Raw tool output may be dropped.

## Project-specific info (always loaded)

@docs/project.md              <!-- Tech stack, commands, routing -->
@docs/architecture.md          <!-- Directory structure, test list -->
@docs/data-model.md            <!-- Schema, validation -->
@docs/development-patterns.md  <!-- Code conventions, patterns -->

> **Fallback**: If the above don't exist or are stubs (under 5 lines), refer to the corresponding sections in `project-config.md`.
