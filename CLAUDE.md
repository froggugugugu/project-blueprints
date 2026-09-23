# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **template repository** (not a runnable application) providing a Claude Code AI-collaborative development harness. It is stack-agnostic: the blueprint ships instructions, skills, subagents, guardrails and a validation gate, never application code. All documentation and instructions are written in **Japanese**. Always respond in Japanese when working on this project.

The blueprint is designed to be copied into target projects via the setup steps in `project-blueprint/README.md`.

## Repository Structure

```text
project-blueprints/
├── README.md                    # Root docs (Japanese)
├── README-en.md                 # Root docs (English)
├── CLAUDE.md                    # This file (repo-wide guidance)
├── constitution.md              # Inviolable principles (7)
├── .github/
│   ├── pages/                   # GitHub Pages source (index.html, en/index.html, assets/, _config.yml)
│   ├── demo/                    # quickstart.gif used by the READMEs and the site
│   └── workflows/               # validate-harness.yml (CI gate) + pages.yml (site deploy)
├── scripts/                     # Harness validator (CI gate) — see Build / Test / Lint
│   ├── validate-harness.sh      # Entry point
│   ├── validate_harness.py      # Checks
│   └── test_validate_harness.py # Negative tests for the checks
├── project-blueprint/           # The Japanese blueprint template
│   ├── README.md                # Setup guide & quick start
│   ├── setup.sh                 # One-command setup script
│   ├── AGENTS.md                # Tool-agnostic rules (copied to target root; imported by CLAUDE.md via @AGENTS.md)
│   ├── project-config.md        # Template: human decisions (13 sections)
│   ├── .mcp.json.template       # Project-shared MCP server config template
│   ├── .github/workflows/       # Claude Code PR review workflow template
│   ├── .claude/
│   │   ├── CLAUDE.md            # Development guide (copied to target project root)
│   │   ├── settings.json        # Hooks + plugin config (context7, playwright, etc.)
│   │   ├── settings.local.json.template
│   │   ├── guardrails.md        # Safety mechanism overview
│   │   ├── quality-gates.md     # Quality gate definitions
│   │   ├── pitfalls.md          # Common failure patterns (anti-patterns)
│   │   ├── skills/              # 17 skill definitions (SKILL.md + evals/evals.json)
│   │   ├── teams/               # 6 team templates (TEAM_*.md files)
│   │   ├── workflows/           # 2 saved dynamic workflows (review-sweep.js, skill-eval.js; full profile only)
│   │   ├── agents/              # 8 subagent definitions (.claude/agents/*.md)
│   │   ├── rules/               # Language/path-specific rule extensions (.example opt-in)
│   │   ├── hooks/               # 16 hook scripts (safety + observability + verification gate + agent scope guard; .sh count)
│   │   └── tasks/               # Task instruction templates
│   ├── docs/                    # AI-managed technical docs (stubs)
│   ├── input/                   # Human requirements input
│   │   └── requirements/        # Requirement memos go here
│   ├── output/                  # AI-generated deliverables
│   │   ├── prd/                 # Phase 1: PRDs
│   │   ├── design/              # Phase 2: Architecture docs
│   │   ├── tasks/               # Phase 3: Task decomposition
│   │   └── reports/             # Phase 5: Quality reports
│   └── testreport/              # Tool raw output (.gitignore target)
└── project-blueprint-en/        # English mirror of the blueprint (same structure)
```

## Architecture: Key Design Decisions

**Human vs AI separation**: `project-config.md` centralizes all human decisions (tech stack, quality standards, policies) in one file. AI generates and maintains `docs/`, `output/`, and `testreport/`.

**Input/Output flow**: `input/requirements/` (human-written, read-only for AI) → AI processing → `output/` (AI-generated, human reviews at quality gates).

**Generic vs project-specific**: Everything under `.claude/` is reusable across projects. `docs/`, `input/`, `output/` are project-specific and generated per-use.

**Skill system** (17 skills in `.claude/skills/*/SKILL.md`): Each skill is a standalone prompt with a defined pipeline order: `/brainstorm` → `/prd` → `/architecture` → `/plan` → `/implementing-features` → `/code-review` + `/security-scan` + `/legal-check` + `/e2e-testing` + `/performance` + `/refactoring`. Auxiliary skills: `/ui-ux-design`, `/hig-compliance`, `/design-system-audit`, `/adr`, `/review-fix`, `/harness-refine` (meta-skill: self-diagnoses and refines the harness configuration). The `/prd` skill follows the spec-driven framing (specification first, technology later) aligned with GitHub Spec-Kit / BMAD-METHOD. Every skill ships `evals/evals.json` (agentskills.io format: a typical case and a boundary case with verifiable assertions, run via the skill-creator plugin). Descriptions follow the official "what it does + when to use it" pattern because the skill listing is capped at 1% of context, and skills never use a line-start `@path` (Claude Code attaches that file in full at invocation); they list references with a reading condition instead. Writing conventions live in the path-scoped rule `.claude/rules/harness-authoring.md`.

**Team system** (6 teams in `.claude/teams/TEAM_*.md`): Multi-agent orchestration templates. `TEAM_PJM.md` is the recommended full-lifecycle team (6 members, covers the 13 core lifecycle skills, 5 quality gates). The 4 auxiliary skills (`/design-system-audit`, `/adr`, `/review-fix`, `/harness-refine`) are invoked on demand outside the standard team flow. `.claude/workflows/review-sweep.js` is the scripted form of the team layer: a saved dynamic workflow that reviews a diff from 4 angles in parallel and adversarially verifies each MUST finding with 3 votes. `skill-eval.js` runs a skill's `evals/evals.json` with and without the skill and compares pass rates, so skill edits are judged on numbers rather than impressions.

**Subagent layer** (8 agents in `.claude/agents/*.md`): Single-shot specialist delegation (`explorer`, `researcher`, `planner`, `security-reviewer`, `performance-analyst`, `doc-synchronizer`, `doc-writer`, `test-writer`). `researcher` handles external technical investigation; `doc-writer` authors new documents under `output/` (complementing `doc-synchronizer` which syncs existing `docs/`). Complements teams and skills with isolated-context execution.

**Hook system** (16 hook scripts in `.claude/hooks/*.sh`, 19 registered invocations in `settings.json` plus 3 agent-frontmatter registrations of `scope-guard.sh`): Defense in depth across `PreToolUse` / `PostToolUse` / `PostToolUseFailure` / `PermissionDenied` / `TaskCompleted` / `SessionStart` / `SessionEnd` / `SubagentStart` / `SubagentStop` / `PreCompact` / `PostCompact` / `UserPromptSubmit` / `Stop` / `Notification`. Mix of block / observe / notify / backup / gate roles. `verify-gate.sh` (PostToolUse + Stop + TaskCompleted) is the deterministic verification gate from the official best practices; `permission-denied-log.sh` records auto mode denials. See `.claude/guardrails.md`.

**Distribution**: `setup.sh` + clone only. Plugin packaging was evaluated twice (adopted 2026-04, withdrawn 2026-06, re-evaluated and withdrawn again 2026-08) and does not fit: a plugin can only declare `skills`/`agents`/`outputStyles`/`hooks`, while **17 of 17 skills reference files a plugin cannot ship** (`docs/` 16, `output/` 15, `quality-gates.md` 15, `project-config.md` 14, `pitfalls.md` 12, `.claude/rules/` 3). Do not re-open this without new evidence that those dependencies have gone away.

**MCP + GitHub Actions**: `.mcp.json.template` for project-shared MCP servers. Two workflow templates: `claude-review.yml.template` (conversational `@claude` PR review via `anthropics/claude-code-action`) and `claude-skills-ci.yml.template` (headless `claude -p` running `/code-review` and `/security-scan` on every PR, with `--permission-mode dontAsk` and no `--bare` so the project's `.claude/` loads), plus `claude-scheduled-audit.yml.template` (weekly `/security-scan` + `/legal-check` into a GitHub Issue). Durable scheduling belongs on Actions, not on session-scoped `/loop`/`CronCreate`, which fire only while a session is idle and expire after 7 days.

**Quality gates**: 5 checkpoints (post-PRD, post-design, post-task-decomposition, post-implementation, post-verification) where humans can review and approve.

## Build / Test / Lint

There is no application build. The check that gates this repository is the harness validator:

```bash
bash scripts/validate-harness.sh          # both mirrors + JP/EN structural parity
bash scripts/validate-harness.sh --online # also resolve the npm packages in .mcp.json.template
bash scripts/validate-harness.sh --test   # negative tests for the validator itself
bash scripts/validate-harness.sh --hooks  # functional tests of the hook scripts (feeds hook JSON on stdin; needs jq)
```

It is deterministic (no LLM) and enforces the parts of the official spec that are easy to
drift from: frontmatter values outside the official enums, permission rules the runtime
never consults (`Write(path)` and friends), hook registrations pointing at missing scripts,
unresolved `@import` targets, the constitution hash, JP/EN parity, line-start `@` attachments in skills, description length and person, `evals/evals.json` schema, reference-file ToCs and linkage from SKILL.md, skill body length, workflow `meta` / determinism rules, agent-frontmatter hooks (including a WARN for write-capable agents without `scope-guard.sh`), and the `AGENTS.md` split (the `@AGENTS.md` import in CLAUDE.md, no line-start `@` in AGENTS.md, every cited `project-config.md` § exists, combined line budget). Run it before every
commit that touches `.claude/`. CI runs it on push and pull request
(`.github/workflows/validate-harness.yml`).

`/harness-refine` is the LLM-driven counterpart and runs *after* this gate passes.

## Editing Guidelines

- Skill files follow a consistent structure: context loading, step-by-step workflow, output format, and gate definitions. Maintain this pattern when adding or modifying skills.
- `project-config.md` has 13 numbered sections (§1–§13; §13 defines the Opus/Sonnet/Haiku tier strategy, and §13.7 the roles and write scopes of agents other than Claude Code). Skills reference these by section number — keep numbering stable.
- The `.claude/CLAUDE.md` is the development guide that gets moved to the target project root during setup. It references `project-config.md` sections and `docs/` files by convention.
- Tool-agnostic rules (principles, document management, quality standards, Git, security rules) live in the blueprint's `AGENTS.md`, which other coding agents read directly; `.claude/CLAUDE.md` imports it with `@AGENTS.md` and holds only Claude Code-specific mechanisms. Claude Code stays the primary agent; other agents follow `project-config.md` §13.7 and act read-only unless marked `yes` there. Safety prohibitions are kept in `CLAUDE.md` itself as well, because the docs do not say whether the auto mode classifier reads imported files. The validator enforces the import, forbids line-start `@` in `AGENTS.md`, checks that every `project-config.md` § they cite exists, and counts both files against the 200-line budget.
- Team templates define roles, member counts, skill assignments, and phase workflows. Changes to skill names must be reflected in team templates.
- `docs/` files are stubs in this repo — they serve as templates showing the expected structure for AI to populate in target projects.
