# refactoring — Output templates

> Skeletons referenced from SKILL.md. Copy the structure and fill it in.

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
