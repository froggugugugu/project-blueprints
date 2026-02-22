---
name: refactoring
description: >
  Executes safe, incremental refactoring with rollback capability.
  Triggers: refactor, restructure, extract, consolidate, decompose, move, rename, split, merge, reorganize.
  Covers: feature responsibility migration, store split/merge, component decomposition, utility extraction, type consolidation, dependency rule fixes.
  Takes optional argument: /refactoring <target-directory or instruction>
---

# Safe Refactoring

Performs incremental, rollback-capable refactoring.
Strictly follow `CLAUDE.md` policies. For project-specific code patterns, refer to [docs/development-patterns.md](../../../docs/development-patterns.md).

## Prerequisites

| Reference File | Purpose | Fallback When Stub |
| -------------- | ------- | ------------------ |
| `docs/project.md` | Commands | Refer directly to `project-config.md` §3 |
| `docs/architecture.md` | Dependency direction rules | Refer directly to `project-config.md` §4.4 |
| `docs/development-patterns.md` | Code conventions | Refer directly to `project-config.md` §11 |

## Core Principles

- **Do not change behavior** — Refactoring improves internal structure while preserving external behavior
- Proceed incrementally (tests must be green at each step)
- Commit in rollback-capable units
- When specifications are ambiguous, ask before implementing (do not proceed by guessing)
- Avoid excessive abstraction

## Usage

```text
/refactoring <target-directory or refactoring instruction>
```

Arguments are optional. When omitted, confirm interactively with the user.
When a file path or directory is specified, use that scope as the refactoring target.

### Examples

```text
/refactoring Split components in src/features/assignment/
/refactoring Fix dependency direction violations
/refactoring output/tasks/TASK_refactor_stores.md
```

### Output Destination

- Refactored code: Under `src/`
- Report: Presented in conversation

### Integration with Other Skills

| Previous Step | This Skill | Next Step |
| ------------- | ---------- | --------- |
| `/plan` `/code-review` | `/refactoring` | `/code-review` `/e2e-testing` |

## Refactoring Patterns

### 1. Feature Responsibility Migration

Fix direct dependencies between feature modules to go through the shared layer.

- Identify migration targets (types, utilities, constants)
- Move to the appropriate location in the shared layer
- Re-export from the original location for backward compatibility
- Verify violation resolution with the dependency direction check command (in `project-config.md`)

### 2. Store Split/Merge

- Preserve persistence keys
- When changing schema structure, add as optional (backward compatible)
- Verify inter-store reference consistency

### 3. Component Decomposition

- Separate **Container** (uses stores/hooks) and **Presentational** (props only)
- Place Containers in pages directory or feature top level
- Place Presentational components in components directory
- Maintain the same props interface after decomposition

### 4. Shared Utility Extraction

- Move logic used across multiple features to the shared layer
- Re-export from the original location for backward compatibility
- Move or update test references accordingly

### 5. Type Definition Cleanup

- Unify to type derivation from validation schemas
- Resolve divergence between manual type definitions and schemas
- Consolidate into shared type definition directory

### 6. Dependency Direction Violation Fixes

- Detect violations with the dependency direction check tool
- Fix according to the architecture dependency direction rules (in `project-config.md`)

## Refactoring Workflow

### Phase 0: Prerequisites Verification

Verify all existing tests pass (baseline for starting refactoring).
Run the project's verification commands (see `docs/project.md`).

If not all tests pass, do not start refactoring. Fix existing issues first.

### Phase 1: Scope Analysis

1. **Identify Impact Scope** — List target files and dependent files
2. **Understand Dependencies** — Check the current dependency graph with dependency direction check
3. **Assess Test Coverage** — Record coverage baseline
4. **Risk Assessment** — Determine step decomposition granularity based on impact scope size

### Phase 2: Refactoring Plan

1. Decompose refactoring into steps (each step is a testable unit)
2. State inter-step dependencies
3. Set rollback points

**🚏 Design Gate**: Present refactoring plan and wait for confirmation

### Phase 3: Incremental Execution

Repeat the following for each step:

1. Implement code changes
2. Run tests
3. Run static analysis
4. Run dependency direction check
5. Verify tests are green

**If tests fail**: Identify the cause and fix. If unable to fix, roll back the step.

### Phase 4: Completion Verification

1. Full verification: Run all project verification commands
2. Coverage comparison: Compare with Phase 1 baseline (must not decrease)
3. Documentation update: Update `docs/` per "Documentation Sync" below

**🚏 Completion Gate**: Present completion report

## Output Contract

### Section Definitions

| Section | Required | Constraints |
| ------- | -------- | ----------- |
| Overview | ✅ | Pattern name (enumeration value), changed file count, step count |
| Step-by-Step Execution Results | ✅ | List all steps in a table |
| Before/After Quality Comparison | ✅ | 4 metrics required (test count, coverage, dependency violations, circular dependencies) |
| Change Summary | ✅ | Organized in 4 categories (Moved, New, Deleted, Re-exported) |
| Documentation Updates | ✅ | Updated `docs/` files and change descriptions |

### Pattern Enumeration

| Pattern | Application Context |
| ------- | ------------------- |
| Feature Responsibility Migration | Fix direct inter-feature dependencies via shared layer |
| Store Split | Separate 1 store into multiple stores |
| Store Merge | Consolidate multiple stores into 1 store |
| Component Decomposition | Separate large component into Container/Presentational |
| Shared Utility Extraction | Move feature-specific logic to shared layer |
| Type Definition Cleanup | Unify manual types to schema derivation |
| Dependency Direction Fix | Resolve dependency check tool violations |

### Vocabulary Constraints

| Term | Definition |
| ---- | ---------- |
| Step | The minimum unit of change that is testable |
| Rollback | Undoing a step's changes with `git checkout` |
| Re-export | Maintaining backward compatibility via `export { X } from '...'` from the original location |
| Baseline | Initial quality metrics recorded in Phase 0 |

### Structural Constraints

- Steps are described in numerical order (1, 2, 3...)
- Before/After delta column uses signed notation (`+3`, `-2`, `±0`)
- Change summary file paths are relative from `src/`
- When coverage decreases, state the reason

## Report Format

```markdown
# Refactoring Report: [Target Overview]

## Overview
- Pattern: [Select from enumeration values]
- Changed Files: X
- Steps: Y

## Step-by-Step Execution Results

| # | Step | Tests | Static Analysis | Dependencies | Status |
| - | ---- | ----- | --------------- | ------------ | ------ |
| 1 | [Description] | pass | OK | OK | Complete |

## Before / After Quality Comparison

| Metric | Before | After | Delta |
| ------ | ------ | ----- | ----- |
| Test Count | X | Y | +Z |
| Coverage (Line) | X% | Y% | +Z% |
| Dependency Violations | X | Y | -Z |
| Circular Dependencies | X | Y | -Z |

## Change Summary
- Moved: [File list]
- New: [File list]
- Deleted: [File list]
- Re-exported: [File list]

## Documentation Updates
- [Updated docs/ files and change descriptions]
```

## Documentation Sync

After refactoring, always update affected `docs/` files.

| Change | Update Target |
| ------ | ------------- |
| Feature additions/deletions/renames | `docs/architecture.md` |
| Component additions/deletions/moves | `docs/architecture.md` |
| Test file additions/deletions/moves | `docs/architecture.md` |
| Shared layer changes | `docs/architecture.md` |
| Store additions/splits/merges | `docs/project.md` |
| Route additions/changes/deletions | `docs/project.md` |
| Schema field additions/changes | `docs/data-model.md` |
| Code pattern/pitfall discovery/changes | `docs/development-patterns.md` |

## Git Operations

- `--no-verify` is prohibited (do not bypass pre-commit / pre-push hooks)
- When hooks fail, fix the cause of the error
- `--force` is prohibited in principle
- Create rollback-capable commits at each step completion

## Prohibited Actions

- Starting refactoring when tests are not green
- Changes that alter behavior (that's a feature change, not refactoring)
- Changes that break backward compatibility (moves without re-exports)
- Using anti-patterns documented in `docs/development-patterns.md`
- Bypassing hooks with `--no-verify`
