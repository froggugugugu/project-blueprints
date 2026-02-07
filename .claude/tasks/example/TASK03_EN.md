# TASK Template — Feature Development Specification

> **Purpose**: Copy this file for each feature (or sub-feature) and save as `TASKXX_<feature_name>.md`
> **Audience**: Developers and testers (teammates read this file to carry out the work)
> **Note**: This file is a specification for "what to build." The "who does what and how" is described in TEAMCREATE.md.

---

## 1. Basic Information

| Item | Details |
|---|---|
| Task ID | TASK03 |
| Feature Name | Assignment |
| Related TEAMCREATE | TEAMCREATE_ASSIGNMENT.md |
| Target Screen / URL | assignment |
| Priority | High |

---

## 2. Feature Overview

### Assignment Editing Grid

- Users can add members to each task within a project's WBS, broken down by effort column, and enter numeric values on a **monthly basis** within the date range defined by the **master schedule (大日程)**.
- The view is **switchable by project**.
- The GUI closely resembles the existing WBS editing screen — it is a **TreeGrid**.
- The WBS editing screen shows projects in a tree structure down to leaf tasks with editable cells. This screen extends that by allowing an additional **member layer** beneath each leaf task.
- **Rows** display tasks and members in a tree hierarchy. **Columns** span from the earliest start month to the latest end month defined in the master schedule, on a monthly basis.
- Members are selected via a **select box** populated with names from the Members Management settings.
- When a new row is added, the member field starts **unselected (empty)**. On focus-out (or equivalent row commit), the member **must** be selected. If unselected, validation fires and prompts the user to choose a member; the row is **not** committed.
- When the master schedule is **extended**, the column structure updates to include the new months.
- When the master schedule is **shortened**, the column structure updates accordingly, but **previously entered data is retained** (hidden, not deleted).
- Numeric values set per project, task, member, and month are **persisted** (localStorage).
- If the **total assignment for a given member in a given month across all projects exceeds 1.0**, a toast notification warns the user about the over-allocation, and validation is applied.

### Member-by-Month Cross-Project Summary Grid

- Positioned **above** the TreeGrid editing area, this is a compact summary table (slightly smaller font size).
- **Rows**: member names. **Columns**: same month columns as the editing area.
- Each cell shows the **sum of all project assignments** for that member in that month (e.g., if Member A has 0.4 on Project X, 0.3 on Project Y, and 0.2 on Project Z in April, the cell shows 0.9).
- **Hover tooltip** shows the per-project breakdown.
- This grid is wrapped in an **accordion** so it can be collapsed to give more space to the editing area.

---

## 3. Target Files & Directories

| Type | Path | Notes |
|---|---|---|
| Page | src/features/assignment/pages/AssignmentPage.tsx | New page |
| Components | src/features/assignment/components/XXXDialogs.tsx, XXXTree.tsx, XXXTreeGrid.tsx, etc. — create as needed | New |
| Unit Tests | src/test/assignment.test.ts (and others as needed) | Developer creates |
| E2E Tests | e2e/assignment.spec.ts | Tester creates |

> **Important**: Do NOT modify any existing files outside the above scope without explicit permission.

---

## 4. Functional Requirements

### 4.1 Screen Specification

- The assignment editing area uses a **TreeGrid** layout identical to the existing WBS editing screen.
- Member selection is done via a **select box**; the options come from the Members Management data.
- Assignment values:
  - Minimum granularity: **2 decimal places**, zero-padded for alignment (e.g., `0.50`).
  - **Half-width numerals only**; full-width input is **auto-converted** to half-width.
- **Horizontal scroll pinning**: columns up to and including the Member column are **frozen** (pinned left).
- **Vertical scroll pinning**: header row is **frozen** (pinned top).
- Data is **saved (persisted)** on every input commit.

---

## 5. Non-Functional Requirements

| Item | Requirement |
|---|---|
| Accessibility | Appropriate `label` / `aria-*` attributes on all form elements. Full keyboard operability. |
| Responsive | Support mobile (375px+), tablet, and desktop. |
| Performance | Avoid unnecessary re-renders. Prevent double-click submission. |

---

## 6. Unit Test Policy (for Developers)

Developers must create the following unit tests alongside implementation.

| Test Aspect | Details |
|---|---|
| Rendering | All form elements render correctly. |
| Validation | Error messages appear for empty input / invalid format. |
| Submission | Correct API/store calls are made on valid input. |
| Loading State | Submit button is disabled while saving. |
| Error Display | User-friendly error messages are shown. |

Library: **React Testing Library + Vitest**

---

## 7. E2E Test Policy (for Testers)

Testers should understand the functional requirements and create Playwright E2E tests covering at least the following scenarios.

### Basic Operations

| # | Scenario | Expected Result |
|---|---|---|
| 1 | Switch to a different project | The WBS task tree and member rows for the selected project are displayed with existing values correctly populated. |
| 2 | Expand / collapse parent-child task hierarchy in the TreeGrid | Child tasks and their member rows expand or collapse correctly. |
| 3 | Add a member row under a leaf task | An empty row appears with the member select box unselected and all month cells empty. |
| 4 | Select a member from the select box on an added row | The select box shows member names from Members Management; selection and commit work correctly. |
| 5 | Enter a numeric value (e.g., 0.5) in a per-project, per-task, per-member, per-month cell | The entered value is reflected in the cell and persisted. |
| 6 | Assign the same member to multiple tasks with different monthly values | Values are stored independently per task and month. |

### Column Structure (Master Schedule Linkage)

| # | Scenario | Expected Result |
|---|---|---|
| 7 | Extend the master schedule end date (e.g., Dec → next Mar) | New month columns are appended on the right; existing values are preserved. |
| 8 | Move the master schedule start date earlier (e.g., Apr → Jan) | New month columns are prepended on the left; existing values are preserved. |
| 9 | Shorten the master schedule end date (e.g., next Mar → Dec) | Columns outside the new range are hidden, but the underlying data is retained internally. |
| 10 | Shorten the master schedule start date (e.g., Jan → Apr) | Columns outside the new range are hidden, but the underlying data is retained internally. |
| 11 | Shorten the schedule, then re-extend to the original range | Previously hidden month columns reappear with their original values fully restored. |

### Validation — Member Not Selected

| # | Scenario | Expected Result |
|---|---|---|
| 12 | Add a member row and focus out without selecting a member | A validation error is displayed prompting the user to select a member. The row is NOT committed. |
| 13 | Add a member row and attempt to enter a value without selecting a member | A warning appears stating the member must be selected first. |
| 14 | After a validation error, select a member and commit | The error clears, the row is committed, and month cells become editable. |

### Validation — Over-Allocation

| # | Scenario | Expected Result |
|---|---|---|
| 15 | Enter values that cause Member A's April total to exceed 1.0 across projects (e.g., 0.6 on Project X + 0.5 on Project Y) | A toast notification warns: "Member A's assignment in April exceeds 1.0." |
| 16 | Reduce values so the total falls to 1.0 or below | The over-allocation toast disappears; normal state is restored. |
| 17 | Multiple members exceed 1.0 in different months simultaneously | A separate toast warning is shown for each over-allocated member/month combination. |

### Data Persistence

| # | Scenario | Expected Result |
|---|---|---|
| 18 | Enter values, switch to another project, then switch back | All entered values are preserved. |
| 19 | Enter values, then reload the page | All per-project, per-task, per-member, per-month values are fully restored. |
| 20 | Add member rows and enter values, navigate away, then return | All added rows and entered values are preserved. |

### Member-by-Month Summary Grid (Top Section)

| # | Scenario | Expected Result |
|---|---|---|
| 21 | Display the summary grid | Rows show member names, columns show master schedule months, and each cell shows the cross-project total assignment for that member/month. |
| 22 | Enter 0.4 for Member A in April in the editing area (with 0.3 from other projects) | The summary grid cell for Member A / April updates immediately to 0.7. |
| 23 | Hover over a summary cell (e.g., Member A, April = 0.9) | A tooltip shows per-project breakdown (e.g., Project X: 0.4, Project Y: 0.3, Project Z: 0.2). |
| 24 | Hover over a summary cell where total exceeds 1.0 | The breakdown tooltip is shown, plus a visual indicator (e.g., red text) signaling over-allocation. |
| 25 | Click the accordion collapse button | The summary grid collapses and the editing area expands. |
| 26 | Click the accordion expand button | The summary grid reappears with up-to-date totals. |
| 27 | Collapse the summary, edit values in the editing area, then re-expand | The summary reflects the updated totals. |

### Composite Scenarios

| # | Scenario | Expected Result |
|---|---|---|
| 28 | Assign Member A to Projects X, Y, Z; enter values in the same month; check the summary grid | The summary cell for Member A in that month shows the combined total; hover shows per-project breakdown. |
| 29 | Extend the master schedule, enter assignments in newly added months, check the summary | The new month columns appear in the summary grid with correct totals. |
| 30 | Shorten the master schedule, then re-extend; verify restored data in the summary | Restored data is correctly reflected in the summary grid totals and hover breakdowns. |

Library: **Playwright**

---

## 8. Notes

Include all related features and interactions. Go beyond the basics to create a fully functional implementation.
