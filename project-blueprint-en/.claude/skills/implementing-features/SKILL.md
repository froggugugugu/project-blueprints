---
name: implementing-features
description: >
  Implements features, fixes bugs, and refactors code following TDD workflow.
  Triggers: implement, create, fix, modify, add, refactor, build, develop, change functionality.
  Covers: components, stores, schemas, utilities, styling, docs/ and project-config.md synchronization.
  Takes optional argument: /implementing-features <task-file or instruction>
---

# Implementing Features

Implements features, fixes bugs, and refactors code following project development standards with TDD.
Strictly follow `CLAUDE.md` policies. For project-specific code patterns, refer to [docs/development-patterns.md](../../../docs/development-patterns.md).

## Prerequisites

| Reference File | Purpose | Fallback When Stub |
| -------------- | ------- | ------------------ |
| `docs/project.md` | Commands, tech stack | Refer directly to `project-config.md` §1–§3 |
| `docs/architecture.md` | Directory structure, test placement | Refer directly to `project-config.md` §4 |
| `docs/data-model.md` | Schema definitions | Read Zod schemas directly from codebase |
| `docs/development-patterns.md` | Code conventions, pitfalls | Refer directly to `project-config.md` §2, §11 |

This skill also generates/updates `docs/` files. When they are stubs, auto-generate after execution.

## Core Principles

- Write production-ready code (no pseudo-code, no escaping with TODOs)
- When specifications are ambiguous, ask before implementing (do not proceed by guessing)
- Do not change the design without approval; avoid excessive abstraction
- Do not add features not in the specification
- Do not implicitly delete or overwrite user data

## Usage

```text
/implementing-features <task-file or implementation instruction>
```

Arguments are optional. When omitted, confirm interactively with the user.
When a task file is specified, read its contents to understand requirements and acceptance criteria.

### Examples

```text
/implementing-features Add user authentication feature
/implementing-features output/tasks/TASK_auth.md
/implementing-features .claude/tasks/TASK_001.md
```

### Output Destination

- Implementation code: Under `src/` (following the project's directory structure)
- Test code: `__tests__/` directory within each module
- Coverage report: `testreport/coverage/`

### Integration with Other Skills

| Previous Step | This Skill | Next Step |
| ------------- | ---------- | --------- |
| `/plan` `/architecture` | `/implementing-features` | `/code-review` `/e2e-testing` |

## Design Principles

Follow the principles below. For project-specific application, refer to `docs/development-patterns.md`.

- **SRP**: 1 component = 1 display responsibility, 1 store = 1 domain, 1 function = 1 computation. Split into hooks/actions when growing too large
- **OCP**: Extend through props/composition/new actions rather than modifying internal existing code
- **LSP**: Derived types (Create/Update) must be subsets of the base schema
- **ISP**: Minimize props, use selectors to retrieve only needed fields, split types by purpose
- **DIP**: Follow layer rules (upper → lower one-way), feature modules connect through shared layer
- **KISS**: Flatten nesting 3+ levels deep with early returns/function extraction. Prefer direct implementation over generalization
- **YAGNI**: Do not implement features not in the spec. No abstraction/flags for the future. Delete unused code
- **DRY**: Consider sharing at 3+ duplicates (Rule of Three). Do not force-share at 2 similar locations

## Implementation Workflow (TDD)

1. **Spec Confirmation** — If anything is ambiguous, show options and ask
2. **Write Tests** — Write normal, error, and boundary value cases with the test framework (see `docs/project.md`)
3. **Minimum Implementation** — Write code that passes the tests
4. **Refactoring** — Clean up while keeping tests green
5. **Verification** — Run the project's verification commands (see `docs/project.md`)
6. **Documentation Update** — Update `docs/` and `project-config.md` per "Documentation Sync" below

## Output Contract

### Gate-Specific Output Specifications

#### 🚏 Design Gate Output (Pre-Implementation)

| Field | Type | Required | Constraints |
| ----- | ---- | -------- | ----------- |
| Requirements Interpretation | Bullet points | ✅ | List acceptance criteria, one per line |
| Affected Files | Table (File, Change Type) | ✅ | Change Type ∈ {Add, Modify, Delete} |
| Test Approach | Bullet points | ✅ | State test targets and expected behavior |
| [Assumption] Items | Bullet points | Conditional | Only when specs are ambiguous |

#### 🚏 Implementation Gate Output (Post-Implementation)

| Field | Type | Required | Constraints |
| ----- | ---- | -------- | ----------- |
| Test Results | `X pass / Y fail` | ✅ | Numbers only. When failing, add cause in 1 line |
| Coverage | `Line: X% / Branch: Y%` | ✅ | State delta from target |
| Static Analysis | `Errors: X / Warnings: Y` | ✅ | State even if 0 |
| Dependency Direction | `Violations: X` | Conditional | When dependency check is enabled |
| Changed File Count | Integer | ✅ | |

#### 🚏 Final Gate Output

Present all implementation checklist items (defined in CLAUDE.md) as `[x]` / `[ ]`.

### Vocabulary Constraints

| Term | Definition |
| ---- | ---------- |
| [Assumption] | A precondition not explicitly stated in the specification |
| pass / fail | Test result states |
| Violation | A breach of dependency direction rules |
| Backward Compatible | Existing data reading is not broken |

### Structural Constraints

- Implementation code output is always in **test code → main code** order (test-first)
- Annotate each code block with the file path as a comment
- Write `describe` / `it` description text in English
- Quality reports are output in plain text (Markdown tables allowed), not JSON

## Architecture Compliance

- Follow the project's architecture pattern (see `docs/architecture.md`)
- Follow state management patterns (see `docs/development-patterns.md`)
- Keep validation schemas consistent with type definitions
- When dark mode support is needed, use semantic colors
- Follow path aliases defined in `project-config.md`

## Data Model Changes

- Define the schema first
- Maintain backward compatibility with existing data (optional additions)
- Check impact on the data persistence layer

## Documentation Sync

After implementation changes, update affected `docs/` files and `project-config.md`.
Documentation accuracy is held to the same quality standard as implementation.

### docs/ Update Triggers

| Change | Update Target |
| ------ | ------------- |
| Route additions/changes/deletions | `docs/project.md` |
| Store additions/changes/deletions | `docs/project.md` |
| npm script additions/changes | `docs/project.md` |
| Dependency package additions/version changes | `docs/project.md` |
| Feature additions/deletions/renames | `docs/architecture.md` |
| Component additions/deletions | `docs/architecture.md` |
| Test file additions/deletions | `docs/architecture.md` |
| Shared layer changes | `docs/architecture.md` |
| Code pattern/pitfall discovery/changes | `docs/development-patterns.md` |
| Schema field additions/changes | `docs/data-model.md` |
| Validation rule changes | `docs/data-model.md` |
| Form schema additions/changes | `docs/data-model.md` |

### project-config.md Update Triggers

| Change | Target Section |
| ------ | -------------- |
| New pitfalls/anti-patterns discovered | §11 (Known Pitfalls) |
| Dependency package additions/version changes | §2 (Technology Stack) |
| npm script additions/changes | §3 (Commands) |

## Test Policy

- Tests "describe the specification"
- Always provide test cases for important logic
- Coverage targets are defined in `project-config.md` section 6
- `describe` / `it` description text must state the behavior
- Output coverage reports to `testreport/coverage/` and present results

### Coverage Report Output

Output coverage reports to `testreport/coverage/` when running tests.
Configuration examples (configure to match the test framework in `project-config.md` §3):

```bash
# For Vitest
# Set the following in vite.config.ts test.coverage:
#   reportsDirectory: 'testreport/coverage'

# For Jest
# Set the following in jest.config.ts:
#   coverageDirectory: 'testreport/coverage'
```

## Dependency Direction Verification

When implementation is complete, run the dependency direction check command
(documented in `project-config.md` section 4.4) and verify no dependency direction violations.

## Git Operations

- `--no-verify` is prohibited (do not bypass pre-commit / pre-push hooks)
- When hooks fail, fix the cause of the error
- `--force` is prohibited in principle

## Prohibited Actions

- Adding features not in the specification
- Implicitly deleting or overwriting user data
- Bypassing hooks with `--no-verify`
- Using anti-patterns documented in `docs/development-patterns.md`
