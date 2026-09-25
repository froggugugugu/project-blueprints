# Review instructions (for Claude's Code Review)

The criteria Claude's Code Review (the GitHub App) applies to pull requests in this repository. `CLAUDE.md` is the shared
context for all work; this file is review-only. The local `/code-review` and the CI `claude -p '/code-review'` do not read
this file, so a rule that must hold in both places belongs in `.claude/skills/code-review/SKILL.md`. Length dilutes it, so
keep only rules that change review behavior.

## What Important means here

Reserve Important (🔴) for: logic errors that break behavior / data leaks (PII or secrets in logs or error messages) /
migrations that cannot be rolled back / queries that cross a tenant boundary / unmet acceptance criteria.
Naming, formatting and refactoring suggestions are Nit (🟡) at most. Important corresponds to MUST in this template's `/code-review`.

## Cap the nits

Report at most five Nits per review. Mention the rest as "plus N similar items" in the summary. If there is no Important, lead the summary with "No blocking issues".

## Do not report

- Anything CI already enforces: lint, formatting, type errors
- Generated files, lockfiles and vendored dependencies (`dist/`, `*.lock`, `vendor/`)
- AI-generated areas: `output/`, `testreport/`, `docs/` (their correctness is judged in the implementation review)
- Test-only code that intentionally violates production rules

## Always check

- New API routes / commands have an integration test
- Log lines and error messages contain no email addresses, user IDs or request bodies
- `docs/` and `project-config.md` §2 / §3 were updated to follow the implementation change (document management in `AGENTS.md`)
- No use of `--no-verify` or `--force`, and no `.env` / private key committed
- No violation of the dependency direction between layers (`project-config.md` §4.4)

## Verification bar

Behavior claims need a `file:line` citation. An inference from naming is a Nit at most.

## Re-review convergence

From the second review of the same PR on, suppress new Nits and post Important findings only.

## Summary shape

Open with one line such as "Important N / Nit M", and lead with "No blocking issues" when there is no Important.
