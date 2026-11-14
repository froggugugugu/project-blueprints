# System Consistency Audit Mode — Execution Steps

Detailed workflow for `ui-ux-design --audit`. Scans across the entire system to detect and correct design inconsistencies between features and components. When the `--fix` flag is provided, auto-fixes are also applied (`--fix` omitted = report only).

## Phase 1: Information Gathering (executed in parallel via subagents)

Execute the following scans in parallel:

| Scan Target | Method | Detected Issues |
| ----------- | ------ | --------------- |
| Hardcoded color values | Grep `.tsx` `.ts` `.css` files under `src/` for `#[0-9a-fA-F]{3,8}` `rgb\(` `rgba\(` `hsl\(` patterns | DS token non-usage |
| Inline styles | Grep for `style={{` `style=\{` patterns | Magic numbers outside tokens |
| Tailwind arbitrary values | Grep for `\-\[.*\]` patterns (`text-[#...]` `p-[13px]`, etc.) | Values outside DS scale |
| Component usage patterns | Tally common components (Button, Card, Dialog, Sheet, Input, etc.) used in each feature's Page/Container | Implementation variance of same UI types |
| Responsive patterns | Grep to tally `useMediaQuery` `md:` `lg:` `sm:` breakpoint usage | Breakpoint inconsistency |
| a11y patterns | Grep to tally `role=` `aria-` `tabIndex`, detect `<div onClick` as button substitutes | a11y deficiencies |
| Icon usage | Grep to tally imports from `lucide-react` | Icon usage consistency |
| Empty/loading states | Check for `isLoading` `isEmpty` `empty` patterns in each page | Missing UX states |

## Phase 2: Pattern Analysis

Analyze the collected data as follows:

1. **Color token usage rate**: Token usage rate defined in `src/index.css` vs remaining hardcoded values
2. **Component consistency matrix**: Comparison table of how each feature uses common UI components
   - e.g., Whether Button variant/size usage is unified across features
   - e.g., Whether Dialog/Sheet usage criteria are consistent
3. **Spacing statistics**: Distribution of spacing values used (within Tailwind scale vs arbitrary values)
4. **Responsive strategy consistency**: Whether mobile/PC switching approaches are consistent across features
5. **Interaction pattern consistency**: Whether loading, error, and empty state representations are unified

## Phase 3: Inconsistency Classification & Prioritization

Classify detected inconsistencies by the following criteria:

| Classification | Criteria | Priority |
| -------------- | -------- | -------- |
| **Token violation** | Not using tokens defined in the DS | HIGH |
| **Pattern mismatch** | Same type of UI element implemented differently across features | MEDIUM |
| **Gap** | UX states (empty states, etc.) present in other features but missing | MEDIUM |
| **a11y deficiency** | Non-semantic HTML, missing ARIA | HIGH |
| **Minor difference** | Trivial differences that don't affect behavior but should be unified | LOW |

## Phase 4: Report Output or Auto-Fix

- Without `--fix`: Output audit report to `output/reports/review/DESIGN_AUDIT_{YYYYMMDD}.md`
- With `--fix`: Auto-fix in HIGH → MEDIUM order, then output fix summary
  - Auto-fix targets: Token violations (hardcoded color values → semantic colors), Tailwind arbitrary values → scale values
  - Auto-fix exclusions: Pattern mismatches (require design decisions), gaps (require new implementation)
  - After fixes, run build/lint/tests to confirm no breaking changes

## Audit Scope Control

By default, the entire `src/` directory is scanned, but scope can be narrowed:

```text
/ui-ux-design --audit                          # Entire src/
/ui-ux-design --audit src/features/touring/    # Specific feature only
/ui-ux-design --audit --fix                    # Entire + auto-fix
```

## Auto-Fix Rules

Auto-fix only applies changes that meet the following safety criteria:

1. **Mechanically unambiguous conversion**: 1:1 mapping such as `#ffffff` → `bg-background`
2. **Visually equivalent**: No visual difference before and after the fix
3. **Tests pass**: All tests pass after the fix
4. **Skip when judgment needed**: When multiple candidates exist or the context is dependent, document in the report and leave to humans
