# Team Definition — Feature Development

## Overview

The main team for implementing new features and fixing bugs. Follows the TDD workflow to complete the design → implementation → review → testing cycle.

## Usage

```text
.claude/teams/TEAM_FEATURE.md <task-file-path or implementation instruction>
```

Arguments are optional. When omitted, the PL checks `output/tasks/` and identifies the target task file.

### Examples

```text
# Task file specification (recommended)
.claude/teams/TEAM_FEATURE.md output/tasks/TASK_auth.md

# Instruction specification
.claude/teams/TEAM_FEATURE.md Add CSV export feature to dashboard

# Bug fix
.claude/teams/TEAM_FEATURE.md Fix bug where monthly allocation values are not saved on assignment screen

# No arguments
.claude/teams/TEAM_FEATURE.md
```

## Team Composition

| Role | Agent Type | Model | Skills | Permissions |
| --- | --- | --- | --- | --- |
| **PL (Leader)** | general-purpose | Opus | `plan` | delegate + plan approval |
| **Developer** | general-purpose | Sonnet | `implementing-features` | plan required (PL approves) |
| **UI/UX Designer** | general-purpose | Sonnet | `ui-ux-design` | plan required (PL approves) |
| **Reviewer** | general-purpose, mode: plan | Sonnet | `code-review` | plan required (PL approves), source code read-only |
| **Tester** | general-purpose | Sonnet | `e2e-testing` | test files only |

## Role Responsibilities

### PL (Leader)

- Read the task file and perform impact analysis and task breakdown with the `/plan` skill
- Decompose into task list with TaskCreate and set dependencies (blockedBy)
- Assign tasks to each member (set owner with TaskUpdate)
- Approve/reject plans from developers and testers
- Verify consistency with other features and architecture
- **Do not write code yourself**

### Developer

- Implement assigned tasks + create unit tests
- Skills used: `/implementing-features`
- Test framework: Use the test tool documented in `docs/project.md`
- Report completion to PL

### UI/UX Designer

- Handle design and implementation of UI-related tasks
- Skills used: `/ui-ux-design`
- Follow the design system section in `docs/development-patterns.md`
- Ensure design system consistency, accessibility, and dark mode support
- Provide UI/UX perspective review of developer's implementation (review mode)
- Directly implement UI (styling, layout, component structure) (implementation mode)

### Reviewer

- Conduct code review after developer implementation completes
- Skills used: `/code-review`
- Follow review perspectives, checklists, and report formats from the skill definition
- Send specific feedback to the developer
- **Do not modify source code**

### Tester

- Create and run tests after reviewer approval
- Skills used: `/e2e-testing`
- Test types: Integration tests + Playwright E2E tests
- Coverage: Normal cases, error cases, edge cases
- Report test results to PL
- **Only create/modify test files. Do not modify source code**

## Workflow

```text
PL: Read task file, break down with /plan → Create task list & assign
  |
  v
Developer + UI/UX Designer: Create plan → PL approval → Implement (parallelizable) → Report completion
  |
  v
UI/UX Designer: UI/UX perspective review → Feedback
  |
  v
Reviewer: Code review with /code-review → Feedback → Approval
  |  (When findings exist, developer/designer fixes → Re-review)
  v
Tester: Create plan → PL approval → Create & run E2E tests with /e2e-testing → Report results
  |
  v
PL: Overall verification → Completion decision
```

### Dependency Rules

| Prerequisite | Next Step |
| --- | --- |
| Developer implementation complete | UI/UX Designer starts UI review |
| UI/UX Designer approval | Reviewer starts code review |
| Reviewer approval | Tester starts testing |
| All tests pass | PL final verification |

### UI/UX Designer Participation Patterns

PL determines the designer's participation method based on the task nature:

| Task Nature | Designer's Role |
| --- | --- |
| UI implementation is primary (new screen creation, layout changes, etc.) | **Implementation mode**: Directly implement UI |
| Logic implementation includes UI changes | **Review mode**: UI review after developer implements |
| Backend logic only | **Not needed**: PL can skip at their discretion |

## Completion Criteria

- [ ] Developer: Implementation complete + all unit tests pass
- [ ] UI/UX Designer: Design system compliance confirmed (applicable tasks only)
- [ ] Reviewer: Review complete + all findings resolved
- [ ] Tester: All E2E tests pass
- [ ] PL: Consistency check complete, all tasks in task list are completed

## Tech Stack Reference

All team members must read `.claude/CLAUDE.md` and follow the project's tech stack and conventions.

## Task File Integration Rules

- When the task file has an "Ambiguity" section, PL makes the judgment and instructs members
- When the task file has an Implementation Order, follow that order
- When the task file has a Testing Strategy, testers follow it

## Sub-team Invocation from PJM Team

When launched from TEAM_PJM's parallel mode (`--parallel`), follow these constraints:

- Implement only within the scope of the assigned TASK file (`TASK_BUNDLE_<name>.md`)
- Only modify files listed in the target files/directories section (changes to out-of-scope files are prohibited)
- Do not coordinate directly with other TEAM_FEATURE instances (PJM manages integration)
- Report completion to PJM upon finishing (PJM manages progress via TaskUpdate)
