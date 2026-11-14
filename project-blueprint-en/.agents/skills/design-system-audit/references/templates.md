# design-system-audit — Output templates

> Skeletons referenced from SKILL.md. Copy the structure and fill it in.

## For New Component Implementation

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

## STEP 4: Design System Documentation Generation

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
