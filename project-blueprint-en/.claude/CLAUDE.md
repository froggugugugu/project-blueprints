# Development Guide

Cross-project development rules, quality standards, and workflows.
Referenced by all roles (PM / PdM / Developer / Reviewer / Tester).

> **This file is the slim "core"** (Pro-plan friendly).
> Each skill / team / agent loads its own details via `@import` when invoked.
> Project-specific parameters live in `project-config.md`.

## General

- Always respond in English
- Use subagents for research and debugging to conserve context
- Record important decisions periodically in markdown files
- CLAUDE.md contains only cross-cutting rules; details delegated to skills

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
| `/code-review <target>` | Code review (read-only) |
| `/security-scan <target>` | Vulnerability scan / OWASP / CVE audit (read-only) |
| `/legal-check <target>` | OSS license / privacy / IP compliance (read-only) |
| `/performance <target>` | Measurement-first performance optimization |
| `/refactoring <target>` | Large-scale restructuring / responsibility migration |
| `/review-fix <PR#>` | Auto-fix CodeRabbit/Copilot review comments |
| `/harness-refine <target or instruction>` | Self-score → improve → review the harness scaffolding (2 fixed rounds / JP-EN mirror parity required) |

Each skill loads its own details (`pitfalls.md`, `guardrails.md`, etc.) at invocation time.

## Team templates

Run a `TEAM_*.md` from `.claude/teams/` to launch a multi-agent team:

- Full lifecycle: `TEAM_PJM.md` (recommended)
- Feature dev: `TEAM_FEATURE.md` / QA: `TEAM_QA.md`
- Planning: `TEAM_PLANNING.md` / Design: `TEAM_DESIGN.md` / Refactor: `TEAM_REFACTOR.md`

Team launch auto-loads `.claude/teams/README.md` and `.claude/agents/README.md`.

> **Profile note**: `.claude/teams/` is only bundled with the `full` profile (`bash setup.sh <dir> --profile full`, the default). Under `minimal` / `standard` profiles this directory does not exist and team templates (`TEAM_*.md`) are unavailable. Individual `/skill` commands remain usable within whatever that profile bundles.

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

## Architecture governance

- Restrict dependency direction between layers; details in `project-config.md` §4.4
- Verify violations with the detection command (in `project-config.md`)
- Circular dependencies are prohibited

## Quality standards / gates

- TDD (when enabled in `project-config.md` §6), unit + E2E
- Coverage targets in `project-config.md` §6
- **5 quality gates**: PRD / Design / Task breakdown / Implementation / Verification (each is an optional human intervention point)
- Each phase skill loads `@.claude/quality-gates.md` at invocation to consult gate criteria

## Concurrent development

- Same-file simultaneous edits prohibited
- Shared-layer changes done sequentially
- `teammateMode`: `in-process` (fast) / `worktree` (isolated) in `settings.local.json`
- PJM team reads `input/`, generates deliverables in `output/`; PL handles task breakdown / assignment

## Implementation workflow

Requirements → Impact analysis → Test design → **🚏 Design Gate**
→ Implementation → Refactor → **🚏 Implementation Gate** → Self-review → **🚏 Final Gate**

## Implementation checklist (before submission)

- [ ] Data model/schema changes documented; UI behavior (editable vs read-only) defined
- [ ] Core algorithms (rounding/formatting/aggregation) clarified
- [ ] Acceptance-criteria correspondence shown / existing tests intact / edge cases considered
- [ ] `docs/` updated to reflect implementation, no dependency-direction violations, no `--no-verify`

## Communication standards

- Always provide rationale for technical decisions
- Present impact scope before starting spec changes
- Reply to review feedback with both fix and reason
- Mark uncertain assumptions as "[Assumption]"

## Tool usage

- Documentation lookup: 1) `docs/` → 2) WebFetch official → 3) Context7 MCP → 4) WebSearch
- Playwright MCP: E2E debugging / visual verification / draw.io MCP: diagrams

## Security

- Always validate user input / regularly check dependency CVEs
- **3-layer defense**: hooks (Layer 1) → deny (Layer 2) → allow (Layer 3)
- Hooks remain active even with `--dangerously-skip-permissions`
- SessionStart hook checks `project-config.md` / `docs/` / `settings.local.json` at session start
- Detailed deny lists, protected files, and permissions guide are loaded by security-related skills (`/security-scan`, etc.)
- Project-specific policy in `project-config.md` §10

> **Inviolable principles** (full text in `constitution.md` / `scan-harness.sh` blocks violations):
> ①Human↔AI separation / ②JP/EN mirror parity / ③5 quality gates preserved / ④3-layer separation (skill/team/agent) /
> ⑤3-layer defense preserved / ⑥CLAUDE.md ≤200 lines / ⑦No secrets committed

## Git operations

- `--no-verify` prohibited / `--force` prohibited in principle / on hook failure, fix the cause (don't disable hooks)
- Conventional Commits required (details loaded by `/review-fix` / `/implementing-features` from `@.claude/rules/git-conventions.md`)

## Phase-specific output styles

`.claude/output-styles/` ships 4 styles (switch via `/output-style phase-prd` etc.):

- Requirements: `phase-prd` / Design: `phase-design` / Implementation: `phase-implementation` / Review: `phase-review`

`statusLine` (`.claude/statusline.sh`) auto-displays current style and phase.

## Workflow control

### 1. Plan first

Start non-trivial tasks (3+ steps or architectural decisions) in plan mode. Include verification steps in the plan.

### 2. Research first

Check existing code, patterns, and official docs before implementing. Priority: Glob/Grep → WebFetch → Context7.

### 3. Subagent strategy

@.claude/agents/README.md  <!-- Project default subagent definitions and selection guide -->

Use subagents aggressively to avoid main-context bloat. 1 subagent = 1 task.

### 4. Detailed procedures (loaded only when needed)

Self-improvement loop / pre-completion verification / pursuit of elegance / autonomous bug fixing /
task management / core principles are loaded by individual skills from
`.claude/rules/workflow-advanced.md`.

## Project-specific info (always loaded)

@docs/project.md              <!-- Tech stack, commands, routing -->
@docs/architecture.md          <!-- Directory structure, test list -->
@docs/data-model.md            <!-- Schema, validation -->
@docs/development-patterns.md  <!-- Code conventions, patterns -->

> **Fallback**: If the above don't exist or are stubs (under 5 lines), refer to the corresponding sections in `project-config.md`.
