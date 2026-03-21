# Team Definition — Design System

## Overview

A team that specializes in defining design systems, auditing consistency, and ensuring UI coherence. Handles design token creation, cross-feature design consistency auditing, and individual UI review/implementation as a unified workflow. **Ideal for cross-screen audits of existing screens or bootstrapping a new design system.**

## Usage

```text
.claude/teams/TEAM_DESIGN.md <target scope or design instruction>
```

Arguments are optional. When omitted, the PL interactively identifies the target.

### Examples

```text
# System-wide design consistency audit
.claude/teams/TEAM_DESIGN.md Audit and fix design consistency across the entire system

# Specific feature UI improvement
.claude/teams/TEAM_DESIGN.md Make src/features/touring/ UI conform to the design system

# Design token definition
.claude/teams/TEAM_DESIGN.md Define design tokens for the project

# Audit + auto-fix
.claude/teams/TEAM_DESIGN.md Audit design consistency and fix mechanically fixable issues

# No arguments
.claude/teams/TEAM_DESIGN.md
```

## Team Composition

| Role | Agent Type | Model | Skills Used | Permissions |
| --- | --- | --- | --- | --- |
| **PL (Leader)** | general-purpose | Opus | — | delegate |
| **DS Engineer** | general-purpose | Sonnet | `design-system-audit` | plan required (PL approves) |
| **UI/UX Designer** | general-purpose | Sonnet | `ui-ux-design` | plan required (PL approves) |
| **Reviewer** | general-purpose, mode: plan | Sonnet | `code-review` | plan required (PL approves), no source code changes |

### Skill Coverage (3 Skills)

| Skill | Owner |
| --- | --- |
| `design-system-audit` | DS Engineer |
| `ui-ux-design` | UI/UX Designer |
| `code-review` | Reviewer |

## Role Responsibilities

### PL (Leader)

- Determine the scope of design work (full audit / specific feature / token definition)
- Create task lists with TaskCreate and set dependencies
- Verify consistency between DS Engineer and UI/UX Designer deliverables
- Make decisions on items requiring design judgment
- **Do not perform design work directly**

### DS Engineer

- Define and verify design tokens (spacing, typography, component sizes)
- Audit cross-feature design consistency
- Skill used: `/design-system-audit`
- Output audit reports to `output/reports/review/`
- Execute mechanical fixes for token violations using `--fix` mode
- Run build/lint/tests after fixes to confirm no breaking changes

### UI/UX Designer

- Implement individual UI fixes and improvements based on DS Engineer's audit results
- Handle fixes requiring design judgment such as pattern mismatches and gaps
- Skill used: `/ui-ux-design`
- Ensure dark mode, accessibility, and responsive support
- Ensure new components conform to the design system

### Reviewer

- Conduct code review on changes by DS Engineer and UI/UX Designer
- Skill used: `/code-review`
- Verify both design system conformance and code quality
- **Do not modify source code**

## Workflow

```text
PL: Determine scope → Create task list and assign
  |
  v
DS Engineer: Run /design-system-audit → Submit audit report
  |
  v
PL: Review audit report → Decide fix approach (mechanical fix vs design judgment needed)
  |
  v (can be parallel)
  +-- DS Engineer: Mechanical token violation fixes with --fix
  +-- UI/UX Designer: Fix pattern mismatches/gaps with /ui-ux-design
  |
  v
Reviewer: Review changes with /code-review → Feedback
  |  (if issues found: fix → re-review)
  v
PL: Final confirmation → Completion determination
```

### Dependency Rules

| Prerequisite | Next Step |
| --- | --- |
| PL scope determination | DS Engineer starts audit |
| Audit report complete | PL decides fix approach |
| Fix approach decided | DS Engineer & UI/UX Designer fix in parallel |
| Fixes complete | Reviewer conducts code review |
| Review approved | PL final confirmation |

## Deliverables

| Deliverable | Owner | Output Location |
| --- | --- | --- |
| Design consistency audit report | DS Engineer | `output/reports/review/DESIGN_AUDIT_{YYYYMMDD}.md` |
| Design token definitions | DS Engineer | Design system section of `docs/development-patterns.md` |
| UI fixes | UI/UX Designer | Components under `src/` |
| Code review results | Reviewer | `output/reports/review/` |

## Completion Criteria

- [ ] DS Engineer: Design consistency audit complete, 0 HIGH inconsistencies (fixed or approach decided)
- [ ] UI/UX Designer: Assigned fixes complete, dark mode & a11y verified
- [ ] Reviewer: Code review complete, 0 MUST-fix issues
- [ ] PL: Build/lint/test all pass confirmed
- [ ] PL: Recommended actions (items requiring human judgment) listed and presented

## Handoff to Subsequent Teams

After design system work is complete, coordinate with the following teams:

| Subsequent Team | Template | Coordination Content |
| --- | --- | --- |
| Feature Development Team | `TEAM_FEATURE.md` | Reflect design tokens and UI conventions in implementation |
| Quality Assurance Team | `TEAM_QA.md` | Continuous verification of design consistency |

## Tech Stack Reference

All team members must read `.claude/CLAUDE.md` and follow the project's tech stack and conventions.
