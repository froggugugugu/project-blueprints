# Document Management Policy

> Imported by `CLAUDE.md` to prevent CLAUDE.md bloat. Cross-cutting rule reference.

## Human-managed files

- `project-config.md` — tech stack, quality standards, policies (human decisions)
- `constitution.md` (repo root) — 7 inviolable principles
- `input/requirements/` — requirement notes (AI is read-only here)

## AI-managed files

The following files are generated and maintained by AI:

- `docs/project.md` — routing, store list, commands, tech stack
- `docs/architecture.md` — directory structure, test list
- `docs/data-model.md` — schema definitions, validation rules
- `docs/development-patterns.md` — code conventions, pitfalls, design system
- Everything under `output/` and `testreport/`

## AI maintenance of project-config.md

Each skill updates the following sections as design and implementation progress:

| Update Trigger | Target Section |
| -------------- | -------------- |
| New pitfalls or anti-patterns discovered | §11 (Known Pitfalls) |
| Dependency package additions or version changes | §2 (Tech Stack) |
| Command additions or changes | §3 (Commands) |

Always maintain consistency between `project-config.md` and `docs/`.

## Conflict prevention for project-config.md updates

| Section | Primary Update Responsibility | Rule |
| ------- | ----------------------------- | ---- |
| §2 (Tech Stack) | `/implementing-features` | Other skills report findings; the primary updater consolidates |
| §3 (Commands) | `/implementing-features` | Same as above |
| §4 (Architecture) | `/implementing-features` | `/architecture` outputs to `output/design/`. Reflected after adoption |
| §11 (Known Pitfalls) | All skills (append allowed) | Check for duplicate entries before appending |

## Conflict prevention for docs/ updates

| File | Primary Update Responsibility | Rule |
| ---- | ----------------------------- | ---- |
| `docs/project.md` | `/implementing-features` | When routing, stores, or commands change |
| `docs/architecture.md` | `/implementing-features` | When directory structure or test placement changes. `/architecture` outputs to `output/design/`, reflected after adoption |
| `docs/data-model.md` | `/implementing-features` | When schemas are added or changed |
| `docs/development-patterns.md` | `/implementing-features` | When code conventions, pitfalls, or design system change. Other skills (`/performance`, `/refactoring`, etc.) report findings; the primary updater consolidates |

In a team context, the PL centrally manages `project-config.md` and `docs/` updates. Members report findings to the PL, who performs the updates. Only appending to §11 can be done directly by members (with duplicate check).
