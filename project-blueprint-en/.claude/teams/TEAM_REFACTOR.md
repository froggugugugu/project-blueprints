# Team Definition — Refactoring

## Overview

A team for safely executing large-scale code restructuring. Performs incremental refactoring and performance optimization, guaranteeing no regressions through reviews and tests.

## Usage

```text
.claude/teams/TEAM_REFACTOR.md <target-directory or refactoring instruction>
```

Arguments are optional. When omitted, the PL interactively confirms the target scope.

### Examples

```text
# Target directory specification (recommended)
.claude/teams/TEAM_REFACTOR.md src/features/assignment/

# Instruction specification
.claude/teams/TEAM_REFACTOR.md Separate store responsibilities and resolve inter-store dependencies

# Multiple targets
.claude/teams/TEAM_REFACTOR.md Extract utilities from src/features/projects/ and src/features/assignment/ to shared/utils/

# No arguments
.claude/teams/TEAM_REFACTOR.md
```

## Team Composition

| Role | Agent Type | Model | Skills | Permissions |
| --- | --- | --- | --- | --- |
| **PL (Leader)** | general-purpose | Opus | `plan` | delegate + plan approval |
| **Refactorer** | general-purpose | Sonnet | `refactoring`, `implementing-features` | plan required (PL approves) |
| **Reviewer** | general-purpose, mode: plan | Sonnet | `code-review` | plan required (PL approves), source code read-only |
| **Tester** | general-purpose | Sonnet | `e2e-testing` | test files only |

## Role Responsibilities

### PL (Leader)

- Investigate and analyze the impact scope of refactoring targets with `/plan`
- Decompose into incremental refactoring steps as task list with TaskCreate
- Verify tests are green at each step
- Approve/reject refactorer plans
- Make rollback decisions when necessary
- **Do not write code yourself**

### Refactorer

- Execute assigned refactoring steps incrementally
- Skills used: `/refactoring` (structural changes), `/implementing-features` (when fixes/supplements are needed)
- Verify behavior is unchanged at each step
- Commit in rollback-capable units
- Report completion to PL

### Reviewer

- Conduct code review at each refactoring step
- Skills used: `/code-review` (quality check)
- Focus on verifying no behavior changes (regression risk)
- When performance measurement is needed, request via PL to refactorer
- **Do not modify source code**

### Tester

- Run E2E tests after each refactoring step completes
- Skills used: `/e2e-testing`
- Focus on regression testing
- Verify all existing tests pass
- Add new test cases as needed
- Report test results to PL
- **Only create/modify test files**

## Workflow

```text
PL: Impact analysis with /plan → Decompose into incremental steps → Assign
  |
  v (Repeat for each step)
Refactorer: Create plan → PL approval → Execute step with /refactoring → Report completion
  |
  v
Reviewer: Code review with /code-review → Feedback
  |  (When findings exist, refactorer fixes → Re-review)
  v
Tester: Regression testing with /e2e-testing → Report results
  |
  v
PL: Step completion decision → Next step or done
```

### Dependency Rules

| Prerequisite | Next Step |
| --- | --- |
| PL impact analysis complete | Refactorer starts first step |
| Refactorer step complete | Reviewer starts review |
| Reviewer approval | Tester runs regression tests |
| All tests pass | PL assigns next step |

### Incremental Execution Principles

- 1 step = 1 clear structural change (responsibility migration, split, merge, etc.)
- Tests must be green at each step completion
- Rollback must be possible between steps
- Shared layer changes are executed sequentially (no parallel execution)

## Completion Criteria

- [ ] Refactorer: All steps complete, committed
- [ ] Reviewer: All steps reviewed, findings resolved
- [ ] PL: Confirmed no negative performance impact (request measurement from refactorer if needed)
- [ ] Tester: All E2E tests pass, no regressions
- [ ] PL: Consistency check of all steps complete, no dependency direction rule violations

## Tech Stack Reference

All team members must read `.claude/CLAUDE.md` and follow the project's tech stack and conventions.
