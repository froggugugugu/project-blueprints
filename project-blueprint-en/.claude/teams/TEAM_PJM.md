# Team Definition — PJM (Full Lifecycle Management)

## Overview

A team that executes all project phases consistently, from requirement notes to implementation, testing, and quality audits.
Humans simply place memos in `input/` and review deliverables in `output/`, and development proceeds.

## Usage

```text
.claude/teams/TEAM_PJM.md <requirement-note-file-path or instruction> [--auto]
```

Arguments are optional. When omitted, the PL checks `input/requirements/` and identifies the target file.

### Approval Mode

| Mode | Specification | Gate Behavior |
| --- | --- | --- |
| **Normal (Default)** | No flag | Present deliverables to human at each gate and wait for approval |
| **Autonomous** | Add `--auto` | PJM auto-judges based on quality criteria. Only final report presented to human |

In autonomous mode, PJM auto-passes gates based on these criteria:
- Deliverables meet the output contract (required sections in skill definitions)
- No unresolved [Needs Confirmation] items remain
- All tests pass, coverage target met, 0 static analysis errors
- 0 CRITICAL/HIGH vulnerabilities

When criteria are not met, human judgment is sought even in autonomous mode.

### Examples

```text
# File specification (recommended)
.claude/teams/TEAM_PJM.md input/requirements/REQ_001.md

# Autonomous mode (delegate gate approval to PJM)
.claude/teams/TEAM_PJM.md input/requirements/REQ_001.md --auto

# Instruction specification
.claude/teams/TEAM_PJM.md Execute all phases for user authentication feature

# Start from mid-phase
.claude/teams/TEAM_PJM.md Start from Phase 3. PRD and design docs already in output/

# Quality audit only + autonomous mode
.claude/teams/TEAM_PJM.md Implementation done. Run Phase 5 only --auto

# No arguments
.claude/teams/TEAM_PJM.md
```

## Input/Output

```text
input/requirements/REQ_xxx.md   ← Human-created (requirement notes)
         │
         ▼ AI Processing (this team executes all phases)
         │
output/
├── prd/PRD_xxx.md              ← Phase 1 deliverable (human reviews)
├── design/ARCH_xxx.md          ← Phase 2 deliverable (human reviews)
├── tasks/TASK_xxx.md           ← Phase 3 deliverable (human reviews)
└── reports/                    ← Phase 5 deliverables (human reviews)
    ├── review/                    Code review results
    ├── test/                      Test reports
    ├── security/                  Security scan results
    └── legal/                     Legal check results
```

## Team Composition

| Role | Agent Type | Model | Skills | Permissions |
| --- | --- | --- | --- | --- |
| **PJM (Leader)** | general-purpose | Opus | — | delegate + plan approval |
| **Analyst** | general-purpose, mode: plan | Sonnet | `prd`, `architecture` | plan required (PJM approves), source code read-only |
| **Planner** | general-purpose, mode: plan | Sonnet | `plan` | plan required (PJM approves), source code read-only |
| **Developer** | general-purpose | Sonnet | `implementing-features`, `ui-ux-design`, `refactoring` | plan required (PJM approves) |
| **Reviewer** | general-purpose, mode: plan | Sonnet | `code-review`, `security-scan`, `legal-check` | plan required (PJM approves), source code read-only |
| **Tester** | general-purpose | Sonnet | `e2e-testing`, `performance` | test files only |

### Skill Coverage (All 11 Skills)

| Skill | Owner |
| --- | --- |
| `prd` | Analyst |
| `architecture` | Analyst |
| `plan` | Planner |
| `implementing-features` | Developer |
| `ui-ux-design` | Developer |
| `refactoring` | Developer |
| `code-review` | Reviewer |
| `security-scan` | Reviewer |
| `legal-check` | Reviewer |
| `e2e-testing` | Tester |
| `performance` | Tester |

## Role Responsibilities

### PJM (Leader)

- Read requirement notes from `input/requirements/` and understand the overall project scope
- Manage the start, completion, and approval of each phase
- Present deliverables to human at each gate point and wait for approval
- Verify consistency between members
- Create phase task lists with TaskCreate
- **Do not create documents or write code yourself**

### Analyst

- Generate PRD from requirement notes → output to `output/prd/`
- After PRD approval, generate architecture design doc → output to `output/design/`
- Skills used: `/prd <file-path>`, `/architecture <file-path>`
- Report ambiguous requirements as "[Needs Confirmation]" to PJM
- **Do not modify source code**

### Planner

- Break down implementation tasks based on architecture design → output to `output/tasks/`
- Skills used: `/plan`
- Analyze inter-task dependencies and parallelization potential
- Define test strategy
- **Do not modify source code**

### Developer

- Implement features based on task breakdown
- Skills used: `/implementing-features` (feature implementation), `/ui-ux-design` (UI implementation), `/refactoring` (structure improvement)
- Follow TDD and create unit tests
- Report completion to PJM

### Reviewer

- Conduct code review, security scan, and legal check after implementation
- Skills used: `/code-review`, `/security-scan`, `/legal-check`
- Output reports to respective subdirectories under `output/reports/`
- Send specific feedback to the developer
- **Do not modify source code**

### Tester

- Conduct E2E testing and performance measurement after reviewer approval
- Skills used: `/e2e-testing`, `/performance`
- Output test reports to `output/reports/test/`
- **Only create/modify test files**

## Phase Workflow

```text
Phase 1: Requirements Analysis
  PJM: Check requirement notes in input/ → Assign to Analyst
  Analyst: Generate PRD with /prd → Output to output/prd/
  🚏 Gate 1: Normal=Present to human→Wait for approval / Autonomous=PJM judges by quality criteria

Phase 2: Architecture Design
  Analyst: Generate design doc with /architecture → Output to output/design/
  🚏 Gate 2: Normal=Present to human→Wait for approval / Autonomous=PJM judges by quality criteria

Phase 3: Task Breakdown
  Planner: Break down tasks with /plan → Output to output/tasks/
  🚏 Gate 3: Normal=Present to human→Wait for approval / Autonomous=PJM judges by quality criteria

Phase 4: Implementation
  Developer: Create plan → PJM approval → Implement with /implementing-features + /ui-ux-design
  🚏 Gate 4: Normal=Present to human / Autonomous=Auto-pass on all tests pass + coverage met

Phase 5: Verification (Parallel Execution)
  Reviewer: /code-review → output/reports/review/
  Reviewer: /security-scan → output/reports/security/
  Reviewer: /legal-check → output/reports/legal/
  Tester: /e2e-testing → output/reports/test/
  Tester: /performance → Performance measurement results
  🚏 Gate 5: Normal=Present to human→Wait for approval / Autonomous=Auto-pass on 0 CRITICALs

Phase 6: Completion Decision
  PJM: Verify all gates passed → Final report (presented to human even in autonomous mode)
```

### Dependency Rules

| Prerequisite | Next Step |
| --- | --- |
| Requirement notes exist in `input/` | Phase 1 starts |
| PRD approved (Gate 1 passed) | Phase 2 starts |
| Design doc approved (Gate 2 passed) | Phase 3 starts |
| Task breakdown approved (Gate 3 passed) | Phase 4 starts |
| Implementation complete (Gate 4 passed) | Phase 5 starts |
| All reports approved (Gate 5 passed) | Phase 6 (Completion decision) |

### Phase Skipping

PJM can skip unnecessary phases at their discretion:

| Situation | Skippable Phases |
| --- | --- |
| PRD and design docs already exist | Phase 1, 2 → Start from Phase 3 |
| Task breakdown already exists | Phase 1, 2, 3 → Start from Phase 4 |
| QA only for implemented code | Phase 1–4 → Run Phase 5 only |
| Security/legal only | Run only applicable skills in Phase 5 |

## Completion Criteria

- [ ] Analyst: PRD generation complete, approved (Normal=human / Autonomous=PJM)
- [ ] Analyst: Architecture design complete, approved (Normal=human / Autonomous=PJM)
- [ ] Planner: Task breakdown complete, approved (Normal=human / Autonomous=PJM)
- [ ] Developer: All tasks implemented, unit tests all pass
- [ ] Reviewer: Code review complete, 0 MUST findings
- [ ] Reviewer: Security scan complete, 0 CRITICAL/HIGH vulnerabilities
- [ ] Reviewer: Legal check complete, 0 CRITICAL risks
- [ ] Tester: All E2E tests pass
- [ ] Tester: Performance measurement complete
- [ ] PJM: All phases confirmed complete, all deliverables in output/
- [ ] PJM: Final report presented to human (required even in autonomous mode)

## Tech Stack Reference

All team members must read `.claude/CLAUDE.md` and follow the project's tech stack and conventions.
