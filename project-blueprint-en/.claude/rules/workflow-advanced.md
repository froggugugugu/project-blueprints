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

## Core principles

- **Simplicity first**: Keep all changes as simple as possible. Minimize the scope of impact
- **No compromises**: Identify root causes. No temporary fixes. Judge by senior developer standards
- **Minimize impact**: Limit changes to only what is necessary. Do not introduce bugs
