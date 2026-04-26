# Guardrails — Safety Mechanism Overview

This file consolidates all safety mechanisms applied to the project as a single reference document.
Provides a unified view of rules that are otherwise distributed across various sections of `CLAUDE.md`.

---

## Hook Inventory

| Hook | Event | Target | Behavior | Description |
| ---- | ----- | ------ | -------- | ----------- |
| `safety-check.sh` | PreToolUse | Bash | Block | Detects and prevents dangerous shell commands |
| `protect-files.sh` | PreToolUse | Edit\|Write | Block | Prevents writes to sensitive and config files |
| `scan-harness.sh` | PreToolUse | Skill | Warn/Block | Self-SAST: detects secrets, constitution drift, weakened local denies in the harness |
| `user-prompt-submit.sh` | UserPromptSubmit | — | Warn/Block | Detects secret patterns (API keys, tokens) in user input |
| `session-start.sh` | SessionStart | — | Warn | Checks existence of project-config.md / docs/ / settings.local.json |
| `session-end.sh` | SessionEnd | — | Observe | Appends session summary to `output/reports/sessions/<date>.md` |
| `commit-quality.sh` | PostToolUse | Bash (git commit) | Warn | Conventional Commits format check and secret detection |
| `console-warn.sh` | PostToolUse | Edit\|Write | Warn | Detects leftover debug statements (console.log, etc.) |
| `post-failure-log.sh` | PostToolUse | All tools | Observe | Structured error logs on tool failure (`testreport/failures/`) |
| `subagent-audit.sh` | SubagentStop | — | Observe | Subagent completion records (`testreport/agents/`) |
| `pre-compact-backup.sh` | PreCompact | — | Observe | Transcript backup before compact (`testreport/transcripts/`) |
| `notify-claude.sh` | Stop / Notification | — | Notify | External notification on task completion (ntfy) |

### Hook profile switching (2026 extension)

The `BLUEPRINT_HOOK_PROFILE` env var controls behavior of `user-prompt-submit.sh` / `session-end.sh` / `scan-harness.sh`:

| profile | Use case | Behavior |
| ------- | -------- | -------- |
| `minimal` | CI / automation | Pass-through (skip checks). Minimum overhead |
| `standard` (default) | Normal dev | Warn-only on detection (non-blocking) |
| `strict` | High-risk work | Block skill / prompt on detection |

Recommended switching mechanism: `.envrc` / `direnv`.

### Hook Behavior Principles

- **Block hooks**: exit 2 to abort the operation. Reason communicated via stderr
- **Warn hooks**: exit 0 to allow the operation. Feedback provided via stderr
- **Notify hooks**: exit 0. Sends notifications to external services
- **Fail-open policy**: If JSON parsing fails, the operation is allowed (don't block work)
- Hooks remain active even with `--dangerously-skip-permissions` (defense in depth)

### Hook Type Selection

| Type | Purpose | Example |
| ---- | ------- | ------- |
| `command` | Execute shell scripts. Deterministic checks like pattern matching and file inspection | safety-check.sh, protect-files.sh |
| `prompt` | Delegate judgment to AI via prompt. For context-dependent flexible decisions | "Evaluate if this Bash command is safe for production" |

- Default to `command` type (deterministic and fast)
- Use `prompt` type only when context-dependent judgment is needed (consumes tokens)
- Both types can coexist on the same event (command → prompt evaluation order)

### Extensible Hook Events

Hook events **not** implemented in this template but available for project-specific additions:

| Event | Timing | Use Case |
| ----- | ------ | -------- |
| `PreToolUse` (matcher: `"Task"`) | Subagent invocation | Capture start events, inject env vars |
| `PreToolUse` (matcher: `"Agent"`) | Just before agent spawn | Pre-spawn screening |

> As of 2026-04, `UserPromptSubmit` / `SessionEnd` / `SubagentStop` / `PreCompact` / `PostToolUse (failure handling)` / `PreToolUse (Skill)` are implemented (see Hook Inventory above).
> The official hook events are `PreToolUse` / `PostToolUse` / `UserPromptSubmit` / `Notification` / `Stop` / `SubagentStop` / `PreCompact` / `SessionStart` / `SessionEnd` (9 total).

Add to `settings.json` in this format:

```json
{
  "UserPromptSubmit": [
    {
      "matcher": "",
      "hooks": [
        { "type": "command", "command": "./scripts/prompt-audit.sh", "timeout": 10 }
      ]
    }
  ]
}
```

---

## Deny Rules (settings.json)

| Pattern | Purpose |
| ------- | ------- |
| `Bash(rm -rf *)` | Prevent recursive deletion |
| `Bash(rm -rf /*)` | Prevent root directory deletion |
| `Bash(rm -fr *)` | Prevent recursive deletion (flag order variant) |
| `Bash(git push --force *)` | Prevent force push |
| `Bash(git push -f *)` | Prevent force push (short form) |
| `Bash(git reset --hard *)` | Prevent hard reset |
| `Bash(git clean -f *)` | Prevent bulk deletion of untracked files |
| `Bash(sudo *)` | Prevent privilege escalation |

---

## Protected Files

### Secrets & Credentials (protect-files.sh)

| File / Pattern | Reason |
| -------------- | ------ |
| `.env`, `.env.local`, `.env.production`, etc. | Environment variables (may contain secrets) |
| `id_rsa`, `id_ed25519`, `id_ecdsa`, `id_dsa` | SSH private keys |
| `credentials.json`, `service-account.json` | Cloud credentials |
| `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.jks`, `*.keystore` | Certificates and keystores |
| `.claude/settings.json`, `.claude/settings.local.json` | Claude Code settings |

### Toolchain Configuration (protect-files.sh)

| File / Pattern | Reason |
| -------------- | ------ |
| `biome.json`, `biome.jsonc` | Biome linter/formatter config |
| `.eslintrc.*`, `eslint.config.*` | ESLint config |
| `.prettierrc.*`, `prettier.config.*` | Prettier config |
| `tsconfig.json`, `tsconfig.*.json` | TypeScript compiler config |
| `.editorconfig` | Editor config |

---

## Prohibited Operations (CLAUDE.md + safety-check.sh)

| Operation | Reason |
| --------- | ------ |
| `--no-verify` | Bypassing Git hooks is prohibited |
| `--force` (git push) | History destruction is prohibited in principle |
| `sudo` | Privilege escalation is prohibited |
| `curl \| bash` | Piped remote script execution is prohibited |
| `chmod 777` | Excessive permission grants are prohibited |
| `dd if=` / `mkfs` | Disk operations are prohibited |

---

## 3-Layer Defense Model

```text
Layer 1: Hooks (PreToolUse / PostToolUse / SessionStart / SubagentStop / PreCompact)
  ↓  Active even with --dangerously-skip-permissions
Layer 2: Deny rules (settings.json)
  ↓  Active in normal mode
Layer 3: Allow rules (settings.local.json)
  ↓  Active only in normal mode
```

> Layer 1 includes blocking hooks (`safety-check.sh` / `protect-files.sh`), observation hooks (`subagent-audit.sh` / `pre-compact-backup.sh` / `post-failure-log.sh`), and notification hooks (`notify-claude.sh`). The observation and notification hooks don't block operations, but they still function as part of the defense perimeter by persisting audit trails and alerts even under `--dangerously-skip-permissions`.

- Layer 1 is always active. The most reliable defense layer
- Layer 2 is automatically applied in normal mode
- Layer 3 contains project-specific allow rules (configured from template)
