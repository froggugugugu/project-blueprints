# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **template repository** (not a runnable application) providing Claude Code AI-collaborative development blueprints for web application projects. All documentation and instructions are written in **Japanese**. Always respond in Japanese when working on this project.

The blueprint is designed to be copied into target projects via the setup steps in `project-blueprint/README.md`.

## Repository Structure

```
project-blueprints/
├── README.md                    # Root docs (Japanese)
└── project-blueprint/           # The blueprint template
    ├── README.md                # Setup guide & quick start
    ├── project-config.md        # Template: human decisions (12 sections)
    ├── .claude/
    │   ├── CLAUDE.md            # Development guide (copied to target project root)
    │   ├── settings.json        # Plugin config (context7, playwright, etc.)
    │   ├── settings.local.json.template
    │   ├── skills/              # 11 skill definitions (SKILL.md files)
    │   ├── teams/               # 5 team templates (TEAM_*.md files)
    │   └── tasks/               # Task instruction templates
    ├── docs/                    # AI-managed technical docs (stubs)
    ├── input/                   # Human requirements input
    │   └── requirements/        # Requirement memos go here
    ├── output/                  # AI-generated deliverables
    │   ├── prd/                 # Phase 1: PRDs
    │   ├── design/              # Phase 2: Architecture docs
    │   ├── tasks/               # Phase 3: Task decomposition
    │   └── reports/             # Phase 5: Quality reports
    └── testreport/              # Tool raw output (.gitignore target)
```

## Architecture: Key Design Decisions

**Human vs AI separation**: `project-config.md` centralizes all human decisions (tech stack, quality standards, policies) in one file. AI generates and maintains `docs/`, `output/`, and `testreport/`.

**Input/Output flow**: `input/requirements/` (human-written, read-only for AI) → AI processing → `output/` (AI-generated, human reviews at quality gates).

**Generic vs project-specific**: Everything under `.claude/` is reusable across projects. `docs/`, `input/`, `output/` are project-specific and generated per-use.

**Skill system** (11 skills in `.claude/skills/*/SKILL.md`): Each skill is a standalone prompt with a defined pipeline order: `/prd` → `/architecture` → `/plan` → `/implementing-features` → `/code-review` + `/security-scan` + `/e2e-testing` + `/performance`.

**Team system** (5 teams in `.claude/teams/TEAM_*.md`): Multi-agent orchestration templates. `TEAM_PJM.md` is the recommended full-lifecycle team (6 members, all 11 skills, 5 quality gates).

**Quality gates**: 5 checkpoints (post-PRD, post-design, post-task-decomposition, post-implementation, post-verification) where humans can review and approve.

## Build / Test / Lint

There are no build, test, or lint commands — this repository contains only Markdown templates and configuration files. Validation is manual review of template content and structure.

## Editing Guidelines

- Skill files follow a consistent structure: context loading, step-by-step workflow, output format, and gate definitions. Maintain this pattern when adding or modifying skills.
- `project-config.md` has 12 numbered sections (§1–§12). Skills reference these by section number — keep numbering stable.
- The `.claude/CLAUDE.md` is the development guide that gets moved to the target project root during setup. It references `project-config.md` sections and `docs/` files by convention.
- Team templates define roles, member counts, skill assignments, and phase workflows. Changes to skill names must be reflected in team templates.
- `docs/` files are stubs in this repo — they serve as templates showing the expected structure for AI to populate in target projects.
