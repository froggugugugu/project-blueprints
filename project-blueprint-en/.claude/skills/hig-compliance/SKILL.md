---
name: hig-compliance
version: 1.0.0
description: >
  This skill should be used when the user asks to "check HIG compliance", "unify button labels", "fix icon consistency",
  or mentions "HIG compliance", "UI consistency", "button unification", "icon unification", "terminology unification",
  "cross-screen consistency", "system-wide UI check".
  Apple Human Interface Guidelines (HIG) based system-wide UI consistency check and correction.
  Takes optional argument: /hig-compliance <target-directory or instruction>
argument-hint: "<target-directory or instruction>"
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(git *), Agent, WebSearch, WebFetch
context: main
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

```markdown
# UI Glossary

## Button Label Standards

| Action | Standard Label | Incorrect Examples | HIG Basis |
| ------ | -------------- | ------------------ | --------- |
| Create | Create | New, Add, Make new | Buttons: concise verbs indicating the action |
| Save | Save | Store, Keep, OK | Buttons: use specific verbs |
| Delete | Delete | Remove, Erase, Discard | Buttons: clearly indicate destructive actions |
| Cancel | Cancel | Dismiss, Never mind, Go back | Buttons: "Cancel" as the standard |
| Confirm | [specific verb] | OK, Yes, Confirm | Buttons: prefer specific verbs over "OK" |

## Page Title Standards

| Pattern | Format | Example |
| ------- | ------ | ------- |
| List screen | [Noun] List or [Noun]s | Users |
| Detail screen | [Noun] Details or [Noun Name] | User Details |
| Create screen | Create [Noun] | Create User |
| Edit screen | Edit [Noun] | Edit User |
| Settings screen | Settings or [Category] Settings | Notification Settings |

## Icon Usage Standards

| Action | Standard Icon | Required/Recommended |
| ------ | ------------- | -------------------- |
| Add | Plus / PlusCircle | Recommended |
| Delete | Trash2 | Required |
| Edit | Pencil / Edit | Recommended |
| Search | Search | Required |
| Settings | Settings / Gear | Required |
| Back | ArrowLeft / ChevronLeft | Required |
| Close | X | Required |
| Menu | Menu / MoreHorizontal / MoreVertical | Required |
| Filter | Filter / SlidersHorizontal | Recommended |
| Sort | ArrowUpDown | Recommended |

## Notification Message Standards

| Type | Format | Example |
| ---- | ------ | ------- |
| Success | "[Noun] [past tense verb] successfully" | User created successfully |
| Error | "Failed to [verb] [noun]" | Failed to create user |
| Confirmation | "[Verb] this [noun]?" | Delete this user? |
| Warning | "[Impact description]. [Verb]?" | This action cannot be undone. Delete? |
```

---

### Phase 2: HIG Compliance Check (8 Categories)

Scan the following categories **in parallel using subagents**.

#### Category A: Button & Action Consistency

Based on HIG "Buttons", "Menus", "Toggles" sections.

| Check Item | Detection Method | HIG Basis |
| ---------- | ---------------- | --------- |
| Same action has different captions across screens | Compare against glossary | "Use consistent terminology" |
| Destructive button lacks warning style | Check for `variant="destructive"` `color="error"` etc. | "Visually distinguish destructive actions" |
| Confirmation dialog uses "OK" | Grep for `>OK<` `"OK"` | "Use specific verbs" |
| Button placement order differs across screens | Primary/secondary action left/right position | "Place primary action in consistent position" |
| Icon-only button lacks label | Check for `aria-label` `title` presence | "Accessibility" |

#### Category B: Icon Completeness & Consistency

Based on HIG "Icons", "SF Symbols" sections.

| Check Item | Detection Method | HIG Basis |
| ---------- | ---------------- | --------- |
| Same action uses different icons | Analyze icon import list vs action mapping | "Use the same icon for the same concept" |
| Icon missing where one should be set | Compare against glossary icon standards | "Consistency" |
| Icon sizes differ across screens | Compare `size=` `width=` `height=` `className` values | "Visual consistency" |
| Text+icon combinations are inconsistent | Compare `<Icon>` + text patterns in buttons | "Text and icon relationship" |

#### Category C: Navigation & Screen Transition Consistency

Based on HIG "Navigation bars", "Tab bars", "Sidebars" sections.

| Check Item | Detection Method | HIG Basis |
| ---------- | ---------------- | --------- |
| Back button style/position differs across screens | Compare navigation component implementations | "Predictable navigation" |
| Breadcrumb presence inconsistent across screens | Check Breadcrumb component usage | "Show user's current location" |
| Page transition animations inconsistent | Check transition/animation usage patterns | "Consistent transitions" |
| Modal vs page navigation usage inconsistent | Check Dialog/Sheet usage criteria | "Appropriate use of modals" |

#### Category D: Form & Input Consistency

Based on HIG "Text fields", "Labels", "Entering data" sections.

| Check Item | Detection Method | HIG Basis |
| ---------- | ---------------- | --------- |
| Same input field type has different styles | Compare Input/Select/Textarea variant/size | "Consistent input experience" |
| Placeholder text style inconsistent | Compare placeholder text expression patterns | "Keep hint text concise" |
| Validation error display method differs | Compare error message display patterns | "Inline feedback" |
| Required/optional display method inconsistent | Check required mark/label format | "Clear labeling" |
| Form layout (vertical/horizontal) inconsistent | Compare form structures | "Predictable layout" |

#### Category E: Feedback & State Display Consistency

Based on HIG "Alerts", "Progress indicators", "Status" sections.

| Check Item | Detection Method | HIG Basis |
| ---------- | ---------------- | --------- |
| Loading display method differs across screens | Compare Spinner/Skeleton/Progress usage | "Consistent feedback" |
| Success/error notification display method differs | Compare toast/alert/banner usage | "Feedback consistency" |
| Empty state design differs or is missing across screens | Compare EmptyState component usage | "Provide guidance when no content" |
| Confirmation dialog structure differs across screens | Compare Dialog internal structure (title/description/buttons) | "Alert structure" |
| Error screen design inconsistent | Compare ErrorBoundary/error page | "Error guidance" |

#### Category F: Typography & Text Consistency

Based on HIG "Typography" section.

| Check Item | Detection Method | HIG Basis |
| ---------- | ---------------- | --------- |
| Heading hierarchy differs across screens | Compare h1-h6/text-xl etc. usage patterns | "Clear information hierarchy" |
| Date/time format inconsistent | Collect and compare date display patterns | "Consistent formatting" |
| Number format inconsistent | Compare number display (comma separation, units) | "Consistent formatting" |
| Writing style inconsistent | Compare tone and voice patterns | "Consistent tone" |

#### Category G: Layout & Structure Consistency

Based on HIG "Layout", "Lists and tables" sections.

| Check Item | Detection Method | HIG Basis |
| ---------- | ---------------- | --------- |
| List screen layout (table/card/list) inconsistent | Compare list display components | "Consistent content display" |
| Detail screen section structure inconsistent | Compare section division patterns | "Predictable structure" |
| Page header structure inconsistent | Compare title+action button placement | "Consistent header structure" |
| List item structure inconsistent | Compare list item internal structure | "Consistent list display" |

#### Category H: Accessibility Consistency

Based on HIG "Accessibility" section.

| Check Item | Detection Method | HIG Basis |
| ---------- | ---------------- | --------- |
| Focus order is not logical | Check tabIndex usage patterns | "Logical focus order" |
| Image alt text missing | Check `<img` `<Image` alt attribute | "Alternative text" |
| Information conveyed by color alone | Check color+icon/text co-usage | "Don't rely on color alone" |
| Touch targets too small | Check button/link sizes (44x44pt minimum) | "Minimum touch target" |

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
