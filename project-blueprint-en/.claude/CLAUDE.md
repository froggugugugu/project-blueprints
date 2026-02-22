# Development Guide

Cross-project development rules, quality standards, and workflows.
Referenced by all roles (PM / PdM / Developer / Reviewer / Tester).

> **Project-specific parameters**: Consolidated in `project-config.md`.
> For details on tech stack, routing, data models, etc., refer to files under `docs/`.

## General

- Always respond in English
- Use subagents for research and debugging to conserve context
- Record important decisions periodically in markdown files
- CLAUDE.md contains only cross-cutting rules; detailed procedures are delegated to skills
- Available skills (all skill arguments are optional; when omitted, confirmation is done interactively):
  - `/plan <description or file-path>` — Design document generation (read-only, no implementation)
  - `/implementing-features <task-file or instruction>` — Feature implementation and bug fixes via TDD
  - `/ui-ux-design <target-file or instruction>` — UI/UX design, review, and implementation following design systems
  - `/e2e-testing <target-feature or instruction>` — Playwright E2E test creation
  - `/code-review <target-file or instruction>` — Code review (read-only)
  - `/performance <target or instruction>` — Measurement-first performance optimization
  - `/refactoring <target-directory or instruction>` — Safe incremental refactoring
  - `/legal-check <target-scope or instruction>` — IT legal compliance check (read-only)
  - `/security-scan <target-scope or instruction>` — Security scan and vulnerability report (read-only)
  - `/prd <file-path>` — PRD generation from requirement notes (read-only)
  - `/architecture <file-path>` — Architecture design from requirement notes (read-only)
- Skill selection criteria:
  - New feature implementation → `/implementing-features <task-file>`
  - UI adjustments, dark mode, a11y → `/ui-ux-design <target-file>`
  - Pre-design for large changes → `/plan <description>`
  - Quality check before PR → `/code-review <target-file>`
  - Automated user flow testing → `/e2e-testing <target-feature>`
  - Performance improvements, bundle optimization → `/performance <target>`
  - Large-scale code restructuring, responsibility migration → `/refactoring <target-directory>`
  - OSS license, privacy, intellectual property legal checks → `/legal-check <target-scope>`
  - Vulnerability scanning, OWASP ZAP, dependency auditing → `/security-scan <target-scope>`
  - PRD creation from requirement/feature notes → `/prd <file-path>`
  - System architecture design from requirement notes → `/architecture <file-path>`

## Document Management Policy

### Human-Managed Files

- `project-config.md` — Parameters that humans should decide: tech stack, quality standards, policies, etc.

### AI-Managed Files

The following files are generated and maintained by AI. They are automatically updated as implementation changes:

- `docs/project.md` — Routing, store list, commands, tech stack
- `docs/architecture.md` — Directory structure, test list
- `docs/data-model.md` — Schema definitions, validation rules
- `docs/development-patterns.md` — Code conventions, pitfalls, design system

### AI Maintenance of project-config.md

Each skill updates the following sections of `project-config.md` as design and implementation progress:

| Update Trigger | Target Section |
| -------------- | -------------- |
| New pitfalls or anti-patterns discovered | §11 (Known Pitfalls) |
| Dependency package additions or version changes | §2 (Tech Stack) |
| Command additions or changes | §3 (Commands) |

Always maintain consistency between `project-config.md` and `docs/`.

### Conflict Prevention for project-config.md Updates

| Section | Primary Update Responsibility | Rule |
| ------- | ----------------------------- | ---- |
| §2 (Tech Stack) | `/implementing-features` | Other skills report findings; the primary updater consolidates |
| §3 (Commands) | `/implementing-features` | Same as above |
| §4 (Architecture) | `/implementing-features` | `/architecture` outputs to `output/design/`. Reflected after adoption |
| §11 (Known Pitfalls) | All skills (append allowed) | Check for duplicate entries before appending |

### Conflict Prevention for docs/ Updates

| File | Primary Update Responsibility | Rule |
| ---- | ----------------------------- | ---- |
| `docs/project.md` | `/implementing-features` | Update when routing, stores, or commands change |
| `docs/architecture.md` | `/implementing-features` | Update when directory structure or test placement changes. `/architecture` outputs to `output/design/`, reflected after adoption |
| `docs/data-model.md` | `/implementing-features` | Update when schemas are added or changed |
| `docs/development-patterns.md` | `/implementing-features` | Update when code conventions, pitfalls, or design system change. Other skills (`/performance`, `/refactoring`, etc.) report findings to PL or in conversation; the primary updater consolidates |

In a team context, the PL centrally manages updates to `project-config.md` and `docs/`. Members report findings to the PL via messages, and the PL performs updates. Only appending to §11 can be done directly by members (duplicate check required).

## Development Principles

- When specifications are ambiguous, do not proceed by guessing — present 1-2 specific options and confirm
- Follow specification options if available; otherwise choose the simplest option and explicitly mark it as an assumption
- Delete or overwrite user data only when explicitly required by specifications
- Separate stored values and display values in data model and UI when they differ
- Be deterministic. Clearly define rounding modes, formats, and aggregation scopes
- Avoid over-engineering. Implement with the minimum complexity needed for current requirements
- Do not duplicate in documentation what can be read from code

## Architecture Governance

Restrict dependency directions between layers. Rule details are defined in `project-config.md` section 4.4.

- Verify dependency direction violations with the detection command (documented in `project-config.md`)
- Circular dependencies are prohibited

## Quality Standards

- Implement incrementally with test-first (TDD) approach (when enabled in `project-config.md` section 6)
- Provide unit tests for important business logic
- Cover major user flows with E2E tests
- Test coverage targets are defined in `project-config.md` section 6

## Quality Reports and Gates

- Present quality evidence in human-readable format at the completion of each phase.
- Quality gates are provided as points where humans can intervene, but intervention is optional.
- Reports are separated into two directories by purpose (refer to `project-config.md` section 6.1)
- There are two types of gates:
  - **Skill gates (3)**: Design/implementation/final checkpoints during each skill execution
  - **Phase gates (5)**: Inter-phase approval points for the PJM team (refer to `.claude/teams/TEAM_PJM.md`)

### Report Output Destinations

Reports are separated into **tool direct output** (machine-oriented) and **human-readable summaries** (for review):

| Type | Destination | Content | Examples |
| ---- | ----------- | ------- | -------- |
| Tool direct output | `testreport/` | Raw data generated by tools (HTML/JSON/LCOV, etc.) | Coverage HTML, ZAP report, gitleaks JSON |
| Human-readable summary | `output/reports/` | Markdown reports for human review | Code review results, legal check results |

#### Tool Direct Output (`testreport/`)

| Category | Destination | Generating Skill |
| -------- | ----------- | ---------------- |
| Unit test coverage | `testreport/coverage/` | `/implementing-features` |
| E2E test report | `testreport/e2e/` | `/e2e-testing` |
| Security scan | `testreport/security/` | `/security-scan` |

#### Human-Readable Summaries (`output/reports/`)

| Category | Destination | Generating Skill |
| -------- | ----------- | ---------------- |
| Code review | `output/reports/review/` | `/code-review` |
| Test result summary | `output/reports/test/` | `/e2e-testing` |
| Security summary | `output/reports/security/` | `/security-scan` |
| Legal check | `output/reports/legal/` | `/legal-check` |

### Report Content

At the completion of each phase, report the following as a summary:

- Test results (pass/fail counts, causes of failed tests)
- Coverage (line/branch changes, delta from threshold)
- Static analysis (lint/type check warning and error counts)
- Change impact scope (number of changed files, number of affected tests)

### Gate Points

Present results at the following timing so humans can review and decide:

1. **Design completion**: Present requirements interpretation and test design approach. Proceed to implementation after approval
2. **Implementation completion**: Present test results, coverage, and static analysis summary
3. **Final check**: Present fulfillment status of all checklist items as a list

Gate passage criteria:

- All tests pass
- Coverage does not fall below the target
- Zero static analysis errors
- Auto-pass if the above are met. Seek human judgment if not met

## Concurrent Development Principles

- Avoid conflicts at the file level. Do not simultaneously edit the same file
- Changes to the shared layer are performed sequentially
- For large feature additions, pre-decompose tasks with the `/plan` skill and identify parallelizable units
- Make dependencies between parallel tasks explicit and minimize blocking
- When using Agent Teams, follow team templates under `.claude/teams/` (all team arguments are optional; when omitted, the PL confirms interactively)
  - Full lifecycle → `TEAM_PJM.md <requirement-note-file or instruction>` (all 11 skills, recommended)
  - Feature development → `TEAM_FEATURE.md <task-file or implementation-instruction>`
  - Quality assurance → `TEAM_QA.md <target-scope or QA-instruction>`
  - Design phase → `TEAM_PLANNING.md <requirement-note-file or design-instruction>`
  - Refactoring → `TEAM_REFACTOR.md <target-directory or refactoring-instruction>`
- The PJM team reads notes from `input/` and generates deliverables in `output/`
- The PL decomposes tasks, sets dependencies, and assigns them; members implement only assigned tasks
- Shared layer changes are assigned sequentially by the PL to avoid concurrent editing

## Implementation Workflow

1. Requirements confirmation: Present options and resolve ambiguities
2. Impact analysis: Check existing code, tests, and dependencies
3. Test design: Derive test cases from acceptance criteria
4. **🚏 Design Gate**: Present requirements interpretation and test approach, wait for confirmation
5. Implementation: Write the minimum code to pass tests
6. Refactor: Eliminate duplication, improve readability (keep tests green)
7. **🚏 Implementation Gate**: Present test results, coverage, and static analysis summary
8. Self-review: Verify with the checklist below
9. **🚏 Final Gate**: Present checklist fulfillment status as a list

## Implementation Checklist

Verify before submitting design or code:

- [ ] Documented data model/schema changes
- [ ] Defined UI behavior (editable vs read-only)
- [ ] Clarified core algorithms (rounding, formatting, aggregation)
- [ ] Showed correspondence with acceptance criteria
- [ ] Confirmed existing tests are not broken
- [ ] Considered edge cases (empty arrays, boundary values, null)
- [ ] Updated documents under `docs/` to reflect implementation changes
- [ ] Confirmed no dependency direction rule violations
- [ ] Confirmed `--no-verify` was not used

## Communication Standards

- Always provide rationale for technical decisions
- Present impact scope before starting specification changes
- Respond to review feedback with both the fix and the reason
- Mark uncertain assumptions as "[Assumption]"

## Tool Usage Policy

- Documentation reference priority:
  1. `docs/` files within the project
  2. Directly reference official sites with `WebFetch`
  3. Context7 MCP (only when official sites are insufficient)
  4. `WebSearch` (only when the latest information is needed)
- Playwright MCP: Used for E2E test debugging and visual verification
- draw.io MCP: Used for architecture diagrams and flow charts

## Security Hardening

Security policy details are defined in `project-config.md` section 10.
The following apply to all projects:

- Always validate user input
- Regularly check dependency package vulnerabilities

## Git Operations Policy

- `--no-verify` is prohibited (do not bypass hooks)
- `--force` is prohibited in principle (state the reason and get confirmation when necessary)
- When hooks fail, fix the cause of the error (do not disable hooks)
- Git Hooks configuration is defined in `project-config.md` section 9

## Project-Specific Information

Recommended loading order: `project-config.md` (human decisions) → `docs/` (AI-generated detailed specs) → this file (cross-cutting rules)

@docs/project.md              <!-- Tech stack, commands, routing, store list -->
@docs/architecture.md          <!-- Directory structure, test list, document responsibilities -->
@docs/data-model.md            <!-- Schema definitions, field specs, validation -->
@docs/development-patterns.md  <!-- Code conventions, pitfalls, design system -->

## Workflow Control

### 1. Plan First
- Start non-trivial tasks (3+ steps or involving architectural decisions) in plan mode
- If unexpected problems arise, immediately revise the plan — do not push through
- Include verification steps in the plan (design confirmation procedures, not just implementation)
- Write detailed specifications upfront to reduce ambiguity

### 2. Subagent Strategy
- Actively use subagents to avoid overloading the main context
- Delegate research, exploration, and parallel analysis to subagents
- Concentrate computational resources on complex problems via subagents
- 1 subagent = 1 task, execute with focused scope

### 3. Self-Improvement Loop
- When receiving corrections from users, record lessons in the `.claude/tasks/LESSONS_TEMPLATE.md` format
- Write your own rules to avoid repeating the same mistakes
- Iteratively improve lessons until the error rate decreases
- Review relevant project lessons at the start of each session

### 4. Pre-Completion Verification
- Do not mark a task as complete without proving it works
- Compare diffs with the main branch as needed
- Ask yourself: "Would a senior engineer approve this?"
- Run tests, check logs, and demonstrate correctness

### 5. Pursuit of Elegance (Balanced)
- For non-trivial changes, pause and ask "Is there a more elegant way?"
- If a fix feels hacky, "implement an elegant solution with full knowledge"
- Do not apply this to simple, obvious fixes — avoid over-engineering
- Critically review your own deliverables before submission

### 6. Autonomous Bug Fixing
- When receiving a bug report, fix it independently without asking for step-by-step guidance
- Identify logs, errors, and failing tests, then resolve them
- Reduce user context switches to zero
- Fix CI failures autonomously without waiting for instructions

## Task Management

1. **Create a plan**: Create checkable items with Claude Code's `TaskCreate` / `TaskUpdate`
2. **Verify the plan**: Check in before starting implementation
3. **Track progress**: Mark completed items as you go
4. **Explain changes**: Present a high-level summary at each step
5. **Record results**: Add a review section upon completion
6. **Accumulate lessons**: When receiving corrections, record lessons in the `.claude/tasks/LESSONS_TEMPLATE.md` format

## Core Principles

- **Simplicity first**: Keep all changes as simple as possible. Minimize the scope of impact
- **No compromises**: Identify root causes. No temporary fixes. Judge by senior developer standards
- **Minimize impact**: Limit changes to only what is necessary. Do not introduce bugs
