# Permissions Guide — running the three tiers: allowlist / auto mode / sandbox

Claude Code offers three mechanisms to reduce approval fatigue.
This template recommends adopting them incrementally as the project matures.

| Tier | Role | Risk model | Recommended phase |
| ---- | ---- | ---------- | ----------------- |
| **allowlist** | Explicitly allow known-safe commands and MCP tools | Whitelist. Anything not listed is reliably refused | All phases (foundation) |
| **auto mode** | A classifier model reviews each action and stops only risky ones | Blacklist + dynamic judgement. Misclassification is possible | **Default** on Pro / Max / Team. Use it with deny / ask reinforcing the boundary |
| **sandbox** | OS-level filesystem / network isolation | Physical containment via containers / namespaces | Tasks with a low trust boundary |

> Official specs: [permissions](https://code.claude.com/docs/en/permissions) /
> [permission-modes](https://code.claude.com/docs/en/permission-modes) /
> [auto-mode-config](https://code.claude.com/docs/en/auto-mode-config) /
> [sandboxing](https://code.claude.com/docs/en/sandboxing)

## 1. allowlist (foundation)

Managed through `permissions.allow` in `settings.local.json`. This template ships a
starter file as `settings.local.json.template`. To add project-specific commands
(build tools, DB CLIs, etc.):

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

- Keep **deny / ask in `settings.json` (shared)** and **allow in `settings.local.json` (personal)**
- Never use broad patterns like `Bash(rm *)`. Always enumerate specific subcommands
- Allow MCP at the `mcp__<server>__<tool>` granularity. Be careful with wildcards
- File-path permissions are evaluated only for `Read(path)` / `Edit(path)` (`Write(path)` is ignored, pitfalls #22)
- deny / ask rules can target a single parameter with `Tool(param:value)`
  (e.g. `Agent(isolation:worktree)`, `Skill(skill:deploy-*)`)
- For every line you add, ask "what happens if this goes through?"
- Allow rules in project settings take effect only **after you trust the folder** (deny / ask always apply)

## 2. auto mode

In interactive sessions on Pro / Max / Team plans, **auto mode is the default permission mode**
(v2.1.228 and later). A classifier model reviews every tool call and blocks only scope
escalation, unknown infrastructure, and hostile-content-driven actions. `claude -p`
(non-interactive) and Enterprise / API-key sessions still default to Manual (`default`).

### Evaluation order (important)

```text
permissions.deny  → absolute block before the classifier (user intent cannot override)
permissions.ask   → always prompts, even in auto mode (the classifier cannot auto-approve it)
classifier        → reviews everything not covered above
hooks (Layer 1)   → always fire in every mode
```

This template's `settings.json` is designed around that order: outbound operations such as
`git push` / `gh pr merge` / `publish` / `kubectl apply` sit in `ask`, so they always pass
through a human confirmation even in auto mode.

### Where settings go (an official-spec pitfall)

| Setting | Honored in | Ignored in |
| ------- | ---------- | ---------- |
| `permissions.deny` / `permissions.ask` | every settings file (project included) | — |
| `permissions.defaultMode: "auto"` | `~/.claude/settings.json`, managed | **project / local settings** (pitfalls #25) |
| `autoMode.environment` / `hard_deny` / `soft_deny` / `allow` | `~/.claude/settings.json`, managed | **project / local settings** |
| `disableAutoMode: "disable"` | any settings file | — |

- When your organization's repos, buckets, or internal domains are treated as "external" and denied,
  run `/auto-mode-setup` to draft `autoMode.environment` entries and save them to your personal settings
- The classifier **also reads CLAUDE.md**. Project-specific prohibitions such as "never force push"
  written there steer Claude and the classifier at the same time

### Using the denial history

The `PermissionDenied` hook (`permission-denied-log.sh`) records classifier denials to
`testreport/denials/<session>.jsonl`.

- A legitimate action is denied repeatedly → add it to `allow` in `settings.local.json`
- Your own infrastructure is treated as external → describe it in `autoMode.environment`
- Repeated denials in a `-p` (non-interactive) run don't stop the run. Check the reasons in the log and fix as above

### Caveats

- The classifier isn't perfect. Treat it as a "looser" defense than the allowlist and pin the boundary with deny / ask / hooks
- This template's hook layer (safety-check / protect-files / verify-gate) stays active in auto mode
- To keep working until a condition holds, combine auto mode with `/goal <condition>`

## 3. sandbox

Enable with `claude --sandbox` or `/sandbox` during a session. Isolates the filesystem and
network at the OS level. To make it a shared setting, use the `sandbox` key in `settings.json`
(a starter block is in `_comment_sandbox` of `settings.local.json.template`).

### Recommended use cases

- **Running unknown / untrusted code**: trying a PoC script picked up from a GitHub issue
- **Dynamic dependency verification**: checking a suspicious package right after `npm install`
- **Running changes fetched from CI for review**: exercising an external PR

### Constraints

- File writes are confined to the sandbox (protects everything outside the repository)
- Network access is allowlist-based. Closed by default
- Some performance overhead (a few percent and up)
- Works independently of auto mode and combines with it (in plan mode, auto-allow doesn't widen approvals)

## Recommended operating patterns

| Scenario | Recommended setup |
| -------- | ----------------- |
| Early development (right after setup) | auto mode (default) + shared deny / ask. Add allow rules while watching the classifier's denial log |
| Stable operation | auto mode + `/goal` for long unattended tasks. `strict` profile turns the verification gate into a send-back |
| High-risk investigation (vulnerability checks etc.) | Enable the sandbox and run in a separate worktree (`--worktree`) |
| CI / GitHub Actions | `--permission-mode dontAsk` + a strict `--allowedTools` allowlist + `--max-turns N` |
| Fully unattended inside a container | `--dangerously-skip-permissions` (container / VM required; deny rules and hooks still apply in this mode) |

## Alignment with the 3-layer defense model

This template's guardrails (`@.claude/guardrails.md`) use three layers of defense:

```text
Layer 1: hooks (always active, even under --dangerously-skip-permissions)
  ↓
Layer 2: deny / ask rules (settings.json, shared; ahead of / above the auto mode classifier)
  ↓
Layer 3: allow rules (settings.local.json, personal)
```

The scope of this guide is **Layer 2 + Layer 3**. Layer 1 hooks operate independently of
these tiers, so an operation that slipped through auto mode by mistake is still blocked by a hook.

## Related documents

- `@.claude/guardrails.md` — hooks, deny rules, protected files
- `@.claude/pitfalls.md` — #23 auto mode / #25 ignored project settings / #27 Stop hooks
- `settings.local.json.template` — starter file (build-tool swap patterns, auto mode / Stop gate notes)
- `managed-settings.example.json` — example for pinning policy organization-wide (deny / sandbox / OpenTelemetry)
