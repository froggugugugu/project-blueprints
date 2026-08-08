# HIG Compliance Check — 8 Category Detail

Detail of the 8 categories scanned **in parallel using subagents** in `hig-compliance` Phase 2.

## Category A: Button & Action Consistency

Based on HIG "Buttons", "Menus", "Toggles" sections.

| Check Item | Detection Method | HIG Basis |
| ---------- | ---------------- | --------- |
| Same action has different captions across screens | Compare against glossary | "Use consistent terminology" |
| Destructive button lacks warning style | Check for `variant="destructive"` `color="error"` etc. | "Visually distinguish destructive actions" |
| Confirmation dialog uses "OK" | Grep for `>OK<` `"OK"` | "Use specific verbs" |
| Button placement order differs across screens | Primary/secondary action left/right position | "Place primary action in consistent position" |
| Icon-only button lacks label | Check for `aria-label` `title` presence | "Accessibility" |

## Category B: Icon Completeness & Consistency

Based on HIG "Icons", "SF Symbols" sections.

| Check Item | Detection Method | HIG Basis |
| ---------- | ---------------- | --------- |
| Same action uses different icons | Analyze icon import list vs action mapping | "Use the same icon for the same concept" |
| Icon missing where one should be set | Compare against glossary icon standards | "Consistency" |
| Icon sizes differ across screens | Compare `size=` `width=` `height=` `className` values | "Visual consistency" |
| Text+icon combinations are inconsistent | Compare `<Icon>` + text patterns in buttons | "Text and icon relationship" |

## Category C: Navigation & Screen Transition Consistency

Based on HIG "Navigation bars", "Tab bars", "Sidebars" sections.

| Check Item | Detection Method | HIG Basis |
| ---------- | ---------------- | --------- |
| Back button style/position differs across screens | Compare navigation component implementations | "Predictable navigation" |
| Breadcrumb presence inconsistent across screens | Check Breadcrumb component usage | "Show user's current location" |
| Page transition animations inconsistent | Check transition/animation usage patterns | "Consistent transitions" |
| Modal vs page navigation usage inconsistent | Check Dialog/Sheet usage criteria | "Appropriate use of modals" |

## Category D: Form & Input Consistency

Based on HIG "Text fields", "Labels", "Entering data" sections.

| Check Item | Detection Method | HIG Basis |
| ---------- | ---------------- | --------- |
| Same input field type has different styles | Compare Input/Select/Textarea variant/size | "Consistent input experience" |
| Placeholder text style inconsistent | Compare placeholder text expression patterns | "Keep hint text concise" |
| Validation error display method differs | Compare error message display patterns | "Inline feedback" |
| Required/optional display method inconsistent | Check required mark/label format | "Clear labeling" |
| Form layout (vertical/horizontal) inconsistent | Compare form structures | "Predictable layout" |

## Category E: Feedback & State Display Consistency

Based on HIG "Alerts", "Progress indicators", "Status" sections.

| Check Item | Detection Method | HIG Basis |
| ---------- | ---------------- | --------- |
| Loading display method differs across screens | Compare Spinner/Skeleton/Progress usage | "Consistent feedback" |
| Success/error notification display method differs | Compare toast/alert/banner usage | "Feedback consistency" |
| Empty state design differs or is missing across screens | Compare EmptyState component usage | "Provide guidance when no content" |
| Confirmation dialog structure differs across screens | Compare Dialog internal structure (title/description/buttons) | "Alert structure" |
| Error screen design inconsistent | Compare ErrorBoundary/error page | "Error guidance" |

## Category F: Typography & Text Consistency

Based on HIG "Typography" section.

| Check Item | Detection Method | HIG Basis |
| ---------- | ---------------- | --------- |
| Heading hierarchy differs across screens | Compare h1-h6/text-xl etc. usage patterns | "Clear information hierarchy" |
| Date/time format inconsistent | Collect and compare date display patterns | "Consistent formatting" |
| Number format inconsistent | Compare number display (comma separation, units) | "Consistent formatting" |
| Writing style inconsistent | Compare tone and voice patterns | "Consistent tone" |

## Category G: Layout & Structure Consistency

Based on HIG "Layout", "Lists and tables" sections.

| Check Item | Detection Method | HIG Basis |
| ---------- | ---------------- | --------- |
| List screen layout (table/card/list) inconsistent | Compare list display components | "Consistent content display" |
| Detail screen section structure inconsistent | Compare section division patterns | "Predictable structure" |
| Page header structure inconsistent | Compare title+action button placement | "Consistent header structure" |
| List item structure inconsistent | Compare list item internal structure | "Consistent list display" |

## Category H: Accessibility Consistency

Based on HIG "Accessibility" section.

| Check Item | Detection Method | HIG Basis |
| ---------- | ---------------- | --------- |
| Focus order is not logical | Check tabIndex usage patterns | "Logical focus order" |
| Image alt text missing | Check `<img` `<Image` alt attribute | "Alternative text" |
| Information conveyed by color alone | Check color+icon/text co-usage | "Don't rely on color alone" |
| Touch targets too small | Check button/link sizes (44x44pt minimum) | "Minimum touch target" |
