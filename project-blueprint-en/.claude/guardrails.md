# Guardrails — Safety Mechanism Overview

This file consolidates all safety mechanisms applied to the project as a single reference document.
Provides a unified view of rules that are otherwise distributed across various sections of `CLAUDE.md`.

---

## Hook Inventory

| Hook | Event | Target | Behavior | Description |
| ---- | ----- | ------ | -------- | ----------- |
| `safety-check.sh` | PreToolUse | Bash | Block | Detects and prevents dangerous shell commands |
| `protect-files.sh` | PreToolUse | Edit\|Write | Block | Prevents writes to sensitive and config files |
| `session-start.sh` | SessionStart | — | Warn | Checks existence of project-config.md / docs/ / settings.local.json |
| `commit-quality.sh` | PostToolUse | Bash (git commit) | Warn | Conventional Commits format check and secret detection |
| `console-warn.sh` | PostToolUse | Edit\|Write | Warn | Detects leftover debug statements (console.log, etc.) |
| `notify-claude.sh` | Stop / Notification | — | Notify | External notification on task completion (ntfy) |

### Hook Behavior Principles

- **Block hooks**: exit 2 to abort the operation. Reason communicated via stderr
- **Warn hooks**: exit 0 to allow the operation. Feedback provided via stderr
- **Notify hooks**: exit 0. Sends notifications to external services
- **Fail-open policy**: If JSON parsing fails, the operation is allowed (don't block work)
- Hooks remain active even with `--dangerously-skip-permissions` (defense in depth)

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
Layer 1: Hooks (PreToolUse / PostToolUse / SessionStart)
  ↓  Active even with --dangerously-skip-permissions
Layer 2: Deny rules (settings.json)
  ↓  Active in normal mode
Layer 3: Allow rules (settings.local.json)
  ↓  Active only in normal mode
```

- Layer 1 is always active. The most reliable defense layer
- Layer 2 is automatically applied in normal mode
- Layer 3 contains project-specific allow rules (configured from template)
