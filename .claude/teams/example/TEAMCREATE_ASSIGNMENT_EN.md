# TEAMCREATE

> **Purpose**: Copy this file for each feature and save as `TEAMCREATE_<feature-name>.md`
> **Team Structure**: 4 roles — PL (Project Lead), Developer, Reviewer, Tester
> **Target**: React / Next.js frontend applications
> **Sample instruction using this file**: Read .claude/teams/TEAMCREATE_ASSIGNMENT_EN.md and follow all instructions in that file. Create the agent team as specified, use delegate mode, and require plan approval before any changes.

---
## 1. Team Structure

| Role | Responsibilities | Model |
|---|---|---|
| **PL (Project Lead)** | Ensures overall feature consistency, coordinates with other features, approves plans. Does NOT implement code (delegate mode). | Opus (Lead) |
| **Developer** | Implements the feature + writes unit tests | Sonnet |
| **Reviewer** | Reviews code quality, design principles, and coding standards compliance | Sonnet |
| **Tester** | Creates and runs integration tests + Playwright E2E tests | Sonnet |

## 2. Task Dependencies

```
Developer: Read the TASK md and implement + write unit tests
    ↓ (implementation complete)
Reviewer: Conduct code review, send feedback to Developer
    ↓ (review approved)
Tester: Create and run integration tests + Playwright E2E tests
    ↓ (tests complete)
PL: Final review, cross-feature consistency check, completion judgment
```

## 3. Instructions for Claude

Paste the following into Claude Code and execute.

**Instructions**

```
Create an agent team for [assignment] feature.
Require plan approval before making any changes.
Operate in delegate mode — you are the PL. Do NOT implement code yourself.

Spawn 3 teammates:

- Developer:
  Read .claude/tasks/TASK03_EN.md and implement according to that specification.
  Write unit tests alongside the implementation.
  Scope of work: / only.
  Use React Testing Library + vitest for unit tests.
  Require plan approval before making any changes.

- Reviewer:
  Wait for the Developer to complete implementation.
  Review all of the Developer's changes from the following perspectives:
    - Code quality and readability
    - Compliance with CLAUDE.md coding standards
    - Component design (proper separation, reusability)
    - Accessibility (a11y) considerations
    - Performance concerns (unnecessary re-renders, missing memoization)
  Send specific, actionable feedback to the Developer.
  Do NOT modify any source code.

- Tester:
  Wait until the Reviewer has approved the Developer's code.
  Read .claude/tasks/TASK03_EN.md to understand the expected behavior.
  Create integration tests and Playwright E2E tests in [e2e/assignment].
  Coverage: happy paths, error cases, edge cases, responsive behavior.
  Run all tests and report results to the PL.
  Do NOT modify source code — only create/modify test files.

Task dependencies:
1. Developer completes implementation → Reviewer begins review
2. Reviewer approves → Tester begins testing
3. Tester completes → PL performs final review

PL responsibilities (you):
- Review and approve or reject each teammate's plan
- Ensure consistency with other features and overall app architecture
- Do NOT approve any Developer plan that does not include unit tests
- Do NOT mark the feature as complete until all tests pass
```

## 4. Completion Criteria

- [ ] Developer: Implementation complete + all unit tests pass
- [ ] Reviewer: Review complete + all issues resolved
- [ ] Tester: Integration tests + E2E tests all pass
- [ ] PL: Cross-feature consistency check complete

## 5. Notes

- There are existing features for requirements management, WBS editing, WBS settings, master schedule, phase settings, and member management. Take care to maintain full data consistency with these features.
