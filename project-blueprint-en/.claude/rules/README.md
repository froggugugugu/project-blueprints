# .claude/rules/ — path-specific and language-specific rule extensions

`.claude/rules/` is **Claude Code's official rules directory**. Every `.md` placed
here is discovered recursively and loaded into context with the same priority as
`CLAUDE.md`.

## Two kinds of rules

| Kind | Frontmatter | When it loads | Use for |
| ---- | ----------- | ------------- | ------- |
| **always-on** | none | at launch, every session | short rules that must always apply (e.g. commit conventions) |
| **path-specific** | has `paths:` | only when Claude touches a matching file | language- or layer-specific detail rules |

> **Important**: a rule without `paths:` **loads in every session**.
> Splitting content out of CLAUDE.md alone does not save context, so always add
> `paths:` to any rule that is not universally applicable.

### Writing a path-specific rule

```markdown
---
paths:
  - "src/api/**/*.ts"
  - "src/**/*.{ts,tsx}"
---

# API Development Rules

- All API endpoints must include input validation
- Use the standard error response format
```

`paths` takes globs, including brace expansion (`{ts,tsx}`).

| Pattern | Matches |
| ------- | ------- |
| `**/*.ts` | All TypeScript files in any directory |
| `src/**/*` | Everything under `src/` |
| `*.md` | Markdown files in the project root |
| `src/components/*.tsx` | Components in a specific directory |

## Bundled rules

| File | Kind | Scope |
| ---- | ---- | ----- |
| `git-conventions.md` | always-on | every session (a commit can happen at any time) |
| `document-management.md` | path-specific | `docs/**` `output/**` `input/**` `project-config.md` |
| `workflow-advanced.md` | path-specific | `src/**` `app/**` `lib/**` `packages/**` `tests/**` |
| `language-typescript.md.example` | path-specific (sample) | `**/*.{ts,tsx}` |
| `language-python.md.example` | path-specific (sample) | `**/*.py` |
| `path-backend.md.example` | path-specific (sample) | `backend/**/*` |

## Enabling a sample (2 steps)

```bash
# 1. Copy without the .example suffix
cp .claude/rules/language-typescript.md.example .claude/rules/language-typescript.md

# 2. Edit `paths:` and the body to match your project
vi .claude/rules/language-typescript.md
```

No `CLAUDE.md` edit is needed — the rule loads automatically when `paths:` matches.

## Naming conventions

| Prefix | Purpose | Examples |
| ------ | ------- | -------- |
| `language-*.md` | Per language / framework | `language-typescript.md`, `language-python.md`, `language-swift.md` |
| `path-*.md` | Rules for a specific path | `path-backend.md`, `path-frontend.md`, `path-mobile.md` |
| `rule-*.md` | Rules for a specific technical topic | `rule-accessibility.md`, `rule-performance-budget.md` |

Subdirectories (`frontend/`, `backend/`, …) are discovered recursively.
Symlinks are resolved too, so a shared rule set can be linked into many projects:

```bash
ln -s ~/shared-claude-rules .claude/rules/shared
```

## Rules vs. skills

| | `.claude/rules/` | `.claude/skills/` |
| --- | --- | --- |
| Load trigger | at launch or on path match (passive) | on invocation or description match (active) |
| Good for | "constraints that always hold" | "procedures for a specific job" |
| Cost | consumes context always or often | consumes context only when invoked |

Task-specific procedures belong in a skill, not in a rule (official guidance).

## Large repositories and monorepos

| Problem | Official answer |
| ------- | --------------- |
| Package-specific procedures show up while working on other packages | **Per-directory skills**: put them in `packages/<name>/.claude/skills/`. They are candidates only while that directory is touched, and a name clash is namespaced automatically as `/packages/<name>:skill` |
| Where a convention belongs | Conventions maintained by the directory owner go in `packages/<name>/CLAUDE.md` (loaded when Claude reads a file there). A rule that must apply to scattered paths goes in this directory as a path-scoped rule |
| Other teams' CLAUDE.md files get loaded | `claudeMdExcludes` in `.claude/settings.local.json` (globs over absolute paths) |
| Worktrees are heavy | `worktree.sparsePaths` checks out only the directories you need |
| Generated or vendored code gets read | Add `Read(./dist/**)` and similar to `permissions.deny` to cut exploration cost |
| Skill descriptions get truncated as skills multiply | Check the listing cost with `/doctor`, hide unneeded skills via `skillOverrides`, adjust the budget with `skillListingBudgetFraction` |

Keep the root `CLAUDE.md` to cross-cutting rules only; never pull package-specific information into it (pitfalls #1).

## Concept alignment

- `.claude/rules/` is part of the generic template layer (project-specific values go in `project-config.md` or `docs/`)
- Keep each rule file to roughly 50–100 lines, for the same reason CLAUDE.md is capped
- Samples are **inactive** by default (nothing with a `.example` suffix is read)
- Too many rules inflate token cost again: keep always-on rules minimal and scope the rest with `paths:`
- See `@.claude/pitfalls.md` #1 and #4 for details
