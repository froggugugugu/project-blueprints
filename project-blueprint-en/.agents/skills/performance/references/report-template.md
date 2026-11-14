# performance — Output templates

> Skeletons referenced from SKILL.md. Copy the structure and fill it in.

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
