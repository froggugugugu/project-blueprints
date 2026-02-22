---
name: code-review
description: >
  Reviews code changes for quality, conventions compliance, performance, and security.
  Triggers: review, check, validate, inspect, audit code quality.
  Source-code read-only — never modifies source code or test files.
  Outputs review report to output/reports/review/ (requires Write permission to output/reports/review/).
  Takes optional argument: /code-review <target-file or instruction>
context: fork
---

# Code Review

A skill that reviews project code changes.
Provides structured feedback based on `CLAUDE.md` conventions and the project-specific checklist in [docs/development-patterns.md](../../../docs/development-patterns.md).

## Prerequisites

| Reference File | Purpose | Fallback When Stub |
| -------------- | ------- | ------------------ |
| `docs/architecture.md` | Architecture pattern | Refer directly to `project-config.md` §4 |
| `docs/development-patterns.md` | Code conventions, anti-patterns | Refer directly to `project-config.md` §11 |

## Core Principles

- **Never modify source code** (read-only)
- Findings must be specific and actionable (no "just feels off")
- State severity clearly (MUST / SHOULD / CONSIDER)
- Mention good points as well (don't make it findings-only)
- Verify compliance with specification requirements (task file) as the top priority

## Usage

```text
/code-review <target-file or review instruction>
```

Arguments are optional. When omitted, review the scope of changes from git diff.
When a file path is specified, review changes in that file.

### Examples

```text
/code-review Review the latest commit
/code-review src/features/assignment/
/code-review output/tasks/TASK_auth.md
```

### Output Destination

- Default: Present report in conversation
- File output: `output/reports/review/REVIEW_<target>.md` (when `output/` directory exists)

### Integration with Other Skills

| Previous Step | This Skill | Next Step |
| ------------- | ---------- | --------- |
| `/implementing-features` `/ui-ux-design` `/refactoring` | `/code-review` | (Final step) |

## Review Workflow

1. **Understand Change Scope** — Review the list of changed files and understand the impact scope
2. **Spec Verification** — Cross-check task file acceptance criteria against the implementation
3. **Perspective-Based Checks** — Check against the review perspectives below
4. **Report Output** — Return structured feedback in the format below

## Review Perspectives

### 1. Spec Compliance

- Are all acceptance criteria from the task file met?
- Are there features added that are not in the specification?
- Are data model changes as specified?

### 2. Code Quality & Readability

- Do names express intent (variables, functions, components)?
- Does each function have a single responsibility?
- Are there unnecessary code fragments or commented-out code?
- Are type definitions appropriate (use of `any`, unnecessary assertions)?

### 3. Architecture Compliance

- Does it follow the project's architecture pattern (see `docs/architecture.md`)?
- Is state management used correctly (see [docs/development-patterns.md](../../../docs/development-patterns.md))?
- Are schemas and types consistent?
- Are path aliases used?
- Are there dependency direction rule violations (see `CLAUDE.md` "Architecture Governance")?

### 4. Performance

- Is memoization used appropriately (neither excessive nor insufficient)?
- Are there anti-patterns documented in `docs/development-patterns.md` related to performance?
- Are unnecessary re-renders avoided?

### 5. Security

- XSS: No unsafe HTML injection?
- Input sanitization/validation?
- No violations of `project-config.md` section 10 security policy?

### 6. Dark Mode Support

- Are color specifications compatible with both light/dark?
- Are there no hardcoded color values?

### 7. Testing

- Do important logic paths have unit tests?
- Do tests verify specification behavior (not implementation details)?
- Do test description texts clearly state the behavior?

### 8. Backward Compatibility

- Is migration of existing data considered?
- Are schema changes optional or have default values?
- Are existing public interfaces preserved?

### 9. Documentation Sync

- Has `docs/` been updated to reflect implementation changes?
- If documentation is not updated, report as a MUST finding

## Output Contract

### Section Definitions

| Section | Required | Constraints |
| ------- | -------- | ----------- |
| Overview | ✅ | Must include changed file count, impact scope, spec compliance, doc sync |
| Findings | ✅ | In MUST → SHOULD → CONSIDER order. Keep headings even when 0 items per level |
| Good Points | ✅ | Minimum 1 item. Don't make it a findings-only review |
| Overall Verdict | ✅ | Select one from enumeration values |

### Severity Definitions

| Level | Criteria | Examples |
| ----- | -------- | -------- |
| **MUST** | CLAUDE.md rule violation, existing test breakage, security vulnerability, dependency direction violation, docs/ not updated | Anti-pattern usage, hardcoded color values, XSS |
| **SHOULD** | Readability degradation, performance concerns, insufficient tests, inappropriate naming | Missing memoization, any type usage, insufficient test coverage |
| **CONSIDER** | Improvement suggestions, alternative approaches, code cleanup | Function extraction suggestion, type definition cleanup |

### Overall Verdict Enumeration

| Verdict | Condition |
| ------- | --------- |
| **Approved** | 0 MUST findings |
| **Conditionally Approved (After MUST Fixes)** | 1+ MUST findings that are fixable |
| **Needs Revision** | Architecture changes or design overhaul needed |

### Finding Description Format

```
- [ ] `file-path:line-number` Finding description. **Reason**: Rationale. **Fix Suggestion**: Specific fix method.
```

- File path is relative from `src/`
- Line number must not be omitted (for ranges use `L10-L15`)
- MUST/SHOULD must include a fix suggestion. CONSIDER is optional

### Vocabulary Constraints

| Term | Definition |
| ---- | ---------- |
| Spec Compliance | All acceptance criteria from the task file are met |
| Documentation Sync | Updates to `docs/` corresponding to implementation changes are complete |
| Dependency Direction Violation | Breach of rules in CLAUDE.md "Architecture Governance" |

## Report Format

```markdown
# Code Review: [Change Overview]

## Overview
- Changed Files: X
- Impact Scope: [Feature name]
- Spec Compliance: OK / NG
- Documentation Sync: OK / NG

## Findings

### MUST (Required Fixes)
- [ ] `file:line` Finding. **Reason**: Rationale. **Fix Suggestion**: Fix method.

### SHOULD (Recommended Fixes)
- [ ] `file:line` Finding. **Reason**: Rationale. **Fix Suggestion**: Fix method.

### CONSIDER (For Consideration)
- [ ] `file:line` Finding. **Reason**: Rationale.

## Good Points
- [Specific positive points]

## Overall Verdict
- **Approved** / **Conditionally Approved (After MUST Fixes)** / **Needs Revision**
```

## Prohibited Actions

- Modifying source code (including test files)
- Requesting additions not in the specification
- Findings based on personal preference (without project convention rationale)
- Vague findings without severity
