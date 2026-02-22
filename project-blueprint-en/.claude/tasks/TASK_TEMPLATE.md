# TASK Template — Feature Development Specification

> **Purpose**: Copy this file for each feature (or part of a feature) and save it as `TASKXX_<feature-name>.md`
> **Audience**: Developers and testers (team members read this file to perform their work)
> **Note**: This file is a specification for "what to build." "Who does what and how" is defined in team definitions under `.claude/teams/`.

---

## 1. Basic Information

| Item | Details |
|---|---|
| Task ID | TASKXX |
| Feature Name | <!-- e.g., Login Form --> |
| Related Team Definition | <!-- e.g., TEAM_FEATURE.md --> |
| Target Screen / URL | <!-- e.g., /login --> |
| Priority | High / Medium / Low |

---

## 2. Feature Overview

<!-- Briefly describe what this feature does from the user's perspective -->

---

## 3. Target Files / Directories

<!-- Enter paths according to the directory structure in docs/architecture.md -->

| Type | Path | Notes |
|---|---|---|
| <!-- Page / Component / Store / Schema / Utility / Test --> | <!-- src/... --> | <!-- New / Modified / Deleted --> |

<!--
Example entries (FSD pattern):
| Page           | src/features/xxx/pages/XxxPage.tsx           |                |
| Component      | src/features/xxx/components/XxxDialog.tsx     | New            |
| Store          | src/stores/xxx-store.ts                      | Add action     |
| Schema         | src/shared/types/xxx.ts                      | Add field      |
| Utility        | src/shared/utils/xxx-utils.ts                |                |
| Test           | src/shared/utils/__tests__/xxx-utils.test.ts | New            |
-->

> **Important**: Do not modify any files other than those listed above.

---

## 4. Functional Requirements

### 4.1 Screen Specification

<!-- Describe screen components, layout, and state transitions -->

### 4.2 Validation

| Field | Rule | Error Message |
|---|---|---|
<!-- e.g., | Name | Required / Max 100 chars | "Please enter a name" | -->

### 4.3 Data Persistence

| Item | Details |
|---|---|
| Store | <!-- Target store name --> |
| Persistence | <!-- Describe the method --> |
| Migration | <!-- Backward compatibility with existing data --> |

### 4.4 State Management

<!-- Describe how state is managed and how it interacts with stores -->

---

## 5. Non-Functional Requirements

| Item | Requirement |
|---|---|
| Accessibility | <!-- Appropriate label/aria attributes for forms. Fully operable via keyboard --> |
| Responsive | <!-- Supported viewports --> |
| Performance | <!-- Prevent unnecessary re-renders, prevent double-clicks, etc. --> |
| Error Handling | <!-- Display messages by error type --> |

---

## 6. Unit Test Policy (For Developers)

Developers must create the following unit tests alongside the implementation.

| Test Aspect | Details |
|---|---|
<!-- e.g., | Rendering | All elements are displayed correctly | -->
<!-- e.g., | Validation | Error messages are shown for invalid input | -->

Testing library: <!-- Test tools listed in docs/project.md -->

---

## 7. E2E Test Policy (For Testers)

Testers must create the following E2E tests.

| Scenario | Expected Result |
|---|---|
<!-- e.g., | Normal operation | Expected results are displayed | -->
<!-- e.g., | Error case | Error message is displayed | -->

---

## 8. References

- Architecture: docs/architecture.md
- Data Model: docs/data-model.md
- Development Patterns: docs/development-patterns.md

---

## 9. Notes

<!-- Document known constraints, caveats, and prerequisites -->
