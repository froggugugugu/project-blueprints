# Claude Code Subagents — Selection Guide

`.claude/agents/` is a collection of subagent definitions for **delegating single-shot tasks to specialists**.
Claude Code parses each agent's `description` field for auto-invocation.
To invoke explicitly, use the `Task` tool with `subagent_type: <name>`.

## Agent list

| Agent | Purpose | Model | Tools | Write access |
| ----- | ------- | ----- | ----- | ------------ |
| `explorer` | Broad codebase exploration | Haiku 4.5 | Read / Grep / Glob | None |
| `planner` | Pre-implementation design planning | Sonnet 4.6 | Read / Grep / Glob | None |
| `security-reviewer` | OWASP-aligned security audit | Opus 4.7 | Read / Grep / Glob | None |
| `performance-analyst` | Measurement-first bottleneck analysis | Sonnet 4.6 | Read / Grep / Glob / Bash | None |
| `doc-synchronizer` | Auto-sync updates to `docs/` | Haiku 4.5 | Read / Edit / Write / Grep / Glob | `docs/` only |
| `test-writer` | Unit and E2E test creation | Sonnet 4.6 | Read / Edit / Write / Grep / Glob / Bash | Test files only |

## agent vs team vs skill — when to use which

| Goal | Choice | Rationale |
| ---- | ------ | --------- |
| Routine collaborative work across roles (PRD → design → impl → verify) | **team** (`.claude/teams/TEAM_*.md`) | Pre-wired role assignments and approval gates |
| Execute a predetermined procedure (PRD generation, code review, etc.) | **skill** (`.claude/skills/*/SKILL.md`) | Defined I/O contracts and output locations |
| One-off specialized investigation or review (avoid reinventing wheels) | **agent** (`.claude/agents/*.md`) | Isolated context, lightweight execution |

These three complement rather than compete. For example, a `TEAM_PJM` Reviewer can delegate to `security-reviewer` for a focused audit.

## Auto-invocation vs explicit invocation

- **Auto-invocation**: Claude Code matches the parent prompt against each agent's `description` and delegates implicitly
- **Explicit invocation**: Use `Task` with `subagent_type` to ensure a specific agent

Explicit example:

```
Task({
  description: "Security review of login flow",
  subagent_type: "security-reviewer",
  prompt: "Review src/auth/ against OWASP A01-A10 and return CRITICAL/HIGH findings"
})
```

## Principle of least privilege

Each agent's `tools` field contains the **minimum set required for its role**.

- Exploratory agents (`explorer`, `planner`) have no write access at all
- Audit agents are read-focused. Only `performance-analyst` has Bash (for measurement commands); `security-reviewer` is fully read-only
- Write-capable agents (`doc-synchronizer`, `test-writer`) are scoped to specific paths by role

Even if the parent session has broad permissions, agents won't cause unintended file changes.

## Model tier selection (aligned with project-config.md §13)

| Tier | Model | Usage | Example |
| ---- | ----- | ----- | ------- |
| Critical | Opus 4.7 | Security and architectural judgment | `security-reviewer` |
| Complex | Sonnet 4.6 | Design, implementation, testing | `planner`, `performance-analyst`, `test-writer` |
| Operational | Haiku 4.5 | Exploration, synchronization, repetitive work | `explorer`, `doc-synchronizer` |

Specify via the frontmatter `model:` key. If unspecified, the session default is inherited.

## Adding a new agent

1. Create `.claude/agents/<agent-name>.md`
2. Fill in required frontmatter:
   ```yaml
   ---
   name: <agent-name>
   description: 1-2 sentences describing invocation conditions
   tools: Read, Grep, Glob  # Comma-separated, minimum privilege
   model: claude-sonnet-4-6  # Pick by tier
   color: blue               # UI hint
   ---
   ```
3. Write role, guidelines, and constraints in the body (use the project's default language)
4. Add one row to the agent list table at the top of this file

## Concept alignment (Project Blueprint principles)

- Agents live in the generic `.claude/` layer; project-specific rules go in `docs/` or `project-config.md`
- Agents **do not inherit skills/rules from the parent session** (Claude Code semantics) — restate required rules in each agent's body
- Agents never modify `input/` (human domain). Deliverables go to `output/` or role-scoped locations

## Pitfalls

- A too-long `description` blurs invocation conditions and causes misfires. Keep to **1-2 sentences**
- Avoid unnecessary `tools`; when in doubt, **leave it out**
- Agents don't share the parent's working memory. Pass required context explicitly in `prompt`

See `@.claude/pitfalls.md` for more.
