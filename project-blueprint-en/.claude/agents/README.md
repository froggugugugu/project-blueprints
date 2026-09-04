# Claude Code Subagents — Selection Guide

`.claude/agents/` is a collection of subagent definitions for **delegating single-shot tasks to specialists**.
Claude Code parses each agent's `description` field for auto-invocation.
To invoke explicitly, use the `Agent` tool with `subagent_type: <name>`.

## Agent list

| Agent | Purpose | model | effort | Tools | Write access |
| ----- | ------- | ----- | ------ | ----- | ------------ |
| `explorer` | Broad in-repo codebase exploration | `haiku` | low | Read / Grep / Glob | None |
| `researcher` | External technical investigation (official docs, standards) | `sonnet` | medium | Read / Grep / Glob / WebSearch / WebFetch / Context7 | None |
| `planner` | Pre-implementation design planning | `sonnet` | high | Read / Grep / Glob | None |
| `security-reviewer` | OWASP-aligned security audit | `opus` | high | Read / Grep / Glob | None |
| `performance-analyst` | Measurement-first bottleneck analysis | `sonnet` | high | Read / Grep / Glob / Bash | None |
| `doc-synchronizer` | Sync updates to **existing** files under `docs/` | `haiku` | low | Read / Edit / Write / Grep / Glob | `docs/` only |
| `doc-writer` | Author **new** documents under `output/` | `sonnet` | medium | Read / Edit / Write / Grep / Glob | `output/` only |
| `test-writer` | Unit and E2E test creation | `sonnet` | medium | Read / Edit / Write / Grep / Glob / Bash | Test files only |

Every agent also sets `memory: project` and `maxTurns` (runaway protection plus cross-session learning).

## agent vs team vs skill — when to use which

| Goal | Choice | Rationale |
| ---- | ------ | --------- |
| Routine collaborative work across roles (PRD → design → impl → verify) | **team** (`.claude/teams/TEAM_*.md`) | Pre-wired role assignments and approval gates |
| Execute a predetermined procedure (PRD generation, code review, etc.) | **skill** (`.claude/skills/*/SKILL.md`) | Defined I/O contracts and output locations |
| One-off specialized investigation or review (avoid reinventing wheels) | **agent** (`.claude/agents/*.md`) | Isolated context, lightweight execution |

These three complement rather than compete. For example, a `TEAM_PJM` Reviewer can delegate to `security-reviewer` for a focused audit.

## Auto-invocation vs explicit invocation

- **Auto-invocation**: Claude Code matches the parent prompt against each agent's `description` and delegates implicitly
- **Explicit invocation**: Use `Agent` with `subagent_type` to ensure a specific agent

Explicit example:

```text
Agent({
  description: "Security review of login flow",
  subagent_type: "security-reviewer",
  prompt: "Review src/auth/ against OWASP A01-A10 and return CRITICAL/HIGH findings"
})
```

## Principle of least privilege

Each agent's `tools` field contains the **minimum set required for its role**.

- Exploratory agents (`explorer`, `planner`) have no write access at all
- Audit agents are read-focused. Only `performance-analyst` has Bash (for measurement commands); `security-reviewer` is fully read-only
- Write-capable agents (`doc-synchronizer`, `doc-writer`, `test-writer`) are scoped to specific paths by role
- `doc-synchronizer` and `doc-writer` set `permissionMode: acceptEdits` to skip permission prompts.
  That is acceptable because their remit is confined to `docs/` and `output/`. Do not set it on an
  agent that touches the source tree

Even if the parent session has broad permissions, agents won't cause unintended file changes.

On top of that, the `SubagentStart` hook (`subagent-audit.sh`) injects the harness-wide guardrails
(output locations, no secrets, evidence required) into every agent via `additionalContext`.

## Frontmatter keys worth knowing (official spec)

| Key | Purpose |
| --- | ------- |
| `name` / `description` | Required. Keep `description` to 1–2 sentences about when to invoke |
| `tools` / `disallowedTools` | Least privilege. Omitting `tools` inherits everything |
| `model` | `opus` / `sonnet` / `haiku` / `fable` / a pinned ID / `inherit` (default) |
| `effort` | `low` / `medium` / `high` / `xhigh` / `max` |
| `permissionMode` | `default` / `acceptEdits` / `auto` / `dontAsk` / `bypassPermissions` / `plan` |
| `maxTurns` | Upper bound on agentic turns (runaway protection) |
| `memory` | `user` / `project` / `local` — cross-session learning |
| `skills` | Skills to preload in full at startup |
| `isolation` | `worktree` runs the agent in a temporary git worktree (branched from the default branch) |
| `color` | Only `red` / `blue` / `green` / `yellow` / `purple` / `orange` / `pink` / `cyan` |

> `isolation: worktree` **branches from the default branch**, so never set it on a read-only agent
> meant to review work in progress — it would audit different code.

## Model tier selection (aligned with project-config.md §13)

| Tier | Alias | Usage | Example |
| ---- | ----- | ----- | ------- |
| Critical | `opus` | Security and architectural judgment | `security-reviewer` |
| Complex | `sonnet` | Design, implementation, testing, research, authoring | `planner`, `performance-analyst`, `test-writer`, `researcher`, `doc-writer` |
| Operational | `haiku` | Exploration, synchronization, repetitive work | `explorer`, `doc-synchronizer` |

Specify via the frontmatter `model:` key. **Prefer an alias over a pinned ID** — aliases follow model
generations and avoid the failure mode where a stale ID stops an agent from launching.
If unspecified, the session default is inherited.

## Adding a new agent

1. Create `.claude/agents/<agent-name>.md`
2. Fill in required frontmatter:
   ```yaml
   ---
   name: <agent-name>
   description: 1-2 sentences describing invocation conditions
   tools: Read, Grep, Glob   # Comma-separated, minimum privilege
   model: sonnet             # Alias matching the tier
   effort: medium            # Reasoning depth
   maxTurns: 30              # Runaway protection
   memory: project           # Cross-session learning
   color: blue               # UI hint (one of the 8 official colors)
   ---
   ```
3. Write role, guidelines, and constraints in the body (use the project's default language)
4. Add one row to the agent list table at the top of this file

## Concept alignment (Project Blueprint principles)

- Agents live in the generic `.claude/` layer; project-specific rules go in `docs/` or `project-config.md`
- Agents **inherit the CLAUDE.md hierarchy (including `.claude/rules/*.md`) and a git status snapshot by default** (Claude Code official semantics; only the built-in `Explore`/`Plan` agents skip both to stay minimal). Skills are preloaded in full only when named in the `skills:` frontmatter field — any other skill can still be invoked individually via the `Skill` tool
- Agents never modify `input/` (human domain). Deliverables go to `output/` or role-scoped locations

## Pitfalls

- A too-long `description` blurs invocation conditions and causes misfires. Keep to **1-2 sentences**
- Avoid unnecessary `tools`; when in doubt, **leave it out**
- Agents don't share the parent's working memory. Pass required context explicitly in `prompt`
- A `color` outside the official eight (e.g. `magenta`) breaks the display
- A `model` ID that does not exist makes the agent fail to launch — use an alias

See `@.claude/pitfalls.md` for more.
