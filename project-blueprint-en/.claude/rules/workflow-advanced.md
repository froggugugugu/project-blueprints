---
paths:
  - "src/**/*"
  - "app/**/*"
  - "lib/**/*"
  - "packages/**/*"
  - "tests/**/*"
---
# Workflow Control — Self-improvement, verification, autonomy

> **path-specific rule**: auto-loads only when Claude touches the implementation source tree

> Split out of CLAUDE.md to keep it small. It loads automatically per the frontmatter above, and skills can still reference it explicitly with `@import`.
> Plan-first / Research-first / Subagent strategy stay in CLAUDE.md proper;
> this file aggregates the "self-improvement loop and beyond" advanced guidance.

## 1. Self-improvement loop

- When receiving corrections from users, record lessons in `.claude/tasks/LESSONS_TEMPLATE.md` format
- Write your own rules to avoid repeating the same mistakes
- Iteratively improve lessons until the error rate decreases
- Review relevant project lessons at session start
- Accumulate success patterns in `.claude/learnings/` with confidence scores (the dual of `pitfalls.md`)

## 2. Pre-completion verification

- Do not mark a task complete without proving it works
- Compare diffs with the main branch as needed
- Ask yourself: "Would a senior engineer approve this?"
- Run tests, check logs, and demonstrate correctness
- For UI changes, include visual verification via Playwright MCP
- **Show evidence**: not "it should work" but the test output, the command run and its return value, or a screenshot.
  If no verification exists yet, build it first (a test / script / diff against a fixture / `/verify` against the running app)
- Tell review subagents to "report only gaps that affect correctness or the stated requirements".
  Acting on every finding of a reviewer asked to find gaps leads to over-engineering

## 3. Pursuit of elegance (balanced)

- For non-trivial changes, pause and ask "Is there a more elegant way?"
- If a fix feels hacky, "implement an elegant solution with full knowledge"
- Don't apply this to simple, obvious fixes — avoid over-engineering
- Critically review your own deliverables before submission

## 4. Autonomous bug fixing

- When receiving a bug report, fix it independently without asking for step-by-step guidance
- Identify logs, errors, and failing tests, then resolve them
- Reduce user context switches to zero
- Fix CI failures autonomously without waiting for instructions

## 5. Task management (two methods)

| Method | Purpose | Persistence |
| ------ | ------- | ----------- |
| `TaskCreate` / `TaskUpdate` | In-session work progress tracking | Session only |
| `.claude/tasks/` templates | Task specifications shared between teams | Persisted as files |

### In-session progress management

1. Create a plan: Use `TaskCreate` to add checkable items
2. Verify the plan: Check in before starting implementation
3. Track progress: Mark completed items with `TaskUpdate` as you go
4. Explain changes: Present a high-level summary at each step

### Persistent task specifications

1. Record results: Add a review section upon completion
2. Accumulate lessons: Record corrections in `.claude/tasks/LESSONS_TEMPLATE.md` format

## 6. Long-running task handoff (multiple context windows)

Based on Anthropic's long-running agent harness findings (initializer / coding agent pattern).
Don't try to build everything in one session; finish in a state **the next session can resume without guessing**.

| Failure pattern | Countermeasure |
| --------------- | -------------- |
| Trying to one-shot the work and running out of context mid-way | **One feature per session**. Pick only the highest-priority unfinished item from the feature list in `output/tasks/PROGRESS.md` |
| Intermediate state left undocumented, so the next session starts from guesses | Before finishing, **commit + update PROGRESS.md** (what was done / verification results / next step / rejected options) |
| Seeing progress and declaring the project done too early | `passes` in the feature list becomes ✅ **only after verification**. Never delete rows or rewrite acceptance criteria |
| Rediscovering how to start the app every time | Pin the start → smoke-test steps in PROGRESS.md, run them at the top of the session, and fix anything broken before starting new work |

Session start routine: `pwd` → `git log --oneline -10` → PROGRESS.md → smoke test → start one feature.
Template: `.claude/tasks/PROGRESS_TEMPLATE.md`. The SessionStart hook injects the head of PROGRESS.md automatically.
To keep going until a condition holds within one conversation use `/goal <condition>`; for recurring cross-session runs use GitHub Actions.

## Core principles

- **Simplicity first**: Keep all changes as simple as possible. Minimize the scope of impact
- **No compromises**: Identify root causes. No temporary fixes. Judge by senior developer standards
- **Minimize impact**: Limit changes to only what is necessary. Do not introduce bugs
