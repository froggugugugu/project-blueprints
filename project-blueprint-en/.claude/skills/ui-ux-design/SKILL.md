---
name: ui-ux-design
description: >
  Reviews and implements UI/UX following project design systems.
  Triggers: design review, UI improvement, styling, accessibility, dark mode, responsive, layout, component design, design consistency audit, system-wide consistency.
  Covers: visual consistency, design system compliance, accessibility, responsive design, dark mode, and system-wide design consistency audit.
  Takes optional argument: /ui-ux-design <target-file or instruction>
argument-hint: "<target-file or instruction>"
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(git *), WebSearch, WebFetch, Agent, mcp__context7__resolve-library-id, mcp__context7__query-docs, mcp__plugin_context7_context7__resolve-library-id, mcp__plugin_context7_context7__query-docs
---

# UI/UX Design

A skill for UI/UX design, review, and implementation that adheres to the project's design system.
Strictly follow `CLAUDE.md` policies. For project-specific design conventions, refer to the "Design System" section in [docs/development-patterns.md](../../../docs/development-patterns.md).

## Prerequisites

| Reference File | Purpose | Fallback When Stub |
| -------------- | ------- | ------------------ |
| `docs/development-patterns.md` | Design system, UI conventions | Refer directly to `project-config.md` §7 |

## Core Principles

- Faithfully follow the design system defined for the project
- When a design system URL is documented in `docs/development-patterns.md`, reference and comply with those guidelines
- When specifications are ambiguous, present mockups or options and confirm (do not proceed by guessing)
- Avoid excessive decoration/animation; prioritize usability
- Always consider accessibility (a11y)

## Usage

```text
/ui-ux-design <target-file or UI instruction>
```

Arguments are optional. When omitted, confirm interactively with the user.
When a file path is specified, read its contents to determine the review/implementation target.

### Examples

```text
/ui-ux-design Improve the dashboard layout
/ui-ux-design src/features/dashboard/pages/DashboardPage.tsx
/ui-ux-design output/tasks/TASK_ui_redesign.md
/ui-ux-design Audit system-wide design consistency
/ui-ux-design --audit                    # Explicitly invoke system consistency audit mode
/ui-ux-design --audit --fix              # Audit + auto-fix
```

### Output Destination

- Review mode: Present report in conversation (can also output to `output/reports/review/`)
- Implementation mode: Directly modify components under `src/`
- System consistency audit mode: Output to `output/reports/review/DESIGN_AUDIT_{YYYYMMDD}.md`

### Integration with Other Skills

| Previous Step | This Skill | Next Step |
| ------------- | ---------- | --------- |
| `/plan` `/architecture` | `/ui-ux-design` | `/code-review` `/e2e-testing` |

## Modes

### Automatic Mode Detection

The mode is automatically determined based on the following criteria:

| Condition | Selected Mode |
| --------- | ------------- |
| Arguments contain `--audit` | System consistency audit mode |
| Task contains "consistency", "unify", "coherence", "cross-cutting", "system-wide", "audit" | System consistency audit mode |
| Task contains "review", "check", "inspect", "evaluate" | Review mode |
| Assigned as a reviewer within a team | Review mode |
| Task file states `role: review` | Review mode |
| Task contains "implement", "create", "fix", "add", "improve", "change" | Implementation mode |
| Assigned as a developer within a team | Implementation mode |
| Task file states `role: implement` | Implementation mode |
| None of the above match | Confirm with the user |

### Design Review Mode (Read-Only)

Used when acting as a team reviewer. Does not modify source code.

1. **Visual Consistency Check** — Identify deviations from the design system
2. **Accessibility Audit** — Verify compliance with accessibility standards (`project-config.md` section 7)
3. **Responsive Check** — Verify display at each breakpoint
4. **Dark Mode Check** — Verify visibility in both light/dark modes
5. **Report Output** — Report in the format below

### Implementation Mode

Used when implementing or modifying UI.

1. **Design System Review** — Reference the design system URL in `docs/development-patterns.md`
2. **Component Selection** — Choose appropriate components from the project's existing UI library
3. **Implementation** — Use semantic colors/tokens; no hardcoding
4. **Dark Mode Support** — Verify behavior in both light/dark modes
5. **Verification** — Confirm build and lint pass

### System Consistency Audit Mode

Scans across the entire system to detect and correct design inconsistencies between features and components.
When the `--fix` flag is provided, auto-fixes are also applied (`--fix` omitted = report only).

Detailed execution steps (Phase 1-4 scan targets, analysis criteria, classification, auto-fix rules)
are in `references/system-audit-workflow.md`.

```text
/ui-ux-design --audit                          # Entire src/
/ui-ux-design --audit src/features/touring/    # Specific feature only
/ui-ux-design --audit --fix                    # Entire + auto-fix
```

## Review Perspectives

The 7 categories checked in design review mode (design system compliance / color & theme / typography /
layout & spacing / accessibility / responsive design / interaction) are detailed in
`references/review-criteria.md`.

## Output Contract

### Review Mode Output Specification

| Section | Required | Constraints |
| ------- | -------- | ----------- |
| Overview | ✅ | All 4 items required (target file count, DS compliance, dark mode, a11y) |
| Findings | ✅ | In MUST → SHOULD → CONSIDER order. Keep headings even when 0 items |
| Good Points | ✅ | Minimum 1 item |
| Overall Verdict | ✅ | Select one from enumeration values |

### Implementation Mode Output Specification

| Field | Type | Required | Constraints |
| ----- | ---- | -------- | ----------- |
| Changed Files List | Bullet points | ✅ | File path and change summary |
| Dark Mode Verification | OK / NG | ✅ | When NG, state specific issue |
| Build Result | pass / fail | ✅ | |

### System Consistency Audit Mode Output Specification

| Section | Required | Constraints |
| ------- | -------- | ----------- |
| Audit Overview | ✅ | Scan scope, file count, feature count |
| Token Usage Statistics | ✅ | Semantic color usage rate, hardcoded value count |
| Cross-Feature Consistency Matrix | ✅ | Component usage pattern comparison table |
| Inconsistency List | ✅ | In HIGH → MEDIUM → LOW order. Keep headings even when 0 items |
| Fix Summary (`--fix` only) | Conditional | Fixed file count, fix content, test results |
| Recommended Actions | ✅ | List of items requiring human judgment |

### Severity Definitions

| Level | Criteria | Examples |
| ----- | -------- | -------- |
| **MUST** | DS violation, a11y WCAG AA non-compliance, dark mode unsupported | Hardcoded color values, not focusable, insufficient contrast ratio |
| **SHOULD** | Deviation from DS recommended patterns, responsive improvements | Inconsistent spacing, insufficient touch targets |
| **CONSIDER** | UX improvement proposals, interaction enhancements | Empty state design, loading indicators |

**PASS criteria**: every MUST finding is either "addressed" or "documented as not addressable" / Implementation mode: dark-mode check result is OK and the build passes / Audit mode: token usage rate has not regressed from the previous audit.

### Overall Verdict Enumeration

| Verdict | Condition |
| ------- | --------- |
| **Approved** | 0 MUST findings |
| **Conditionally Approved (After MUST Fixes)** | 1+ MUST findings that are fixable |
| **Needs Revision** | Major design system compliance overhaul needed |

### Finding Description Format

```
- [ ] `file-path:line-number` Finding description. **DS Basis**: Applicable guideline. **Fix Suggestion**: Specific fix.
```

### Vocabulary Constraints

| Term | Definition |
| ---- | ---------- |
| DS | Design System (defined in `docs/development-patterns.md`) |
| Semantic Color | CSS variable-based color definitions (`--foreground`, `--background`, etc.) |
| Token | Values defined in the design system (colors, spacing, typography) |
| a11y | Accessibility (WCAG 2.1 AA compliance as baseline) |
| Contrast Ratio | WCAG-defined luminance ratio. Text: 4.5:1+, large text: 3:1+ |

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

## Implementation Guidelines

### Color Handling

```typescript
// OK: Semantic colors (design system tokens)
className="text-foreground bg-background border-border"
className="text-primary bg-primary/10"

// OK: Dark mode utility classes
className="bg-gray-100 dark:bg-gray-800"

// NG: Hardcoded color values
style={{ color: '#333333' }}
className="text-[#333333]"
```

### Spacing

```typescript
// OK: Design system spacing scale
className="p-4 gap-3 space-y-2"

// NG: Magic numbers
style={{ padding: '13px', gap: '7px' }}
```

### Component Selection

Maximize use of the project's existing UI library.
Before adding new components, check if existing ones can serve as alternatives.

## Design System Reference Method

This skill references the "Design System" section in `docs/development-patterns.md`.
The following information is documented per project:

- Design system official URL
- UI component library
- Color palette/token definition location
- Icon library

**When applying to a new project, document the design system URL in `docs/development-patterns.md`.**

## Prohibited Actions

- Adding custom colors not defined in the design system
- Hardcoded color values (direct HEX/RGB specification)
- Design that ignores accessibility
- UI changes that don't support dark mode
- Adding UI elements not in the specification
- Bypassing hooks with `--no-verify`

## Related references (loaded on demand by Claude)

@.claude/quality-gates.md
@.claude/pitfalls.md
