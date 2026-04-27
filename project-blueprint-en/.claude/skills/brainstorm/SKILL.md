---
name: brainstorm
description: Socratic clarification skill that surfaces assumptions before `/prd`. Read-only; output to `output/brainstorm/` only.
allowed-tools: Read, Grep, Glob, Write, AskUserQuestion
argument-hint: <requirement-note path, or topic to clarify>
disable-model-invocation: false
triggers: brainstorm, surface-assumptions, clarify, ambiguity-check, pre-prd, what-am-i-missing
---

# `/brainstorm` — Pre-`/prd` Socratic clarification

## When to use

Before running `/prd`, when you want to **structure the assumptions and ambiguities**
in a requirement note. A short cushion that dramatically reduces later rework.

## Input

- **A requirement-note path** (`input/requirements/foo.md`, etc.)
- Or **a one-line topic** ("Add a subscription feature")

## Output

Saved to `output/brainstorm/BRAINSTORM_<topic>_<date>.md`:

```markdown
## 1. Core request (one sentence)
## 2. Assumption inventory (explicit + implicit)
## 3. Stakeholders and stakes (who expects what, who fears what)
## 4. In-scope / out-of-scope candidates (3+ proposals)
## 5. Open-question list (prioritized)
## 6. Next step (Are we ready to run `/prd`?)
```

## Workflow

1. **Read input** — note file, or ask for a 1-2 sentence seed
2. **Socratic question salvo** (AskUserQuestion, 1-4 per round, max 3 rounds)
   - "Who is this for?" "What does success look like?" "Why now?"
   - "What's the option of *not* doing this?" "Exit strategy if it fails?"
3. **Surface implicit assumptions** — mark with `[Assumption]`
4. **Propose 3 scope variants** — Minimum / Standard / Ambitious
5. **List open questions** — star (★) the ones that must resolve before `/prd`
6. **Save** to `output/brainstorm/` and present to the user

## Constraints

- **No code, test, or production-doc changes** (`docs/`, `src/`, `tests/` off-limits)
- **No requirement inflation** — never add features the input didn't request
- **Output destination is `output/brainstorm/` only** — no other writes
- **Max 4 questions per round** — don't exhaust the user
- **3 rounds is a hard cap** — beyond that, move to `/prd`

## Related skills

- After clarification: `/prd <output-file>` for the formal PRD
- For decisions with significant design impact: `/adr <title>` in parallel
- For threat modeling at design time: `planner` agent + `security-reviewer` combo

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

## Gates

- **Gate 1**: At end of brainstorm, ask "Ready to proceed to `/prd`?"
- **Gate 2**: If 3+ open questions remain, hold off on transitioning to `/prd`
