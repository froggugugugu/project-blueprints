# ui-ux-design — Output templates

> Skeletons referenced from SKILL.md. Copy the structure and fill it in.

## Contents

- Report Format (Review Mode)
- Overview
- Findings
- Good Points
- Overall Verdict
- Report Format (System Consistency Audit Mode)
- Audit Overview
- Token Usage Statistics
- Cross-Feature Consistency Matrix
- Inconsistency List
- Fix Summary (--fix execution only)
- Recommended Actions
- Score

## Report Format (Review Mode)

```markdown
# UI/UX Review: [Target Overview]

## Overview
- Target Files: X
- Design System Compliance: OK / NG
- Dark Mode Support: OK / NG
- Accessibility: OK / NG

## Findings

### MUST (Required Fixes)
- [ ] `file:line` Finding. **DS Basis**: Guideline. **Fix Suggestion**: Fix method.

### SHOULD (Recommended Fixes)
- [ ] `file:line` Finding. **Reason**: Rationale. **Fix Suggestion**: Fix method.

### CONSIDER (For Consideration)
- [ ] `file:line` Finding. **Improvement Direction**: Suggestion.

## Good Points
- [Design aspects done well]

## Overall Verdict
- **Approved** / **Conditionally Approved (After MUST Fixes)** / **Needs Revision**
```

## Report Format (System Consistency Audit Mode)

```markdown
# Design Consistency Audit Report: {YYYY-MM-DD}

## Audit Overview
- Scan Scope: {entire src/ or specific directory}
- Scanned Files: X
- Features: Y
- Execution Time: {ISO 8601}

## Token Usage Statistics

### Color Tokens
| Metric | Value |
| ------ | ----- |
| Semantic color usage locations | X |
| Remaining hardcoded color values | Y |
| Token usage rate | Z% |

### Hardcoded Color Value Details
| File | Line | Value | Recommended Token |
| ---- | ---- | ----- | ----------------- |
| `path/to/file.tsx` | 42 | `#ffffff` | `bg-background` |

### Spacing
| Metric | Value |
| ------ | ----- |
| Within Tailwind scale | X locations |
| Arbitrary values (`-[Npx]`) | Y locations |

## Cross-Feature Consistency Matrix

### Component Usage Patterns
| Component | auth | map-editor | routes | touring | stamps | bikes | settings | admin |
| --------- | ---- | ---------- | ------ | ------- | ------ | ----- | -------- | ----- |
| Button    | ✅   | ✅         | ✅     | ✅      | ✅     | ✅    | ✅       | ✅    |
| Card      | —    | —          | ✅     | ✅      | ✅     | ✅    | —        | —     |
| Dialog    | —    | ✅         | —      | ✅      | —      | ✅    | ✅       | ✅    |
| Sheet     | —    | ✅         | —      | ✅      | —      | —     | —        | —     |

### Responsive Strategy
| Feature | SP/PC Switch Method | Breakpoint | Notes |
| ------- | ------------------- | ---------- | ----- |
| map-editor | useMediaQuery | 768px | — |
| touring | useMediaQuery | 768px | — |

### UX State Implementation Status
| Feature | Loading | Error | Empty State |
| ------- | ------- | ----- | ----------- |
| map-editor | ✅ | ✅ | ✅ |
| touring | ✅ | ✅ | ✅ |

## Inconsistency List

### HIGH (Token Violations / a11y Deficiencies)
- [ ] `file:line` Inconsistency description. **Detection Pattern**: Detection method. **Fix Suggestion**: Specific fix.

### MEDIUM (Pattern Mismatches / Gaps)
- [ ] `file:line` Inconsistency description. **Comparison Target**: Implementation in other features. **Fix Suggestion**: Unification method.

### LOW (Minor Differences)
- [ ] `file:line` Inconsistency description. **Recommendation**: Unification suggestion.

## Fix Summary (--fix execution only)
- Fixed Files: X
- Fix Content:
  - [Fix 1 summary]
  - [Fix 2 summary]
- Build Result: pass / fail
- Test Result: X passed, Y failed

## Recommended Actions
Items requiring human judgment:
1. [Description of inconsistency requiring design decisions and options]
2. [Description of gap requiring new implementation]

## Score
| Aspect | Score | Rating |
| ------ | ----- | ------ |
| Token Compliance | X/100 | — |
| Cross-Feature Consistency | X/100 | — |
| a11y Adequacy | X/100 | — |
| UX State Coverage | X/100 | — |
| **Overall** | **X/100** | — |
```
