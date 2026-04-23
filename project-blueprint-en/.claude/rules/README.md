# .claude/rules/ — Opt-in Path/Language Rule Extension Point

`.claude/rules/` is an **opt-in area for extending rules incrementally**.
In the initial state only `*.example` files exist and are not actually used in operation.

## Why this directory exists

CLAUDE.md should focus on cross-cutting project rules and stay **within ~200 lines**
(see `.claude/pitfalls.md` #1).

If you cram project-specific coding conventions and language-specific rules into CLAUDE.md:

- Matching precision drops (important rules get buried)
- Token cost increases (loaded every session)
- Maintenance becomes painful

So `.claude/rules/` provides an **incremental-rule-extension surface**.
You opt in by copying/editing `*.example` files. **CLAUDE.md is left untouched** —
extensions live here.

## Usage (3 steps)

### Step 1: Pick rules you need

Available examples:

| File | Purpose |
| ---- | ------- |
| `language-typescript.md.example` | TypeScript-specific conventions (types strategy, error handling, etc.) |
| `language-python.md.example` | Python-specific conventions (PEP compliance, type hints, exception handling) |
| `path-backend.md.example` | Path-specific rules applied to `backend/**/*` |

### Step 2: Copy to activate

```bash
# Activate TypeScript rules
cp .claude/rules/language-typescript.md.example .claude/rules/language-typescript.md

# Edit as needed
vi .claude/rules/language-typescript.md
```

### Step 3: Reference from CLAUDE.md (optional)

If you want it loaded every session, append to `CLAUDE.md`:

```markdown
@.claude/rules/language-typescript.md
@.claude/rules/path-backend.md
```

For path-specific loading (only when editing certain files), either reference from a skill
or wait for Claude Code's native path-specific rules feature.

## Naming conventions

| Prefix | Purpose | Examples |
| ------ | ------- | -------- |
| `language-*.md` | Language / framework-specific | `language-typescript.md`, `language-python.md`, `language-swift.md` |
| `path-*.md` | Rules for a specific path subtree | `path-backend.md`, `path-frontend.md`, `path-mobile.md` |
| `rule-*.md` | Topic-specific rule | `rule-accessibility.md`, `rule-performance-budget.md` |

## Concept alignment

- `.claude/rules/` is part of the generic template layer (project-specific lives in `project-config.md` or `docs/`)
- **By default** CLAUDE.md is not modified (non-destructive). Only if you want a rule loaded in every session do you optionally append an `@.claude/rules/...` reference (see Step 3 above)
- Aim for 50-100 lines per file (same rationale as CLAUDE.md — avoid bloat)
- Examples are **inactive by default** (anything with `.example` extension is not loaded)

## Notes

- Too many rules re-inflate token cost. Keep the minimum necessary
- Path-specific rules are intended to be "loaded only when editing matching paths" —
  Claude Code may support this natively in the future. Currently, `@import` from CLAUDE.md
  loads them every session
- See also `@.claude/pitfalls.md` #1 and #4
