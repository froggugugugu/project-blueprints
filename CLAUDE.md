# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **template repository** (not a runnable application) providing Claude Code AI-collaborative development blueprints for web application projects. All documentation and instructions are written in **Japanese**. Always respond in Japanese when working on this project.

The blueprint is designed to be copied into target projects via the setup steps in `project-blueprint/README.md`.

## Repository Structure

```text
project-blueprints/
├── README.md                    # Root docs (Japanese)
├── README-en.md                 # Root docs (English)
├── CLAUDE.md                    # This file (repo-wide guidance)
├── project-blueprint/           # The Japanese blueprint template
│   ├── README.md                # Setup guide & quick start
│   ├── setup.sh                 # One-command setup script
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
│   │   ├── skills/              # 17 skill definitions (SKILL.md files)
│   │   ├── teams/               # 6 team templates (TEAM_*.md files)
│   │   ├── agents/              # 8 subagent definitions (.claude/agents/*.md)
│   │   ├── rules/               # Language/path-specific rule extensions (.example opt-in)
│   │   ├── hooks/               # 12 hook scripts (safety + observability; .sh count)
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

**Skill system** (17 skills in `.claude/skills/*/SKILL.md`): Each skill is a standalone prompt with a defined pipeline order: `/brainstorm` → `/prd` → `/architecture` → `/plan` → `/implementing-features` → `/code-review` + `/security-scan` + `/legal-check` + `/e2e-testing` + `/performance` + `/refactoring`. Auxiliary skills: `/ui-ux-design`, `/hig-compliance`, `/design-system-audit`, `/adr`, `/review-fix`, `/harness-refine` (meta-skill: self-diagnoses and refines the harness configuration). The `/prd` skill follows the spec-driven framing (specification first, technology later) aligned with GitHub Spec-Kit / BMAD-METHOD.

**Team system** (6 teams in `.claude/teams/TEAM_*.md`): Multi-agent orchestration templates. `TEAM_PJM.md` is the recommended full-lifecycle team (6 members, covers all 17 skills, 5 quality gates).

**Subagent layer** (8 agents in `.claude/agents/*.md`): Single-shot specialist delegation (`explorer`, `researcher`, `planner`, `security-reviewer`, `performance-analyst`, `doc-synchronizer`, `doc-writer`, `test-writer`). `researcher` handles external technical investigation; `doc-writer` authors new documents under `output/` (complementing `doc-synchronizer` which syncs existing `docs/`). Complements teams and skills with isolated-context execution.

**Hook system** (12 hook scripts in `.claude/hooks/*.sh`, 13 registered invocations in `settings.json`): Defense in depth across `PreToolUse` / `PostToolUse` / `SessionStart` / `SessionEnd` / `SubagentStop` / `PreCompact` / `UserPromptSubmit` / `Stop` / `Notification`. Mix of block / observe / notify / backup roles. See `.claude/guardrails.md`.

**MCP + GitHub Actions**: `.mcp.json.template` for project-shared MCP servers; `.github/workflows/claude-review.yml.template` for `@claude` PR review automation.

**Quality gates**: 5 checkpoints (post-PRD, post-design, post-task-decomposition, post-implementation, post-verification) where humans can review and approve.

## Build / Test / Lint

There are no build, test, or lint commands — this repository contains only Markdown templates and configuration files. Validation is manual review of template content and structure.

## Editing Guidelines

- Skill files follow a consistent structure: context loading, step-by-step workflow, output format, and gate definitions. Maintain this pattern when adding or modifying skills.
- `project-config.md` has 13 numbered sections (§1–§13; §13 defines the Opus/Sonnet/Haiku tier strategy). Skills reference these by section number — keep numbering stable.
- The `.claude/CLAUDE.md` is the development guide that gets moved to the target project root during setup. It references `project-config.md` sections and `docs/` files by convention.
- Team templates define roles, member counts, skill assignments, and phase workflows. Changes to skill names must be reflected in team templates.
- `docs/` files are stubs in this repo — they serve as templates showing the expected structure for AI to populate in target projects.
