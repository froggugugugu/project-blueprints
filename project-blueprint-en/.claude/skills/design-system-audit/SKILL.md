---
name: design-system-audit
version: 1.0.0
description: A skill for verifying and standardizing design consistency across the entire UI system. Use it for referencing design guidelines for new screens, auditing consistency of existing screens, and generating Claude Code instruction templates. It defines and verifies numerical systems (design tokens) for buttons, spacing, typography, colors, etc. based on ratio principles such as the golden ratio and silver ratio. Use this skill whenever you feel "the design is inconsistent," "we need to unify spacing standards," "title positions are misaligned across screens," or "we want to apply ratios to clean up the UI." Technology-stack agnostic (applicable to Web/Qt/QML/mobile).
argument-hint: "<target-directory or instruction>"
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(git *), Agent, WebSearch, WebFetch
context: main
---

# Design System Audit Skill

A skill for defining, verifying, and documenting design consistency across the entire UI system.
Provides numerically-based design principles from the perspective of a **design system engineer** / **frontend architect**.

---

## What This Skill Can Do

| Use Case | Description |
|----------|-------------|
| **New Design Guidelines** | Design token definitions and application rules based on ratio principles |
| **Existing Screen Consistency Audit** | Detect and record inconsistencies using a categorized checklist |
| **Claude Code Instruction Templates** | Generate standardized prompts to pass during implementation |

---

## STEP 1: Design Token Definition

### Choosing a Ratio System

First, decide on a **base size** and **scale ratio**.

| Ratio Name | Value | Best Suited For |
|------------|-------|-----------------|
| **Golden Ratio** | 1.618 | Spacious layouts, reading-oriented UIs |
| **Silver Ratio** | 1.414 | Japanese-style balance, compact UIs |
| **Major Third** | 1.250 | High information density, business UIs |
| **Perfect Fourth** | 1.333 | General purpose, balanced |

> **Recommended**: For business tools, automotive HUDs, and other visibility-focused use cases, **Silver Ratio (1.414)** or **Major Third (1.250)** are easiest to work with.

### Spacing Tokens (Margins & Gaps)

Set the base as `base = 8px` (or any reference value) and expand the scale.

```
space-1 = base × 0.5   =  4px   (minimum margin, icon inner spacing, etc.)
space-2 = base × 1     =  8px   (between related elements)
space-3 = base × 1.5   = 12px   (intra-group margin)
space-4 = base × 2     = 16px   (standard intra-section margin)
space-5 = base × 3     = 24px   (between sections)
space-6 = base × 4     = 32px   (between blocks, large margin)
space-7 = base × 6     = 48px   (screen edge margin, etc.)
space-8 = base × 8     = 64px   (before/after large headings, etc.)
```

Ratio-scaled version (golden ratio base, base=8px):
```
space-1 =  5px  (8 ÷ 1.618)
space-2 =  8px  (base)
space-3 = 13px  (8 × 1.618)
space-4 = 21px  (13 × 1.618)
space-5 = 34px  (21 × 1.618)
space-6 = 55px  (34 × 1.618)
```

### Typography Tokens

Set the base font size as `base = 14px` or `16px`.

```
text-xs   = base ÷ ratio²
text-sm   = base ÷ ratio
text-md   = base             (body text)
text-lg   = base × ratio     (subheading)
text-xl   = base × ratio²    (heading)
text-2xl  = base × ratio³    (large heading, screen title)
text-3xl  = base × ratio⁴    (hero, number emphasis)
```

Example with Silver Ratio (1.414), base=14px:
```
text-xs  =  7px
text-sm  = 10px
text-md  = 14px
text-lg  = 20px
text-xl  = 28px
text-2xl = 40px
text-3xl = 56px
```

### Component Size Tokens

```
button-height-sm  = space-6         (approx. 32px)
button-height-md  = space-7         (approx. 48px)
button-height-lg  = space-7         (approx. 48px)
button-padding-x  = space-4 to 5    (16-24px)

input-height      = align with button-height-md
icon-size-sm      = 16px
icon-size-md      = 24px
icon-size-lg      = 32px

border-radius-sm  = 4px
border-radius-md  = 8px
border-radius-lg  = 16px
border-radius-full= 9999px
```

### Title & Header Position Unification Rules

```
Screen Title
  - Font size: text-2xl fixed
  - Top margin (screen edge to title): space-6 or space-7
  - Bottom margin (title to content): space-5
  - Horizontal position: left-align (business) / center (wizard/modal)

Section Heading
  - Font size: text-xl
  - Top margin: space-6
  - Bottom margin: space-4

Subheading
  - Font size: text-lg
  - Top margin: space-5
  - Bottom margin: space-3
```

---

## STEP 2: Consistency Audit Checklist

When evaluating existing screens, check from the following perspectives.
→ See `references/audit-checklist.md` for the detailed checklist.

### Audit Categories

| # | Category | Key Checks |
|---|----------|------------|
| A | **Spacing** | Whether margins follow token values |
| B | **Typography** | Consistency of font size, weight, and line height |
| C | **Components** | Unified height and shape of buttons, inputs, and icons |
| D | **Title & Heading Position** | Unified title top/bottom and horizontal position across screens |
| E | **Color** | Whether colors outside color tokens are used |
| F | **Grid & Alignment** | Alignment of element left/right edges |
| G | **Ratio Compliance** | Whether exception values outside the scale exist |
| H | **Interaction** | Unified hover, focus, and disabled states |

### Inconsistency Recording Format

```
[Audit Record]
Screen Name: ___________
Date: ___________

| Category | Location | Issue | Current Value | Correct Value | Priority |
|----------|----------|-------|---------------|---------------|----------|
| A | Button bottom margin | Uses space-3 (12px) | 12px | 16px (space-4) | Medium |
| D | Screen title top margin | Varies 20-40px across screens | Variable | 32px (space-6) fixed | High |
```

---

## STEP 3: Claude Code Instruction Templates

### For New Component Implementation

```
When implementing this component, follow these design tokens.

[Spacing Standards]
- Element spacing: 8px multiple grid (8, 16, 24, 32, 48, 64px)
- Between sections: 32px (space-6)
- Button inner padding: top/bottom 12px × left/right 20px

[Typography]
- Screen title: 28px / weight-700
- Section heading: 20px / weight-600
- Body text: 14px / weight-400
- Supplementary text: 12px / weight-400

[Component Sizes]
- Button height: 40px (md) / 32px (sm) / 48px (lg)
- Input field height: 40px (unified with button md)
- Icon: 24px (standard)

[Title Position Rules]
- Screen title top margin: 32px
- Screen title bottom margin: 24px
- Horizontal position: left-aligned

[Anti-Patterns]
- Do not use arbitrary pixel values outside tokens (e.g., 15px, 22px, 37px)
- Do not use different sizes for components with the same role
```

### For Existing Screen Fix Instructions

```
Please fix the following consistency issues.

[Fix Target: Spacing]
- [Location]: [current]px → [correct]px (token: space-N)

[Fix Target: Title Position]
- Unify title top margin to 32px across all screens
- Target files: [file paths]

[Verification]
- After fixing, verify that balance with other elements is not broken
- Keep fixes minimal; do not change unrelated areas
```

---

## STEP 4: Design System Documentation Generation

Store in the project's `design-system.md` or `DESIGN_TOKENS.md` with the following structure.

```markdown
# [Project Name] Design System

## Core Principles
- Base size: Npx
- Scale ratio: [ratio name] (×N.NNN)
- Grid unit: Npx

## Design Tokens
### Spacing
...(transcribe values from STEP 1)

### Typography
...

### Components
...

## Per-Screen Rules
### Title & Heading Position
...

## Audit Log
| Date | Auditor | Target Screen | Issue Count | Status |
|------|---------|---------------|-------------|--------|
| yyyy-mm-dd | ___ | ___ | N | Resolved/Unresolved |
```

---

## Reference Files

Detailed audit checklist → `references/audit-checklist.md`
Ratio calculation reference → `references/ratio-reference.md`
