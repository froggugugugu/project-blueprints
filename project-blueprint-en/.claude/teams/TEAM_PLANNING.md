# Team Definition — Planning

## Overview

A team for the pre-implementation design phase. Creates PRD, architecture design, task breakdown, and UI design from requirement notes, producing handoff documents for the implementation team. **Never modifies source code.**

## Usage

```text
.claude/teams/TEAM_PLANNING.md <requirement-note-file-path or design instruction>
```

Arguments are optional. When omitted, the PL checks `input/requirements/` and identifies the target file.

### Examples

```text
# File specification (recommended)
.claude/teams/TEAM_PLANNING.md input/requirements/REQ_001.md

# Instruction specification
.claude/teams/TEAM_PLANNING.md PRD, design, and task breakdown for user authentication feature

# Start from PRD (skip requirements analysis)
.claude/teams/TEAM_PLANNING.md output/prd/PRD_auth.md

# No arguments
.claude/teams/TEAM_PLANNING.md
```

## Team Composition

| Role | Agent Type | Model | Skills | Permissions |
| --- | --- | --- | --- | --- |
| **PL (Leader)** | general-purpose | Opus | — | delegate |
| **Requirements Analyst** | general-purpose, mode: plan | Sonnet | `prd` | plan required (PL approves), source code read-only |
| **Architect** | general-purpose, mode: plan | Sonnet | `architecture` | plan required (PL approves), source code read-only |
| **Planner** | general-purpose, mode: plan | Sonnet | `plan` | plan required (PL approves), source code read-only |

## Role Responsibilities

### PL (Leader)

- Review requirement note input files and determine the design phase scope
- Create design task list with TaskCreate and set dependencies
- Review each member's deliverables and verify consistency
- Resolve ambiguous specification decisions
- Hand off the complete deliverable set to the implementation team
- **Do not write design documents yourself**

### Requirements Analyst

- Generate PRD from requirement notes
- Skills used: `/prd <file-path>`
- Structure user stories, acceptance criteria, and priorities
- Report ambiguous requirements as "[Needs Confirmation]" to PL
- **Do not modify source code**

### Architect

- Design system architecture based on the PRD
- Skills used: `/architecture <file-path>`
- Design directory structure, data model, and dependency direction rules
- Present technology choices as options with rationale, defer to PL for decisions
- **Do not modify source code**

### Planner

- Break down implementation tasks based on architecture design
- Skills used: `/plan`
- Analyze inter-task dependencies and parallelization potential
- Define test strategy
- Output task breakdown document to `output/tasks/PLAN_<feature-name>.md`
- **Do not modify source code**

## Workflow

```text
PL: Review requirement notes → Create design task list & assign
  |
  v
Requirements Analyst: Generate PRD from notes with /prd → Submit to PL
  |
  v
PL: Review & approve PRD
  |
  v (Parallelizable)
  +-- Architect: Architecture design with /architecture → Submit to PL
  +-- Planner: Task breakdown & test strategy with /plan → Submit to PL
  |
  v
PL: Verify deliverable consistency → Hand off to implementation team
```

### Dependency Rules

| Prerequisite | Next Step |
| --- | --- |
| Requirement note input | Requirements Analyst starts PRD generation |
| PRD approved | Architect and Planner start in parallel |
| All deliverables complete | PL final review |

## Deliverables

| Deliverable | Owner | Output Destination |
| --- | --- | --- |
| PRD | Requirements Analyst | `output/prd/PRD_<feature-name>.md` |
| Architecture Design Doc | Architect | `output/design/ARCH_<feature-name>.md` |
| Task Breakdown & Test Strategy | Planner | `output/tasks/PLAN_<feature-name>.md` |

## Completion Criteria

- [ ] Requirements Analyst: PRD generation complete, all ambiguous requirements resolved
- [ ] Architect: Architecture design complete, technology selections confirmed
- [ ] Planner: Task breakdown complete, dependency and parallelization analysis complete
- [ ] PL: Consistency check of all deliverables complete

## Handoff to Subsequent Teams

After design completion, hand off task files to the following teams:

| Subsequent Team | Template | Purpose |
| --- | --- | --- |
| Feature Development Team | `TEAM_FEATURE.md` | Feature implementation |
| Refactoring Team | `TEAM_REFACTOR.md` | When structural changes are needed |

## Tech Stack Reference

All team members must read `.claude/CLAUDE.md` and follow the project's tech stack and conventions.
