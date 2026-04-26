# Permissions Guide — auto / sandbox / allowlist (3-tier model)

Claude Code provides three mechanisms to reduce the friction of permission prompts.
This template recommends adopting them progressively as the project matures.

| Tier | Role | Risk Model | Recommended Phase |
| ---- | ---- | ---------- | ----------------- |
| **allowlist** | Explicitly permit known-safe commands and MCPs | Whitelist. Anything not listed is denied | All phases (foundation) |
| **auto mode** | A classifier evaluates each action and only prompts on high-risk ones | Blacklist + dynamic judgment. Misclassification risk exists | Mid-to-late stage, stable CI runs |
| **sandbox** | OS-level filesystem and network isolation | Physically separated via container / namespace | Tasks with low trust boundary |

> Specs: [code.claude.com/docs/en/permissions](https://code.claude.com/docs/en/permissions) /
> [permission-modes](https://code.claude.com/docs/en/permission-modes) /
> [sandboxing](https://code.claude.com/docs/en/sandboxing)

## 1. allowlist (foundation)

Operated via `permissions.allow` in `settings.local.json`. The template ships a
ready-to-use `settings.local.json.template`. To add project-specific commands
(build tools / DB CLI / etc.):

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Bash(npx vitest *)",
      "Bash(gh pr *)",
      "mcp__context7__*"
    ]
  }
}
```

### Best practices

- **deny in `settings.json` (shared)**, **allow in `settings.local.json` (personal)**.
- Avoid broad patterns like `Bash(rm *)`. Always enumerate specific subcommands.
- For MCPs, allow at the `mcp__<server>__<tool>` granularity. Use wildcards sparingly.
- For each line you add, ask "what could this allow that I don't want?".

## 2. auto mode

Start with `claude --permission-mode auto`. A classifier model reviews each tool
invocation and blocks only scope escalations, unknown infrastructure, or
hostile-content-driven actions.

### Recommended use cases

- **Long-running autonomous workflows**: `/loop` or `claude -p` non-interactive runs.
- **Large fan-out batches**: migrating 1000+ files in one shot.
- **CI batch jobs**: GitHub Actions where no human can approve.

### Caveats

- In non-interactive mode (`-p`), the run aborts if the classifier blocks too often.
- The classifier is not perfect. Treat it as a "looser" defense than allowlist.
- This template's hook layer (safety-check / protect-files) remains active in auto mode.

## 3. sandbox

Enable via `claude --sandbox` or `/sandbox` mid-session. Isolates the filesystem
and network at the OS level.

### Recommended use cases

- **Untrusted code execution**: trying a PoC script grabbed from a GitHub issue.
- **Dynamic dependency verification**: checking the behavior of a newly installed
  package immediately after `npm install`.
- **External PR review runs**: dynamically verifying changes pulled from CI.

### Constraints

- File writes are confined to the sandbox (no impact outside the repo).
- Network access is allowlisted; default is closed.
- A small performance overhead (a few percent).

## Recommended operating patterns

| Scenario | Recommended configuration |
| -------- | ------------------------- |
| Early development (right after setup) | allowlist only; gradually add project-specific commands |
| Stable operation | allowlist + auto mode for long-running `/loop` tasks |
| High-risk investigation (vuln research) | enable sandbox in a separate worktree |
| CI / GitHub Actions | allowlist + `--max-turns N` + `--timeout N` |

## Alignment with the 3-layer defense model

The template's guardrails (`@.claude/guardrails.md`) follow a 3-layer model:

```text
Layer 1: hooks (always active, even with --dangerously-skip-permissions)
  v
Layer 2: deny rules (settings.json, shared)
  v
Layer 3: allow rules (settings.local.json, personal)
```

This permissions-guide covers **Layer 2 + Layer 3**. Layer 1 hooks operate
independently of all three modes, so even if auto mode "lets through" something
unintended, the hooks still block it.

## Related documents

- `@.claude/guardrails.md` — hook inventory, deny rules, protected files.
- `@.claude/pitfalls.md` — gotchas including `.claude/settings.local.json` mis-sharing.
- `settings.local.json.template` — template (with package-manager-specific swap patterns).
