# code-review — Output templates

> Skeletons referenced from SKILL.md. Copy the structure and fill it in.

## Report Format

```markdown
# Code Review: [Change Overview]

## Overview
- Changed Files: X
- Impact Scope: [Feature name]
- Spec Compliance: OK / NG
- Documentation Sync: OK / NG

## Quantitative Measurement (optional / gate 5 evidence)

| Metric | Before | After | delta | Source |
| ------ | ------ | ----- | ----- | ------ |
| Coverage | XX.X% | YY.Y% | +ΔΔ% | testreport/coverage |
| Static analysis errors | N | M | -K | npm run lint |
| Bundle size | XX KB | YY KB | +ΔΔ% | npm run build |
| Performance metrics | XX ms | YY ms | +ΔΔ% | output/reports/performance / testreport |
| Test failures | N | M | -K | CI logs / testreport |

> When no data is provided, write `_no measurement data provided_` for this section

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
