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

| Kind | What goes in it | Update frequency | Location | git |
| ---- | --------------- | ---------------- | -------- | --- |
| CLAUDE.md | Cross-cutting rules (must) | Low | `.claude/CLAUDE.md` | ✅ committed |
| pitfalls.md | Failure patterns (to avoid) | Medium | `.claude/pitfalls.md` | ✅ committed |
| learnings/ | Success patterns (to reuse) | High | `.claude/learnings/L*.md` | ✅ committed |
| auto memory | One person's working context | High | `~/.claude/projects/<proj>/memory/` | ❌ **never committed** |

## How this relates to auto memory

Claude Code has **auto memory** built in (on by default). `learnings/` does not replace
it — it complements it. The decisive difference is whether it enters git:

- **`learnings/` is a team asset**. It is committed, reviewed, and shared. Use it when
  "this approach worked on this project" should apply to **everyone**
- **auto memory is one person's working context**. It lives under `~/.claude/`, is never
  committed, is written autonomously by Claude, and is shared with nobody

The four kinds auto memory records (official):

| type | Content |
| ---- | ------- |
| `user` | Role, expertise, working preferences |
| `feedback` | Corrections you gave, and approaches you confirmed |
| `project` | Ongoing work, deadlines, decisions not derivable from code or git history |
| `reference` | Pointers to external resources (issue tracker, dashboards) |

Auto memory skips anything derivable from the codebase (architecture, file paths, past
fixes) and anything the CLAUDE.md files already say.

### Deciding where something goes

| Content | Where |
| ------- | ----- |
| A technical decision confirmed reproducible (sample_size ≥ 3) | `learnings/` |
| An approach the team agreed on | `learnings/` or `CLAUDE.md` |
| "This person writes strict TypeScript types" | auto memory (`user`) |
| "This person always wants tests before a commit" | auto memory (`feedback`) |
| "This feature ships by Q3" | auto memory (`project`) |

### Settings

```json
// .claude/settings.json (to disable per project)
{ "autoMemoryEnabled": false }

// To relocate storage (absolute path, or starting with ~/)
{ "autoMemoryDirectory": "~/my-memory-dir" }
```

In CI, set `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` so runs stay reproducible (the bundled
`claude-skills-ci.yml.template` already does).

> **Caution**: auto memory accumulates across sessions, but each note is a
> **point-in-time snapshot**. If a note names a file, function, or flag, verify it still
> exists before acting on it.

## Auto-reference

- Each skill should instruct: "Reference relevant learning if available" (skill-side `@` import only when needed)
- Don't read everything at session start (avoid bloat)
- Treat only `confidence >= 0.8` entries as "strong reference"

## Related

- `@.claude/pitfalls.md` — failure patterns
- `~/.claude/projects/<proj>/memory/` — Claude Code Auto Memory
- `@.claude/CLAUDE.md` — cross-cutting rules
