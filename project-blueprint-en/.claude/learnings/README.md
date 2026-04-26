# `.claude/learnings/` — Success-pattern accumulation (the dual of `pitfalls.md`)

While `pitfalls.md` is a **failure-pattern catalog**, `learnings/` is a **success-pattern catalog**.
This is a "continuous learning" layer inspired by ECC (everything-claude-code)'s instinct mechanism.

## Why we need this

`pitfalls.md` alone only conveys "what *not* to do". Without a record of "what
**worked**", AI becomes overly conservative and asks for confirmation on judgments
that have already been validated.

By accumulating success patterns with confidence scores, future sessions
hitting the same decision point can **reference them automatically**.

## File structure

```text
.claude/learnings/
├── README.md           # this file
├── TEMPLATE.md         # template for new learnings
└── L<NNNN>-<topic>.md  # individual learnings (sequentially numbered)
```

Each learning is Markdown with frontmatter:

```yaml
---
id: L0001
topic: <short subject>
confidence: 0.85         # 0.0-1.0 (reproducibility)
sample_size: 3           # number of observed cases
first_seen: 2026-04-01
last_confirmed: 2026-04-23
status: active           # active | deprecated | superseded
related: [L0002, P12]    # links to other learnings (L) / pitfalls (P)
---
```

## Operating rules

### When to add

- The user gave positive feedback like "**yes, that approach was right**"
- The same decision pattern recurred **3+ times** (across sessions)
- A specific tactic for avoiding a pitfall pattern was identified

### When *not* to add

- Obvious things (readable from code)
- Observed only once (sample_size=1) — likely coincidence
- User-specific preferences (those go to `feedback` memory)

### Confidence updates

- Applied → succeeded → bump confidence by +0.05 (cap 0.95)
- Applied → failed → drop confidence by -0.20, move toward `status: deprecated`
- No `last_confirmed` update for 6+ months → drop to `status: stale`

## Role split with CLAUDE.md / pitfalls

| Type | What goes here | Update freq | Location |
| ---- | -------------- | ----------- | -------- |
| CLAUDE.md | Cross-cutting rules (must) | low | `.claude/CLAUDE.md` |
| pitfalls.md | Failure patterns (avoid) | medium | `.claude/pitfalls.md` |
| learnings/ | Success patterns (reuse) | high | `.claude/learnings/L*.md` |
| auto memory | User-specific facts/preferences | high | `~/.claude/projects/<proj>/memory/` |

## Auto-reference

- Each skill should instruct: "Reference relevant learning if available" (skill-side `@` import only when needed)
- Don't read everything at session start (avoid bloat)
- Treat only `confidence >= 0.8` entries as "strong reference"

## Related

- `@.claude/pitfalls.md` — failure patterns
- `~/.claude/projects/<proj>/memory/` — Claude Code Auto Memory
- `@.claude/CLAUDE.md` — cross-cutting rules
