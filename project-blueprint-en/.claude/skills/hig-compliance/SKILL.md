---
name: hig-compliance
description: >
  This skill should be used when the user asks to "check HIG compliance", "unify button labels", "fix icon consistency",
  or mentions "HIG compliance", "UI consistency", "button unification", "icon unification", "terminology unification",
  "cross-screen consistency", "system-wide UI check".
  Apple Human Interface Guidelines (HIG) based system-wide UI consistency check and correction.
  Takes optional argument: /hig-compliance <target-directory or instruction>
argument-hint: "<target-directory or instruction>"
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(git *), Agent, WebSearch, WebFetch
---

# HIG Compliance — Apple Human Interface Guidelines Compliance Check & Correction

A skill that uses Apple Human Interface Guidelines (https://developer.apple.com/design/human-interface-guidelines/)
as the authoritative standard to **systematically check and correct UI consistency across the entire system**.

Specializes in detecting and fixing "subtle inconsistencies between screens" that commonly arise during parallel implementation by Agent Teams.

> **Relationship with existing skills**:
> - `design-system-audit`: Design token (numerical system) consistency → **Token level**
> - `ui-ux-design`: Individual screen UI design, review, implementation → **Screen level**
> - `hig-compliance` (this skill): System-wide behavior, terminology, and structural consistency based on HIG principles → **System level**

---

## Prerequisites

| Reference File | Purpose | Fallback |
| -------------- | ------- | -------- |
| `docs/development-patterns.md` | Design system & UI conventions | Refer to `project-config.md` §7 directly |
| Apple HIG (official URL) | UI guideline standards | Fetch directly via WebFetch |

### How to Reference Apple HIG

1. **WebFetch** to directly reference `https://developer.apple.com/design/human-interface-guidelines/`
2. Fetch individual category pages as needed (buttons, navigation, icons, etc.)
3. If HIG-based rules are documented in the project's `docs/development-patterns.md`, prioritize those

---

## Core Principles

- **Apple HIG is the primary standard** — when in doubt, refer back to HIG
- **System-wide consistency is the top priority** — prioritize system-wide unification over individual screen "goodness"
- **Detection is mechanical and exhaustive** — subtle differences missed by visual inspection are this skill's target
- **Correction proposals are specific and singular** — state "unify to A", not "A or B"
- Only present options to the user when judgment is genuinely uncertain

---

## Usage

```text
/hig-compliance                           # Check entire src/
/hig-compliance src/features/             # Specific directory only
/hig-compliance --fix                     # Check + auto-correct
/hig-compliance --fix src/features/       # Specific directory + auto-correct
/hig-compliance --glossary                # Generate/update UI glossary only
```

### Output Destinations

- Check report: `output/reports/review/HIG_COMPLIANCE_{YYYYMMDD}.md`
- UI glossary (when generated): `docs/ui-glossary.md`

### Integration with Other Skills

| Upstream | This Skill | Downstream |
| -------- | ---------- | ---------- |
| `/implementing-features` `/ui-ux-design` | `/hig-compliance` | `/code-review` `/e2e-testing` |
| `/design-system-audit` | `/hig-compliance` | — |

**Recommended flow**: Implementation complete → `design-system-audit` (token consistency) → `hig-compliance` (HIG compliance & consistency) → `code-review`

---

## Workflow

### Phase 1: Establish UI Glossary (first run or `--glossary`)

Generate a glossary to unify UI terminology used across the project.
Executed when `docs/ui-glossary.md` does not exist, or when `--glossary` is specified.

**1.1 Collect Current Terminology**

Scan in parallel using subagents:

| Scan Target | Method | Collected Content |
| ----------- | ------ | ----------------- |
| Button labels | Grep for `>Save<` `>Cancel<` `label=` `title=` `aria-label=` etc. | All button caption list |
| Page titles | Grep for `<h1` `<title` `PageTitle` `Header` components | All screen title list |
| Navigation | Grep for menu, tab, breadcrumb labels | Navigation item list |
| Form labels | Grep for `<label` `placeholder=` | Form item list |
| Alerts/Notifications | Grep for `toast` `alert` `confirm` `dialog` messages | Notification message list |
| Empty states | Grep for `empty` `no-data` `EmptyState` | Empty state message list |

**1.2 Standardize Terminology**

Standardize terminology based on HIG principles:

- **Verb unification**: "Save" / "Store" / "Keep" → unify to one
- **Cancel-type unification**: "Cancel" / "Dismiss" / "Go Back" / "Close" → define usage rules per context
- **Confirmation unification**: "OK" / "Confirm" / "Yes" / "Got it" → unify to HIG-recommended expressions
- **Destructive actions**: "Delete" / "Remove" / "Erase" → use explicit verbs per HIG ("Delete [item]")

**1.3 Output `docs/ui-glossary.md`**

The template (4 standard tables: button labels, page titles, icons, notification messages) is in
`references/ui-glossary-template.md`.

---

### Phase 2: HIG Compliance Check (8 Categories)

Scan the 8 categories defined in `references/hig-check-categories.md`
(A: Button & Action / B: Icons / C: Navigation / D: Form & Input / E: Feedback & State / F: Typography /
G: Layout & Structure / H: Accessibility) **in parallel using subagents**. See the reference file for
each category's check items, detection methods, and HIG basis.

---

### Phase 3: Consistency Analysis

Based on Phase 2 collected data, **visualize cross-screen differences in matrices**.

**3.1 Button Caption Consistency Matrix**

```text
| Action | Screen A | Screen B | Screen C | Unified | Status |
|--------|----------|----------|----------|---------|--------|
| Save   | Save     | Store    | Save it  | Save    | NG     |
| Delete | Delete   | Delete   | Remove   | Delete  | NG     |
| Back   | Back     | Cancel   | Close    | (context) | Review |
```

**3.2 Icon Usage Consistency Matrix**

```text
| Action | Screen A | Screen B | Screen C | Unified | Status |
|--------|----------|----------|----------|---------|--------|
| Edit   | Pencil   | Edit2    | — (missing) | Pencil | NG  |
| Delete | Trash2   | Trash    | Trash2   | Trash2  | NG     |
| Add    | Plus     | Plus     | PlusCircle | Plus   | NG     |
```

**3.3 UX State Implementation Matrix**

```text
| Screen   | Loading  | Error | Empty State | Confirm Dialog |
|----------|----------|-------|-------------|----------------|
| Screen A | Spinner  | toast | Yes         | Yes            |
| Screen B | Skeleton | alert | —           | Yes            |
| Screen C | Spinner  | toast | Yes         | —              |
```

---

### Phase 4: Classify and Prioritize Inconsistencies

| Classification | Criteria | Priority | Auto-fix |
| -------------- | -------- | -------- | -------- |
| **Caption mismatch** | Same action with different labels | HIGH | Yes |
| **Icon missing** | Standard icon should be set but absent | HIGH | Yes |
| **Icon mismatch** | Same action with different icons | HIGH | Yes |
| **"OK" in confirmation dialog** | Should be replaced with specific verb | MEDIUM | Yes |
| **Feedback method mismatch** | Mixed toast/alert etc. | MEDIUM | Partial |
| **Empty state missing** | Empty state exists in other screens but not here | MEDIUM | No (new implementation) |
| **Layout pattern mismatch** | Page header structure differences etc. | MEDIUM | Partial |
| **Style/format mismatch** | Date format, formal/informal tone mixing | LOW | Yes |
| **a11y issues** | Missing alt, insufficient touch targets | HIGH | Partial |

---

### Phase 5: Report Output or Auto-Correction

#### Report Only (Default)

Output to `output/reports/review/HIG_COMPLIANCE_{YYYYMMDD}.md`.

#### Auto-Correction (`--fix`)

Apply corrections in the following order:

1. **Caption unification**: Bulk replace button/link labels based on glossary
2. **Icon unification**: Fix imports and components based on glossary icon standards
3. **Confirmation dialog fix**: Replace "OK" → specific verb only when 1:1 mapping is defined in glossary
4. Run build, lint, and tests after corrections to confirm no breaking changes

> **Report only (not auto-corrected)**: Icon gap completion (requires new element addition), format unification (date/number function changes have wide impact). These are documented in the report and left to human judgment.

**Auto-correction safety criteria**:
- Only execute transformations with 1:1 mapping defined in glossary
- When multiple candidates exist, document in report and leave to human judgment
- Confirm functionality is unchanged via tests before and after correction

---

## Output Contract

### Report Output Specification

| Section | Required | Constraints |
| ------- | -------- | ----------- |
| Check overview | Yes | Scan scope, file count, check item count |
| Glossary comparison results | Yes | Match rate, mismatch list |
| Per-category check results | Yes | Categories A-H. Keep headings even for 0 findings |
| Consistency matrices | Yes | Button, icon, UX state comparison tables |
| Inconsistency list | Yes | HIGH → MEDIUM → LOW order |
| Fix summary (`--fix` only) | Conditional | Fixed file count, fix content, test results |
| Recommended actions | Yes | Items requiring human judgment |
| HIG compliance score | Yes | Per-category score + overall score |

### Severity Definitions

| Level | Criteria | Examples |
| ----- | -------- | -------- |
| **MUST** | Explicit HIG violation, UI contradiction for same action, a11y issues | Different captions for same "Save" action, missing icons |
| **SHOULD** | Deviation from HIG recommendations, pattern mismatch | Loading display inconsistency, missing empty states |
| **CONSIDER** | Areas with room for improvement | Minor style differences, slight layout variations |

### Finding Description Format

```text
- [ ] `file-path:line-number` Finding description. **HIG basis**: Applicable guideline. **Unified to**: Specific correction. **Affected screens**: List of impacted screens.
```

**PASS criteria**: every MUST finding has a unified-to correction / when run with `--fix`, tests pass after the fix / the HIG compliance score has not dropped versus the previous scan (if any).

---

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

---

## Glossary Maintenance

- **Initial**: Auto-generated in Phase 1 → User review → Saved to `docs/ui-glossary.md`
- **Updates**: Re-scan and show diff with `/hig-compliance --glossary`
- **During implementation**: Reference `docs/ui-glossary.md` when running `/implementing-features` to prevent drift in new screens

### How to Integrate Glossary with Other Skills

When `docs/ui-glossary.md` exists, the following skills automatically reference it:
- `/implementing-features`: Conform captions and icons to glossary during new UI implementation
- `/ui-ux-design`: Add glossary conformance to review checklist items
- `/code-review`: Verify glossary compliance during reviews involving UI changes

> **Integration prerequisite**: Add a reference to the glossary in the design system section of
> `docs/development-patterns.md` so the above skills load `docs/ui-glossary.md` during their "design system check" step.

---

## Prohibited Actions

- Adding custom captions/labels not defined in the glossary
- UI changes that violate HIG principles
- Arbitrary icon changes (follow glossary standards)
- Bypassing hooks with `--no-verify`
- Force pushing with `--force`

## Related references (loaded on demand by Claude)

@.claude/quality-gates.md
@.claude/pitfalls.md
