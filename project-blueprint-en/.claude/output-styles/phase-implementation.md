---
name: phase-implementation
keep-coding-instructions: true
description: Implementation phase. Optimized for TDD, minimal diffs, and verification-first behavior.
---

# Output Style: Implementation Phase

Use this style when running `/implementing-features`, `/refactoring`, or any task that writes code.
**Always test before writing**; always verify after.

## Behavioral Principles

1. **Red-Green-Refactor** — Failing test → passing code → refactor. Strict order.
2. **Minimal diff** — One commit, one responsibility. Don't smuggle in unrelated improvements.
3. **Verify first** — After changes, always run tests, type-check, and lint, then show the logs.
4. **Respect existing patterns** — Use Glob/Grep to find similar implementations and conform.
5. **Dry-run thinking** — Before changing anything, predict in 1-2 lines what will happen.
6. **Zero dependency-direction violations** — Honor the rules in `project-config.md` §4.4.
7. **Sync docs** — Update `docs/` to reflect implementation changes.

## Output Format

- Split code changes into short sections; each reports as Goal → Diff → Verification.
- Always show test results (pass/fail counts + log excerpt).
- Show before/after for coverage, lint warnings, type errors.
- Mark unresolved TODOs explicitly or move them to follow-up tasks.

> **N/A allowance**: If test infrastructure / coverage / type-checking / lint is not yet
> set up for the project (or not enabled in `project-config.md`), report the item as
> **"N/A + reason + next action"** instead. Example: "Coverage: N/A (vitest not installed,
> no coverage target in §6). Next: enable after §6 configured." Truthful reporting beats
> fabricated numbers.

## Forbidden

- Use of `--no-verify`.
- "Greening" by skipping or deleting failing tests.
- Leftover debug statements (language-specific: JS `console.log`, Python `print` /
  `logger.debug`, Go `fmt.Println`, Rust `dbg!` / `println!`, Ruby `puts` / `pp`,
  Swift `print`).
- Bypassing hooks to force a commit.
- Adding/removing fields by guessing.

## Expected Follow-up

- After implementation, self-review with `/code-review`.
- If E2E coverage is needed, invoke `/e2e-testing`.
- For perf-sensitive changes, invoke `/performance`.
