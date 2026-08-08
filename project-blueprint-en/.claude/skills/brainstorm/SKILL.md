---
name: brainstorm
description: Socratic clarification skill that surfaces assumptions before `/prd`. Triggers: brainstorm, surface-assumptions, clarify, ambiguity-check, pre-prd, what-am-i-missing. Read-only; output to `output/brainstorm/` only.
allowed-tools: Read, Grep, Glob, Write, AskUserQuestion
argument-hint: <requirement-note path, or topic to clarify>
context: fork
---

# `/brainstorm` — Pre-`/prd` Socratic clarification

## Prerequisites

- A requirement note exists in `input/requirements/<file>.md`, or a one-line topic can be passed in interactively
- Write permission for `output/brainstorm/` is granted (in `settings.local.json`)
- `/prd` has not yet been started (this skill is **upstream** of `/prd`)
- Applicability: any of — the note is under half a page / the "what we won't do" is unclear /
  stakeholders or success metrics are undefined
  (reference: `@.claude/learnings/L0001-brainstorm-before-prd.md`)

## Principles

- **Question-driven**: never inflate features by guessing. Surface ambiguity via `AskUserQuestion`
- **No code or production-doc changes**: this skill's charter is *structuring assumptions* only
- **Socratic pacing**: max 4 questions per round, max 3 rounds (avoid user fatigue)

## Usage

### Examples

```text
/brainstorm input/requirements/REQ_subscription.md
/brainstorm Add a subscription feature (one-liner)
```

### Output destination

- `output/brainstorm/BRAINSTORM_<topic>_<YYYY-MM-DD>.md` only
- No writes to other directories

### Integration with Other Skills

- Downstream (required): `/prd <output-file>` — build the formal PRD off the seed
- Parallel (optional): `/adr <title>` — record significant design judgments as they emerge
- Upstream: none (this is the top of the PRD pipeline)

## Workflow

1. **Read input**: read the requirement note. Or ask for a 1-2 sentence seed interactively
2. **Socratic question salvo** (`AskUserQuestion`, max 4 per round, max 3 rounds):
   - Motivation (Why now? Would the same value hold one month from now?)
   - Users (Who is the primary persona? Niche cases?)
   - Success (What does post-launch success look like? Which metrics?)
   - Out-of-scope (What are we deliberately *not* doing? Why?)
   - Exit (How do we roll back if it fails? Data implications?)
   - Constraints (Which legal / security / SLA constraints can't be relaxed?)
   - Alternatives (Could the same value be delivered differently?)
3. **Surface implicit assumptions**: mark with `[Assumption]`
4. **Propose 3 scope variants**: Minimum / Standard / Ambitious
5. **List open questions**: star (★) the ones that must resolve before `/prd`
6. **Save**: write to `output/brainstorm/` and present to the user
7. **Gate decision**: ask whether to proceed to `/prd` (see "Gates" below)

## Output Contract

`output/brainstorm/BRAINSTORM_<topic>_<YYYY-MM-DD>.md` must contain these sections:

```markdown
## 1. Core request (one sentence)
## 2. Assumption inventory (explicit + implicit)
## 3. Stakeholders and stakes (who expects what, who fears what)
## 4. In-scope / out-of-scope candidates (3+ proposals)
## 5. Open-question list (★-prioritized)
## 6. Next step (Are we ready to run `/prd`?)
```

## Prohibitions

- **No code, test, or production-doc changes** (`docs/`, `src/`, `tests/` off-limits)
- **No requirement inflation**: never add features the input didn't request
- **No write outside `output/brainstorm/`**
- **No question fatigue**: max 4 questions per round; max 3 rounds total
- **No secret transcription**: redact discovered API keys, etc., as `[REDACTED]`

## Gates

- **Gate 1**: At end of brainstorm, ask "Ready to proceed to `/prd`?"
- **Gate 2**: If 3+ ★-marked open questions remain, hold off on transitioning to `/prd`
  (only pass through if the user explicitly says "proceed")

## Socratic question templates

| Category | Example |
| -------- | ------- |
| Motivation | Why now? Would the same value hold one month from now? |
| Users | Who is the primary persona? Which niche cases exist? |
| Success | What does post-launch success look like? What metrics? |
| Out-of-scope | What are we deliberately *not* doing? Why? |
| Exit | If this fails, how do we roll back? Data implications? |
| Constraints | Which legal / security / SLA constraints can't be relaxed? |
| Alternatives | Could the same value be delivered differently? |
