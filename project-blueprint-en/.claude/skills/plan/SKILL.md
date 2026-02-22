---
name: plan
description: >
  Generates design documents and task breakdowns for feature implementation.
  Triggers: plan, design, decompose, analyze impact, task breakdown.
  Source-code read-only — never modifies source code or test files.
  Outputs structured plan to output/tasks/ (requires Write permission to output/tasks/).
  Updates project-config.md §11 when new patterns or pitfalls are identified.
  Takes optional argument: /plan <description or file-path>
context: fork
---

# Plan

A skill for pre-implementation design of features. Produces structured documentation
covering impact analysis, task breakdown, parallelization analysis, and test strategy.
**Never modifies source code.**

## Prerequisites

| Reference File | Purpose | Fallback When Stub |
| -------------- | ------- | ------------------ |
| `docs/project.md` | Routing, store list | Refer directly to `project-config.md` §1–§3 |
| `docs/architecture.md` | Directory structure | Refer directly to `project-config.md` §4 |

Plan generation is possible even when `docs/` contains only stubs.

## Core Principles

- Read-only (code modification prohibited)
- When requirements are ambiguous, present options and confirm
- Output is intended for human review and approval. Do not proceed to implementation without approval
- Avoid excessive design; summarize at a granularity sufficient for implementation

## Usage

```text
/plan <feature description or file-path>
```

Arguments are optional. When omitted, confirm interactively with the user.
When a file path is specified, read its contents to understand the design target.

### Examples

```text
/plan Design user authentication feature
/plan input/requirements/REQ_001.md
/plan output/prd/PRD_auth.md
```

### Output Destination

- Default: Present design document in conversation
- File output: `output/tasks/PLAN_<feature-name>.md` (when `output/` directory exists)

### Integration with Other Skills

| Previous Step | This Skill | Next Step |
| ------------- | ---------- | --------- |
| `/prd` `/architecture` | `/plan` | `/implementing-features` `/e2e-testing` |

## Workflow

1. **Requirements Clarification** — Structure user requirements and formalize acceptance criteria
2. **Impact Analysis** — Identify related files, stores, schemas, and tests
3. **Task Breakdown** — Split into implementation units and state dependencies
4. **Parallelization Analysis** — Classify tasks into parallelizable and sequential groups
5. **Test Strategy** — Define targets and approach for unit tests and E2E tests
6. **Documentation Impact** — State impact on `project-config.md` and `docs/`
7. **Submit for Review** — Output the design document and await human approval

## Output Contract

### Section Definitions

| Section | Required | Constraints |
| ------- | -------- | ----------- |
| Requirements Summary | ✅ | Acceptance criteria in bullet points. One per line |
| Impact Analysis | ✅ | Table format. Category ∈ {Schema, Store, Component, Page, Utility, Test, Documentation, Config} |
| Task Breakdown | ✅ | Phase-based. Each task states changed files and dependent tasks |
| Dependency Graph | ✅ | ASCII format. Show task dependencies with arrows |
| Test Strategy | ✅ | Unit test/E2E test targets and approach |
| Documentation Update Plan | ✅ | Impact on project-config.md and docs/ |
| Risks & Concerns | Conditional | Only when technical risks exist |

### Task Description Format

Each task is described in the following format:

```
- [ ] TaskID — Description (Changed files: path1, path2 | Depends on: TaskID)
```

- Task IDs are sequential: `T1`, `T2`, ...
- Changed files are relative paths from `src/`
- When no dependencies: `Depends on: none`
- Phase classification criteria:
  - **Parallelizable**: Tasks whose changed files do not overlap
  - **Sequential**: Tasks that depend on outputs of the previous phase

### Vocabulary Constraints

| Term | Definition |
| ---- | ---------- |
| Phase | A unit of parallel execution. Tasks within a phase can be started simultaneously |
| Dependency | A relationship where a task requires another task's output |
| Changed Files | Files that will be added, modified, or deleted in that task |
| [Needs Confirmation] | A design decision point requiring user judgment |

### Structural Constraints

- Phases are described in numerical order (Phase 1, 2, 3...)
- Each phase header states the execution condition: `(Parallelizable)` or `(After Phase N)`
- Impact analysis table change descriptions start with a verb: `Add`, `Modify`, `Delete`, `Move`

## Output Format

```markdown
# Design Document: [Feature Name]

## Requirements Summary
- [Acceptance criteria in bullet points]

## Impact Analysis
| Category | File | Change Description |
| --- | --- | --- |
| Schema | src/shared/types/xxx.ts | Add fields |
| Store | src/stores/xxx-store.ts | Add actions |

## Task Breakdown

### Phase 1 (Parallelizable)
- [ ] T1 — [Description] (Changed files: ... | Depends on: none)
- [ ] T2 — [Description] (Changed files: ... | Depends on: none)

### Phase 2 (After Phase 1)
- [ ] T3 — [Description] (Changed files: ... | Depends on: T1)

### Phase 3 (Sequential)
- [ ] T4 — [Description] (Changed files: ... | Depends on: T2, T3)

## Dependency Graph
T1 ──┐
     ├──→ T3 ──→ T4
T2 ──┘

## Test Strategy
### Unit Tests
- [Targets and approach]

### E2E Tests
- [Target scenarios]

## Documentation Update Plan
### project-config.md
- [State impact if any (e.g., new technology → §2, new pitfall → §11)]

### docs/
- [State impact if any (e.g., new store → docs/project.md, new schema → docs/data-model.md)]

## Risks & Concerns
- [Notable items if any]
```

## project-config.md Maintenance

When the following are discovered during design investigation, update `project-config.md`:

| Discovery | Target Section |
| --------- | -------------- |
| A new library needs to be introduced | §2 (Technology Stack) |
| New pitfalls/notes discovered | §11 (Known Pitfalls) |
| Architecture pattern change needed | §4 (Architecture) |

## Investigation Tools

- `Glob` / `Grep` — File and code search
- `Read` — File content review
- Dependency direction check command (when documented in `project-config.md`)

## Output Files

- When `output/` directory exists: `output/tasks/PLAN_<feature-name>.md`
- When `output/` directory doesn't exist: Present design document in conversation

## Prohibited Actions

- Modifying source code (including test files)
- Starting implementation tasks without design approval
- Including project-specific data (IDs, passwords, etc.) in documentation
