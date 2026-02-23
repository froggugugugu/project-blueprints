# Team Definition — PJM (Full Lifecycle Management)

## Overview

A team that executes all project phases consistently, from requirement notes to implementation, testing, and quality audits.
Humans simply place memos in `input/` and review deliverables in `output/`, and development proceeds.

## Usage

```text
.claude/teams/TEAM_PJM.md <requirement-note-file-path or instruction> [--auto] [--parallel]
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

### Implementation Mode

| Mode | Specification | Phase 4 Behavior |
| --- | --- | --- |
| **Sequential (Default)** | No flag | A single developer implements tasks sequentially |
| **Parallel** | Add `--parallel` | Delegates independent task groups to TEAM_FEATURE in parallel |

Parallel mode prerequisites:
- Phase 3 deliverables must specify changed files and dependencies
- At least 2 independent Feature Bundles must be identifiable (falls back to sequential mode if only 1)

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

# Parallel implementation mode
.claude/teams/TEAM_PJM.md input/requirements/REQ_001.md --parallel

# Autonomous + parallel
.claude/teams/TEAM_PJM.md input/requirements/REQ_001.md --auto --parallel

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
- **Additional responsibilities in parallel mode**:
  - Identify Feature Bundles from task breakdown deliverables (analyze changed-file overlaps)
  - Separate shared layer change tasks and manage their sequential execution
  - Generate TASK files for each Bundle in `output/tasks/`
  - Launch TEAM_FEATURE in parallel for each Bundle, track progress, and aggregate results
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
  ┌─ Sequential mode (default) ────────────────────
  │ Developer: Create plan → PJM approval → Implement with /implementing-features + /ui-ux-design
  └────────────────────────────────────────────────

  ┌─ Parallel mode (--parallel) ───────────────────
  │ Phase 4a: Parallelization Prep (PJM)
  │   Analyze changed-file overlaps in task breakdown deliverables
  │   Identify independent Feature Bundles
  │   Separate shared layer change tasks
  │
  │ Phase 4b: Shared Layer Changes (sequential, when applicable)
  │   Developer implements shared layer changes sequentially
  │
  │ Phase 4c: Feature Bundle Parallel Implementation
  │   PJM: Generate TASK files for each Bundle in output/tasks/
  │   PJM: Launch TEAM_FEATURE in parallel for each Bundle
  │   PJM: Track progress with TaskCreate/TaskUpdate
  │
  │ Phase 4d: Integration Verification
  │   After all TEAM_FEATURE instances complete, run integration tests
  │   Re-run failed Bundles or report to human
  └────────────────────────────────────────────────
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
- [ ] **Parallel mode only**: PJM: All Bundle TEAM_FEATURE instances completed
- [ ] **Parallel mode only**: PJM: Integration verification checklist all passed (no file conflicts, all tests pass, all type checks pass, zero static analysis errors)

## Parallel Mode Details

### Feature Bundle Identification Rules

PJM analyzes Phase 3 deliverables (`output/tasks/`) and identifies Feature Bundles based on these criteria:

1. **No changed-file overlap**: Changed files must not overlap between Bundles
2. **Shared layer exclusion**: Changes to shared layer files are excluded from Bundles and processed sequentially in Phase 4b
3. **Respect dependencies**: When inter-task dependencies exist, group them in the same Bundle or make the dependency source a preceding Bundle

### Shared Layer Definition

The following paths are treated as the shared layer and excluded from parallel Bundles:

- `src/shared/`, `src/stores/`, `src/types/`, `src/lib/`, `src/utils/`
- Shared paths defined in `project-config.md` §4 (Architecture)

### Bundle TASK File Generation Convention

- File name: `TASK_BUNDLE_<name>.md` (e.g., `TASK_BUNDLE_auth.md`)
- Format: `TASK_TEMPLATE.md` compliant + Bundle metadata (Bundle ID, source task breakdown, included task IDs, prerequisites)
- Output destination: `output/tasks/`

### TEAM_FEATURE Invocation Format

```text
.claude/teams/TEAM_FEATURE.md output/tasks/TASK_BUNDLE_<name>.md
```

Each TEAM_FEATURE instance works only within the scope of its assigned Bundle.
PJM tracks each Bundle's progress with TaskCreate/TaskUpdate.

### Failure Recovery

- Preserve successful Bundle results
- Analyze the cause of failed Bundles and attempt re-execution
- Escalate to human if re-execution does not resolve the issue

### Integration Verification Checklist

After all TEAM_FEATURE instances complete, PJM verifies the following:

- [ ] No file conflicts between Bundles
- [ ] All tests pass
- [ ] All type checks pass
- [ ] Zero static analysis errors

## Tech Stack Reference

All team members must read `.claude/CLAUDE.md` and follow the project's tech stack and conventions.
