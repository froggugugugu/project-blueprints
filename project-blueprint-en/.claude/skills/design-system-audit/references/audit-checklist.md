# Consistency Audit Detailed Checklist

## A. Spacing

- [ ] Top/bottom padding inside buttons is unified
- [ ] Left/right padding inside buttons is unified
- [ ] Spacing between adjacent buttons is unified
- [ ] Top/bottom margins of input forms are unified
- [ ] Inner padding of cards/panels is unified
- [ ] Outer margins between cards/panels are unified
- [ ] Spacing between list items is unified
- [ ] Inner padding of modals/dialogs is unified
- [ ] Screen edge (left/right) margins are unified across all screens
- [ ] All margin values follow the 8px grid (or token values)

## B. Typography

- [ ] Screen title font size is the same across all screens
- [ ] Section heading font size is the same across all screens
- [ ] Body text font size is the same across all screens
- [ ] Supplementary/caption text is unified
- [ ] Font weight roles (bold/regular/light) are consistent
- [ ] Line height (line-height) is unified per role
- [ ] Font families are not unintentionally mixed

## C. Component Size & Shape

- [ ] Primary button height is unified across all screens
- [ ] Secondary button height is unified across all screens
- [ ] Buttons with the same role do not have different sizes
- [ ] Text input field height is unified with buttons
- [ ] Dropdown height is unified with input fields
- [ ] Icon sizes are unified per role (sm/md/lg)
- [ ] Border-radius is unified per role
- [ ] Checkbox/radio button sizes are unified

## D. Title & Heading Position

- [ ] Screen title "top margin (from screen edge or header)" is unified across all screens
- [ ] Screen title "bottom margin (distance to content)" is unified
- [ ] Screen title horizontal position (left/center/right) is unified
- [ ] Section heading before/after margins are unified
- [ ] Line spacing for multi-line titles is considered
- [ ] Title position relationship with in-page navigation (tabs, etc.) is unified

## E. Color

- [ ] Text colors are unified by role (primary/secondary/disabled/error/link)
- [ ] Background colors follow tokens (surface/background/overlay, etc.)
- [ ] Border colors follow tokens
- [ ] Error/warning/success/info colors are unified
- [ ] Hover color changes are unified
- [ ] No unintended "hardcoded colors" (e.g., #ff0000 inline)

## F. Grid & Alignment

- [ ] Content left edges are aligned (no misalignment)
- [ ] Column widths are unified in multi-column layouts
- [ ] Vertical alignment of icons and text is unified (center/baseline)
- [ ] Vertical alignment of labels and input fields is unified
- [ ] Alignment within button groups is unified

## G. Ratio & Scale Compliance

- [ ] No off-token spacing values like "5px", "11px", "22px" are used
- [ ] No off-scale font sizes are mixed in
- [ ] No unintended exception values in component sizes

## H. Interaction States

- [ ] Button hover state is unified across all buttons
- [ ] Button disabled state styling is unified
- [ ] Button active (pressed) state is unified
- [ ] Input field focus state is unified
- [ ] Link hover/visited states are unified
- [ ] Loading state styling is unified

---

## Audit Scoring (Optional)

```
Category Score: 0 (unchecked) / 1 (issues found) / 2 (acceptable) / 3 (compliant)

Total Score = Sum ÷ (Check Count × 3) × 100 %

80%+: Release ready
60-79%: Minor fixes recommended
Below 60%: Fixes required
```
