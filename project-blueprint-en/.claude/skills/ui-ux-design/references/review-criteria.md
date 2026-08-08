# Review Perspectives

The 7 categories checked in `ui-ux-design` design review mode.

## 1. Design System Compliance

- Does it follow the guidelines of the project's specified design system?
- Are color palette, typography, and spacing consistent?
- Is component usage aligned with design system recommended patterns?

## 2. Color & Theme

- Are semantic colors (CSS variables/design tokens) used?
- Are there any hardcoded color values?
- Is sufficient contrast ratio maintained in dark mode (WCAG AA: 4.5:1 or higher)?
- Are focus and hover state styles defined?

## 3. Typography

- Do font sizes and weights follow the design system scale?
- Is the heading hierarchy (h1–h6) logical?
- Are line height and letter spacing readable?

## 4. Layout & Spacing

- Is the design system's spacing scale used?
- Are grid/flex usages appropriate?
- Does whitespace appropriately express visual hierarchy?

## 5. Accessibility (a11y)

- Is semantic HTML used (`button`, `nav`, `main`, etc.)?
- Are ARIA attributes appropriate (neither excessive nor insufficient)?
- Is keyboard navigation possible?
- Is the content understandable by screen readers?
- Are focus indicators visible?

## 6. Responsive Design

- Are breakpoints appropriately set?
- Does nothing break from mobile to desktop?
- Are touch targets an appropriate size (44x44px or larger recommended)?

## 7. Interaction

- Is loading state appropriately communicated?
- Are error states visually clear?
- Are transitions/animations natural (not excessive)?
- Is there an empty state design?
