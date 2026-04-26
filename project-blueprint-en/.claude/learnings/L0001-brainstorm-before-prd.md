---
id: L0001
topic: Always run /brainstorm before /prd when the requirement note is vague
confidence: 0.85
sample_size: 4
first_seen: 2026-04-15
last_confirmed: 2026-04-27
status: active
related: [P19]
---

# L0001 — Always run /brainstorm before /prd when the requirement note is vague

## Context

When the user drops a short requirement note (a few lines to half a page) into
`input/requirements/REQ_*.md` and asks "create the PRD". The note typically
omits success criteria, what's *not* in scope, and the target user. If the AI
runs `/prd` directly, the resulting PRD is inflated with guesswork, causing
multiple rework cycles in the design phase.

## Observed success pattern

- **input**: A requirement note under half a page, or an abstract one-line wish
- **decision**: Don't run `/prd` directly. Run `/brainstorm <note>` first to extract
  motivation / users / success criteria / out-of-scope / exit conditions / constraints /
  alternatives via Socratic questions in 3 rounds or fewer. Then proceed to PRD using
  `output/brainstorm/BRAINSTORM_<topic>_<date>.md` as the seed.
- **outcome**: PRD authoring time grows slightly (+10-15 min), but design-review
  rework cycles drop from ~3 to 0-1. Phase 2 (design gate) pass rate roughly doubles.

## Why it works

A PRD is "a set of requirements", but extracting requirements requires prior **agreement
on premises**. `/brainstorm` deliberately bans code and document writing, removing the
AI's temptation to fill gaps with guesses and forcing the user to articulate. This is
the same pattern adopted by spec-kit's `/clarify` phase, BMAD's analyst persona, and
superpowers' brainstorming skill — confirmed across multiple top-OSS projects.

## Applicability

**When to apply (must)**:

- Requirement note under half a page
- No "what we won't do" section in the note
- Stakeholders / success metrics undefined
- Large feature additions spanning multiple skills

**When *not* to apply (must not)**:

- Bug fixes (run `/implementing-features` directly)
- Refactoring (run `/refactoring` directly)
- Trivial UI tweaks (run `/ui-ux-design` directly)
- Note already at full PRD-level detail (rework risk for `/prd` is low)

**Related skills / phases**:

- Upstream: none (top of the PRD pipeline)
- Downstream: `/prd` → `/architecture` → `/plan` → `/implementing-features`
- Parallel: Once design judgments emerge, capture in `/adr`

## Counter-examples

- 1 case: For a 3-page complete spec, inserting `/brainstorm` was flagged by the user
  as "rehashing already-agreed items". → Added the "note under half a page" applicability
  condition to avoid this case.

## Revision history

| Date | Change | Confidence delta |
| ---- | ------ | ---------------- |
| 2026-04-15 | Initial registration (2 cases observed) | — (0.50) |
| 2026-04-22 | 3rd case reproduced, PRD-rework reduction confirmed | 0.50 → 0.65 |
| 2026-04-27 | 4th case; `/brainstorm` skill shipped in this template | 0.65 → 0.85 |
