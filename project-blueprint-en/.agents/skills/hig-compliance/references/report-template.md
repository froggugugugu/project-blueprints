# hig-compliance — Output templates

> Skeletons referenced from SKILL.md. Copy the structure and fill it in.

## Report Format

```markdown
# HIG Compliance Check Report: {YYYY-MM-DD}

## Check Overview
- Scan scope: {entire src/ or specific directory}
- Scanned file count: X
- Screen (page) count: Y
- Check item count: Z
- Glossary: {used docs/ui-glossary.md / newly generated}

## Glossary Comparison Results
- Button caption match rate: X%
- Icon standard fulfillment rate: X%
- Mismatch count: X

## Per-Category Check Results

### A: Button & Action Consistency
- [ ] `file:line` Finding. **HIG basis**: xxx. **Unified to**: yyy.

### B: Icon Completeness & Consistency
...

### C: Navigation & Screen Transition Consistency
...

### D: Form & Input Consistency
...

### E: Feedback & State Display Consistency
...

### F: Typography & Text Consistency
...

### G: Layout & Structure Consistency
...

### H: Accessibility Consistency
...

## Consistency Matrices

### Button Captions
| Action | Screen A | Screen B | ... | Unified | Status |
| ------ | -------- | -------- | --- | ------- | ------ |

### Icon Usage
| Action | Screen A | Screen B | ... | Unified | Status |
| ------ | -------- | -------- | --- | ------- | ------ |

### UX State Implementation
| Screen | Loading | Error | Empty State | Confirm Dialog |
| ------ | ------- | ----- | ----------- | -------------- |

## Inconsistency List

### MUST (Required Fix)
- [ ] ...

### SHOULD (Recommended Fix)
- [ ] ...

### CONSIDER (For Consideration)
- [ ] ...

## Fix Summary (--fix execution only)
- Fixed file count: X
- Fix content:
  - [Fix overview]
- Build result: pass / fail
- Test result: X passed, Y failed

## Recommended Actions
1. [Items requiring human judgment]

## HIG Compliance Score
| Category | Score | Rating |
| -------- | ----- | ------ |
| A: Buttons & Actions | X/100 | — |
| B: Icons | X/100 | — |
| C: Navigation | X/100 | — |
| D: Forms & Input | X/100 | — |
| E: Feedback | X/100 | — |
| F: Typography | X/100 | — |
| G: Layout & Structure | X/100 | — |
| H: Accessibility | X/100 | — |
| **Overall** | **X/100** | — |
```
