---
name: e2e-testing
description: >
  Creates and maintains Playwright E2E tests for SPAs.
  Triggers: E2E test, scenario test, user flow, cross-feature, Playwright.
  Covers: Page Object design, test data management, stability patterns, and reporting.
  Takes optional argument: /e2e-testing <target-feature or instruction>
---

# E2E Testing

A skill for implementing E2E tests with Playwright. Automates key user-perspective scenarios to prevent regressions.
For project-specific scenarios, Page Objects, and test data, refer to [docs/development-patterns.md](../../../docs/development-patterns.md).

## Prerequisites

| Reference File | Purpose | Fallback When Stub |
| -------------- | ------- | ------------------ |
| `docs/project.md` | Test commands, tech stack | Refer directly to `project-config.md` §3, §8 |
| `docs/development-patterns.md` | E2E patterns, test data | Refer directly to `project-config.md` §8, §11 |

## Test Target Policy

E2E tests verify **user interaction flows that span multiple screens**.

- ✅ Targets: Page navigation, form interaction → result verification, cross-feature coordination, data persistence (retained after reload)
- ❌ Not targets: Individual validation rules (unit tests), component rendering details (component tests), third-party library internals

## Usage

```text
/e2e-testing <target-feature or test instruction>
```

Arguments are optional. When omitted, confirm interactively with the user.
When a file path is specified, design E2E test scenarios for that feature.

### Examples

```text
/e2e-testing Test the entire assignment management flow
/e2e-testing src/features/assignment/
/e2e-testing output/tasks/TASK_e2e_assignment.md
```

### Output Destination

- Test code: Under `e2e/`
- Tool output: `testreport/e2e/` (Playwright reports and traces)
- Summary output: `output/reports/test/` (when `output/` directory exists)

### Integration with Other Skills

| Previous Step | This Skill | Next Step |
| ------------- | ---------- | --------- |
| `/implementing-features` `/ui-ux-design` | `/e2e-testing` | `/code-review` |

## Implementation Workflow

1. **Scenario Definition** — Clarify what to verify (reference scenario list in [docs/development-patterns.md](../../../docs/development-patterns.md))
2. **Test Data Preparation** — Inject data using helper functions (see [docs/development-patterns.md](../../../docs/development-patterns.md))
3. **Write Operations via Page Objects** — Test body focuses on "what to verify"
4. **Execute & Verify** — Run E2E test command (see `docs/project.md`)
5. **Report Output** — Output test report to `testreport/e2e/` and present. Also present trace review commands

## File Layout

```
e2e/
├── <feature>.spec.ts         # Test file (per feature)
├── fixtures/
│   └── test-data.ts          # Test data generation helpers
└── pages/
    ├── BasePage.ts            # Common operations (navigation, dialogs, toasts)
    └── <Feature>Page.ts       # Feature-specific Page Object
```

## Locator Strategy (Priority Order)

1. `getByRole` — Accessibility-based (most stable)
2. `getByLabel` — Form elements
3. `getByText` — Displayed text
4. `getByTestId` — When the above are difficult
5. CSS selectors — Last resort for complex UI components

## Stability Rules

- Leverage Playwright's auto-waiting (assertions like `expect(...).toBeVisible()`)
- **`waitForTimeout` is prohibited** (causes flaky tests)
- Each test initializes data in `beforeEach` (no dependency on test execution order)
- After page navigation, stabilize with `waitForLoadState('networkidle')`

## Page Object Design Principles

- **BasePage** consolidates common operations (navigation, dialog open/close, toast verification)
- **Feature-specific Pages** extend BasePage and add screen-specific operations
- Test bodies call only Page Object methods (avoid direct locator operations)

## Test Commands

Test commands are documented in `docs/project.md`. Common patterns:

```bash
npm run e2e                    # All E2E tests
npm run e2e:ui                 # UI mode (for debugging)
npx playwright test e2e/<file> # Specific file
npx playwright test --grep "<test name>" # Filter by test name
npx playwright show-report --reporter-dir testreport/e2e  # Show report
```

## Report Output Configuration

Configure the Playwright config file (`playwright.config.ts`) to output reports to `testreport/e2e/`:

```typescript
// playwright.config.ts
export default defineConfig({
  reporter: [
    ['html', { outputFolder: 'testreport/e2e', open: 'never' }],
  ],
  outputDir: 'testreport/e2e/results',
})
```

## Output Contract

### Test Implementation Output Specification

| Field | Type | Required | Constraints |
| ----- | ---- | -------- | ----------- |
| Scenario Definition | Bullet points | ✅ | Describe user flows to verify in natural language |
| Test Code | TypeScript file | ✅ | Place under `e2e/` |
| Page Object | TypeScript file | Conditional | When new screen operations are needed |
| Test Data | TypeScript function | Conditional | When new data patterns are needed |
| Execution Results | Table | ✅ | Test name, Result (pass/fail), Execution time |

### Test Code Structure Constraints

```typescript
// Required structure
test.describe('[Feature Name]', () => {
  test.beforeEach(async ({ page }) => {
    // Data initialization
    // Page navigation
  })

  test('[Scenario description in English]', async ({ page }) => {
    // Arrange: Initial operations via Page Object
    // Act: Test target operations
    // Assert: Expected result verification
  })
})
```

- `test.describe` / `test` description text in English
- `waitForTimeout` usage is prohibited (use assertion-based waiting instead)
- Locator priority: `getByRole` > `getByLabel` > `getByText` > `getByTestId` > CSS

### Execution Results Report Format

```markdown
## E2E Test Results

| Test | Result | Execution Time |
| ---- | ------ | -------------- |
| [Scenario name] | pass / fail | Xs |

- Total: X pass / Y fail
- Report: `testreport/e2e/index.html`
- Trace review: `npx playwright show-report testreport/e2e`
```

### Vocabulary Constraints

| Term | Definition |
| ---- | ---------- |
| Scenario | A user-perspective interaction flow (a series of operations spanning screens) |
| Page Object | A class that abstracts screen operations, hiding locator details |
| Flaky | An unstable test whose results change between runs |
| Seed Data | Initial data injected for testing |

## Checklist

- [ ] Each test is independent (data initialized in beforeEach)
- [ ] Operations abstracted via Page Objects
- [ ] No `waitForTimeout` usage
- [ ] Locators are Role/Label/Text-based
- [ ] Data persistence test (after reload) exists
- [ ] Cross-feature scenarios exist
- [ ] E2E tests pass stably
