# AGENTS.md

Development rules shared by every coding agent (tool-agnostic). Claude Code, the primary agent, imports it through `@AGENTS.md` in `CLAUDE.md`;
Codex / Cursor read it by default, and Copilot / Gemini CLI and others need configuration (`project-config.md` §13.7).
Claude Code-specific mechanisms (skills / teams / subagents / hooks / permissions) belong in `CLAUDE.md`.

## General

- Always respond in English
- **Attach evidence to every completion report** (test output, the command run and its result, screenshots). A "done" without evidence is not allowed
- Before starting, read `project.md` / `architecture.md` / `data-model.md` / `development-patterns.md` under `docs/` (Claude Code loads them automatically). If they don't exist or are stubs (under 5 lines), refer to the corresponding sections in `project-config.md`

## Development principles

- For ambiguous specs, never proceed by guessing — present 1-2 options and confirm
- When the user describes a problem, asks a question, or thinks out loud, deliver an assessment; apply a fix only when asked
- Delete or overwrite user data only when explicitly required by spec
- Separate stored vs displayed values in data model and UI when they differ
- Be deterministic (define rounding, formatting, aggregation scope)
- Avoid over-engineering — implement the minimum complexity needed
- Don't duplicate in docs what can be read from code
- Check existing code, patterns, and official docs before implementing. Prefer CLI tools (`gh` / `aws` / `gcloud` etc.) for external services

## Document management (short)

- **Human-managed**: `project-config.md` (13 sections) / `input/requirements/` / `constitution.md` (repo root)
- **AI-managed**: `docs/*.md` (project-derived info) / `output/` (deliverables) / `testreport/` (raw tool data)
- **AI-mutable sections**: `project-config.md` §2 (Tech Stack) / §3 (Commands) / §11 (Known Pitfalls) only. §1 / §4-§10 / §12 / §13 are human-decision areas (immutable to AI)
- **Primary owner**: `docs/*.md` and `project-config.md` §2/§3 are consolidated by the implementation task (`/implementing-features`). Other tasks only report findings
- **Details** (conflict-prevention tables / docs update rules): read `.claude/rules/document-management.md` before editing `docs/` or `output/`

## Architecture governance

- Restrict dependency direction between layers; details in `project-config.md` §4.4
- Verify violations with the detection command (in `project-config.md`)
- Circular dependencies are prohibited

## Quality standards / gates

- TDD (when enabled in `project-config.md` §6), unit + E2E. Coverage targets in `project-config.md` §6
- **5 quality gates**: PRD / Design / Task breakdown / Implementation / Verification (each is an optional human intervention point). Criteria in `.claude/quality-gates.md`
- **Set up the verification first**: before starting, decide on a check that returns pass/fail (tests / build / lint / screenshot comparison) and paste its result when done

## Implementation workflow

Requirements → Impact analysis → Test design → **🚏 Design Gate** → Implementation → Refactor → **🚏 Implementation Gate** → Self-review → **🚏 Final Gate**

- Same-file simultaneous edits prohibited. Shared-layer changes done sequentially
- Work spanning multiple sessions is handed over through `output/tasks/PROGRESS.md` (template: `.claude/tasks/PROGRESS_TEMPLATE.md`).
  One feature per session, smoke-test before starting, and finish with tests green + a commit + PROGRESS updated

## Implementation checklist (before submission)

- [ ] Data model/schema changes documented; UI behavior (editable vs read-only) defined
- [ ] Core algorithms (rounding/formatting/aggregation) clarified
- [ ] Acceptance-criteria correspondence shown / existing tests intact / edge cases considered
- [ ] `docs/` updated to reflect implementation, no dependency-direction violations, no `--no-verify`
- [ ] Verification command results (pass/fail counts, error counts) attached to the report

## Communication standards

- Always provide rationale for technical decisions / present impact scope before starting spec changes
- Reply to review feedback with both fix and reason / mark uncertain assumptions as "[Assumption]"

## Security

- Always validate user input / regularly check dependency CVEs
- Never read or commit `.env`, private keys, or `*.pem`
- Confirm with a human every time before outbound, irreversible operations (push / merge / publish / apply)
- Project-specific policy in `project-config.md` §10

> **Inviolable principles** (full text in `constitution.md`): ①Human↔AI separation / ②JP/EN mirror parity / ③5 quality gates preserved /
> ④3-layer separation (skill/team/agent) / ⑤3-layer defense preserved / ⑥CLAUDE.md + AGENTS.md ≤200 lines / ⑦No secrets committed

## Git operations

- `--no-verify` prohibited / `--force` prohibited in principle / on hook failure, fix the cause (don't disable hooks)
- Conventional Commits required. Read `.claude/rules/git-conventions.md` before committing (Claude Code always loads it)

## Using this outside Claude Code

- Follow the role and write scope that `project-config.md` §13.7 assigns to your agent. If it is not marked `yes` there, act read-only
- The safety mechanisms under `.claude/` (hooks, deny/ask rules, write-scope enforcement) run only in Claude Code. Follow the security and Git rules above yourself
- Slash commands such as `/prd` are unavailable. The same procedure lives in `.claude/skills/<name>/SKILL.md`;
  read and follow it when asked. Replace Claude Code-only features such as subagents with sequential steps of your own
