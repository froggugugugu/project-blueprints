---
name: ui-ux-design
description: >
  Reviews and implements UI/UX following project design systems.
  Triggers: design review, UI improvement, styling, accessibility, dark mode, responsive, layout, component design.
  Covers: visual consistency, design system compliance, accessibility, responsive design, and dark mode.
  Takes optional argument: /ui-ux-design <target-file or instruction>
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
```

### Output Destination

- Review mode: Present report in conversation (can also output to `output/reports/review/`)
- Implementation mode: Directly modify components under `src/`

### Integration with Other Skills

| Previous Step | This Skill | Next Step |
| ------------- | ---------- | --------- |
| `/plan` `/architecture` | `/ui-ux-design` | `/code-review` `/e2e-testing` |

## Modes

### Automatic Mode Detection

The mode is automatically determined based on the following criteria:

| Condition | Selected Mode |
| --------- | ------------- |
| Task contains "review", "check", "inspect", "audit", "evaluate" | Review mode |
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

## Review Perspectives

### 1. Design System Compliance

- Does it follow the guidelines of the project's specified design system?
- Are color palette, typography, and spacing consistent?
- Is component usage aligned with design system recommended patterns?

### 2. Color & Theme

- Are semantic colors (CSS variables/design tokens) used?
- Are there any hardcoded color values?
- Is sufficient contrast ratio maintained in dark mode (WCAG AA: 4.5:1 or higher)?
- Are focus and hover state styles defined?

### 3. Typography

- Do font sizes and weights follow the design system scale?
- Is the heading hierarchy (h1–h6) logical?
- Are line height and letter spacing readable?

### 4. Layout & Spacing

- Is the design system's spacing scale used?
- Are grid/flex usages appropriate?
- Does whitespace appropriately express visual hierarchy?

### 5. Accessibility (a11y)

- Is semantic HTML used (`button`, `nav`, `main`, etc.)?
- Are ARIA attributes appropriate (neither excessive nor insufficient)?
- Is keyboard navigation possible?
- Is the content understandable by screen readers?
- Are focus indicators visible?

### 6. Responsive Design

- Are breakpoints appropriately set?
- Does nothing break from mobile to desktop?
- Are touch targets an appropriate size (44x44px or larger recommended)?

### 7. Interaction

- Is loading state appropriately communicated?
- Are error states visually clear?
- Are transitions/animations natural (not excessive)?
- Is there an empty state design?

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

### Severity Definitions

| Level | Criteria | Examples |
| ----- | -------- | -------- |
| **MUST** | DS violation, a11y WCAG AA non-compliance, dark mode unsupported | Hardcoded color values, not focusable, insufficient contrast ratio |
| **SHOULD** | Deviation from DS recommended patterns, responsive improvements | Inconsistent spacing, insufficient touch targets |
| **CONSIDER** | UX improvement proposals, interaction enhancements | Empty state design, loading indicators |

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
