---
name: performance
description: >
  Measures and optimizes application performance using a measurement-first approach.
  Triggers: performance, optimize, slow, bundle size, re-render, memory, profiler, lazy load, memoize.
  Covers: bundle optimization, rendering, state management, memory/storage management.
  Takes optional argument: /performance <target-component or instruction>
---

# Performance Optimization

Performs performance optimization using a measurement-first approach.
Strictly follow `CLAUDE.md` policies. For project-specific code patterns, refer to [docs/development-patterns.md](../../../docs/development-patterns.md).

## Prerequisites

| Reference File | Purpose | Fallback When Stub |
| -------------- | ------- | ------------------ |
| `docs/project.md` | Commands | Refer directly to `project-config.md` §3 |
| `docs/development-patterns.md` | Performance patterns | Refer directly to `project-config.md` §2, §11 |

## Core Principles

- **No optimization without measurement** — Base decisions on data, not guesses
- Always compare before/after numbers (Before/After)
- Sacrificing readability for optimization is a last resort
- Avoid excessive optimization (skip if there's no perceivable improvement)
- Do not break existing tests

## Usage

```text
/performance <target-component or optimization instruction>
```

Arguments are optional. When omitted, confirm interactively with the user.
When a file path is specified, analyze performance around that file.

### Examples

```text
/performance Dashboard initial load is slow
/performance src/features/assignment/components/AssignmentTreeGrid.tsx
/performance Optimize bundle size
```

### Output Destination

- Optimized code: Under `src/` (following the project's directory structure)
- Report: Presented in conversation

### Integration with Other Skills

| Previous Step | This Skill | Next Step |
| ------------- | ---------- | --------- |
| `/implementing-features` | `/performance` | `/code-review` |

## Optimization Categories

### 1. Bundle Optimization

- Visualize bundle composition with bundle analysis tools
- Code splitting via dynamic imports
- Verify tree-shaking (eliminate imports with side effects)
- Measure build size

### 2. Rendering Optimization

- Identify bottlenecks with profiler
- Appropriate use of memoization (framework-provided memoization APIs)
- Detect and eliminate unnecessary re-renders
- Minimize re-render scope through component splitting

**Note**: Only add memoization when bottlenecks are confirmed through measurement. Do not add preventive memoization.

### 3. State Management Optimization

- Avoid anti-patterns documented in `docs/development-patterns.md` for state management
- Subscribe to individual fields (only needed fields, not entire objects)
- Minimize state updates

### 4. Memory & Storage Management

- Storage quota monitoring
- Split storage strategies for large-scale data
- Cleanup of unnecessary data

## Optimization Workflow

1. **Identify Bottleneck** — Identify problem areas through user reports or measurement tools
2. **Baseline Measurement** — Record pre-optimization numbers
3. **Root Cause Analysis** — Identify root cause from profiling results
4. **🚏 Analysis Gate** — Present bottleneck and optimization approach, wait for confirmation
5. **Implement Optimization** — Make changes with minimum impact scope
6. **Verify Effect** — Measure post-optimization numbers and compare Before/After
7. **Test Verification** — Run the project's verification commands (see `docs/project.md`)
8. **🚏 Completion Gate** — Present effectiveness report

## Output Contract

### 🚏 Analysis Gate Output

| Field | Type | Required | Constraints |
| ----- | ---- | -------- | ----------- |
| Bottleneck Location | file-path:line-number | ✅ | Identified based on measurement data |
| Measurement Value | Number + Unit | ✅ | Guessed values not allowed. State measurement method |
| Root Cause Analysis | Text | ✅ | Explain root cause in 1–3 sentences |
| Optimization Approach | Bullet points | ✅ | List optimizations to perform in priority order |
| Expected Improvement | Text | Conditional | When quantitatively estimable |

### 🚏 Completion Gate Output

| Field | Type | Required | Constraints |
| ----- | ---- | -------- | ----------- |
| Before/After Comparison | Table | ✅ | Metric name, Before value, After value, Improvement rate |
| Test Results | `X pass / Y fail` | ✅ | |
| Coverage | `Line: X% / Branch: Y%` | ✅ | Delta from baseline |
| Static Analysis | `Errors: X` | ✅ | |

### Vocabulary Constraints

| Term | Definition |
| ---- | ---------- |
| Baseline | Pre-optimization measurement values. The basis for comparison |
| Bottleneck | The primary cause of performance degradation identified through measurement |
| Improvement Rate | `(Before - After) / Before × 100` (percentage) |
| Perceivable Improvement | A change in response speed that users can notice |

### Structural Constraints

- Before/After table metrics must be measured under identical conditions
- Measurement values must always include units (KB, ms, count, items)
- Optimization decisions based on "guessing" or "probably" are prohibited

## Report Format

```markdown
# Performance Optimization Report: [Target Overview]

## Overview
- Target: [Optimized feature/component]
- Category: Bundle / Rendering / State Management / Memory
- Changed Files: X

## Bottleneck Analysis
- Location: `file-path:line-number`
- Measurement: [Number + Unit] (Method: [method])
- Cause: [Root cause explanation]

## Before / After

| Metric | Before | After | Improvement |
| ------ | ------ | ----- | ----------- |
| [Metric name] | [Value + Unit] | [Value + Unit] | [X%] |

## Optimizations Applied
1. [Change description and rationale]

## Test Results
- Tests: X pass / Y fail
- Coverage: Line: X% / Branch: Y%
- Static Analysis: 0 errors

## Notes
- [Side effects or trade-offs if any]
```

## Documentation Sync

After optimization changes, always update affected `docs/` files.

| Change | Update Target |
| ------ | ------------- |
| Code pattern/optimization pattern discovery | `docs/development-patterns.md` |
| Feature structure changes (lazy load, etc.) | `docs/architecture.md` |
| Store split/merge | `docs/project.md` |
| Dependency package additions | `docs/project.md` |

## Git Operations

- `--no-verify` is prohibited (do not bypass pre-commit / pre-push hooks)
- When hooks fail, fix the cause of the error
- `--force` is prohibited in principle

## Prohibited Actions

- Optimization without measurement (no starting based on "probably slow")
- Using anti-patterns documented in `docs/development-patterns.md`
- Micro-optimizations that significantly degrade readability
- Changes that break existing tests
- Bypassing hooks with `--no-verify`
