# Guardrails — Safety Mechanism Overview

This file is the single reference for every safety mechanism applied to the project.
Rules that are scattered across `CLAUDE.md` sections are consolidated here.

---

## Hook inventory (13 scripts / 15 registrations)

| Hook | Event | Target | Behavior | Description |
| ---- | ----- | ------ | -------- | ----------- |
| `safety-check.sh` | PreToolUse | Bash | block | Detects and blocks dangerous shell commands |
| `protect-files.sh` | PreToolUse | Edit\|Write\|NotebookEdit | block | Blocks writes to secret and toolchain config files |
| `scan-harness.sh` | PreToolUse | Skill | warn/block | Self-SAST of the harness (secret leakage, constitution tampering, deny-rule weakening) |
| `user-prompt-submit.sh` | UserPromptSubmit | — | warn/block + context | Detects secret patterns; re-injects core rules right after a compact |
| `session-start.sh` | SessionStart | — | warn | Checks that project-config.md / docs/ / settings.local.json exist |
| `session-end.sh` | SessionEnd | — | observe | Appends a session summary to `output/reports/sessions/<date>.md` |
| `commit-quality.sh` | PostToolUse | Bash (git commit) | warn | Conventional Commits format check and secret detection |
| `console-warn.sh` | PostToolUse | Edit\|Write | warn | Detects leftover debug statements (console.log etc.) |
| `post-failure-log.sh` | **PostToolUseFailure** | `*` | observe | Structured error log on tool failure (`testreport/failures/`) |
| `subagent-audit.sh` | **SubagentStart** | — | observe + context | Logs the launch and injects guardrails into the subagent |
| `subagent-audit.sh` | SubagentStop | — | observe | Logs completion (`testreport/agents/`) |
| `pre-compact-backup.sh` | PreCompact | — | observe | Backs up the transcript before compaction (`testreport/transcripts/`) |
| `post-compact-restore.sh` | **PostCompact** | — | observe + marker | Preserves the summary and drops a re-injection marker |
| `notify-claude.sh` | Stop / Notification | — | notify (async) | External notification on task completion (ntfy) |

### Two-stage compaction recovery

Countermeasure for instructions fading after a context compact (pitfalls #21):

```text
PreCompact  → pre-compact-backup.sh   saves the transcript to testreport/transcripts/
PostCompact → post-compact-restore.sh preserves the summary, drops .post-compact-pending
                    ↓ (for exactly one prompt)
UserPromptSubmit → user-prompt-submit.sh collects the marker and re-injects
                    the core rules through additionalContext
```

> **Why two stages**: per the official spec, `PostCompact` has **no decision control
> at all** (it cannot even return `additionalContext`) — it is a side-effect-only
> event. Only `UserPromptSubmit` can inject context, so the marker bridges the two.

### Hook profile switch

`BLUEPRINT_HOOK_PROFILE` switches behavior
(honored by `user-prompt-submit.sh`, `session-end.sh`, `scan-harness.sh`, `post-compact-restore.sh`, `subagent-audit.sh`):

| Profile | Use for | Behavior |
| ------- | ------- | -------- |
| `minimal` | CI / automation | Pass-through (skip inspection). Minimal overhead |
| `standard` (default) | Everyday development | Warn only on detection (non-blocking) |
| `strict` | High-risk work | Block the skill / prompt on detection |

Switching through `.envrc` or `direnv` is recommended.

### Hook behavior rules (official spec)

- **exit 2 = block**. stderr is returned to Claude as the block reason
  - Exception: `UserPromptSubmit` rejects with `exit 0 + stdout JSON {"decision":"block","reason":"..."}`
- **stderr on exit 0 only reaches the debug log** — neither Claude nor the user sees it
  - To surface a warning to Claude, **print `hookSpecificOutput.additionalContext` on stdout**
  - Every warning hook in this template implements that through a shared `emit_context()`
- **stdout is interpreted by its first character**: `{` means JSON, anything else is plain text
  - Plain text is only added as context for `UserPromptSubmit` / `UserPromptExpansion` / `SessionStart`
- **fail-open policy**: allow the operation when JSON parsing fails or jq is missing (never stall work)
- **`async: true`**: slow hooks such as outbound notifications can run in the background
  - Async hooks cannot return `decision` / `permissionDecision` / `continue`
  - In this template only `notify-claude.sh` (ntfy delivery) is async
- Hooks stay active under `--dangerously-skip-permissions` (defense in depth)

### Decision control by event (excerpt)

| Event | Control |
| ----- | ------- |
| `PreToolUse` | `hookSpecificOutput.permissionDecision` (allow / deny / ask / defer) |
| `UserPromptSubmit` / `PostToolUse` / `PostToolUseFailure` / `Stop` / `SubagentStop` / `PreCompact` | Top-level `decision: "block"` + `reason` |
| `SessionStart` / `Setup` / `SubagentStart` | **Context only** (`additionalContext`). Cannot block |
| `PostCompact` / `SessionEnd` / `Notification` / `FileChanged` etc. | **No control**. Side effects such as logging and cleanup only |

### Choosing a hook type

| Type | Use for | Examples |
| ---- | ------- | -------- |
| `command` | Run a shell script. Deterministic pattern/file checks | safety-check.sh, protect-files.sh |
| `prompt` | Delegate the judgement to the model when it is context-dependent | "Assess whether this Bash command is safe in production" |
| `http` | POST to an external endpoint. Centralized auditing | An organization-wide audit server |
| `mcp_tool` | Call an MCP tool directly | — |

- Prefer `command` by default (deterministic and fast)
- Use `prompt` only when context-dependent judgement is required (it costs tokens)
- Multiple types can be combined on the same event

### Unused official hook events (room to extend)

Events this template does not use but a project can add:

| Event | When it fires | Example use |
| ----- | ------------- | ----------- |
| `Setup` | `--init-only` / `-p --init` | Dependency install in CI, scheduled cleanup |
| `InstructionsLoaded` | CLAUDE.md / rules loaded | Observability of rule application |
| `PermissionRequest` | A permission dialog appears | Automatic allow/deny by org policy |
| `PermissionDenied` | Auto-denied in auto mode | Aggregating denial events |
| `PostToolBatch` | A parallel tool batch completes | Per-batch verification |
| `TaskCreated` / `TaskCompleted` | Task created / completed | Enforcing task naming, quality gates |
| `TeammateIdle` | A teammate goes idle | Quality gates for agent teams |
| `StopFailure` | A turn ends in an error | Measuring failure rate |
| `FileChanged` | A file change is detected | Syncing with external tooling |
| `WorktreeCreate` / `WorktreeRemove` | Worktree created / removed | Setting up isolated environments |
| `CwdChanged` / `DirectoryAdded` / `ConfigChange` | Working directory or settings change | Auditing environment drift |
| `MessageDisplay` | Assistant output is rendered | Masking displayed content |
| `Elicitation` / `ElicitationResult` | MCP form input | Automatic responses |

Format to add in `settings.json`:

```json
{
  "hooks": {
    "TaskCompleted": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "./scripts/gate-check.sh", "timeout": 30 }
        ]
      }
    ]
  }
}
```

---

## Deny rules (settings.json)

### Destructive shell operations

| Pattern | Purpose |
| ------- | ------- |
| `Bash(rm -rf *)` / `Bash(rm -rf /*)` / `Bash(rm -fr *)` | Prevent recursive deletion |
| `Bash(git push --force *)` / `Bash(git push -f *)` | Prevent force pushes |
| `Bash(git reset --hard *)` | Prevent hard resets |
| `Bash(git clean -f *)` | Prevent bulk deletion of untracked files |
| `Bash(sudo *)` | Prevent privilege escalation |
| `Bash(chmod 777 *)` | Prevent excessive permission grants |
| `Bash(dd if=*)` / `Bash(mkfs*)` | Prevent destructive disk operations |
| `Bash(* --no-verify)` / `Bash(* --no-verify *)` | Prevent bypassing Git hooks |
| `Skill(skill:deploy)` / `Skill(skill:deploy-*)` / `Skill(skill:*-deploy)` | Block deploy-class skills |
| `Skill(skill:production-*)` / `Skill(skill:*-production)` | Block production-class skills |

> `Tool(param:value)` rules deny or ask on any tool's top-level input parameter.
> The `Skill` tool's `skill` parameter is covered, so high-risk skills can be stopped at the
> permission layer. `scan-harness.sh` doubles up on the same check as an operational layer
> that a profile can relax.

### Blocking secret reads (new)

`protect-files.sh` only sees `Edit`/`Write`, so **reads** are closed off through
permissions. A `Read(...)` deny rule also blocks Edit and Write on the same path,
and applies to the file commands Claude Code recognizes in Bash (`cat`, `head`, `sed`, …).

| Pattern | Purpose |
| ------- | ------- |
| `Read(./.env)` / `Read(./.env.*)` | Environment files |
| `Read(./secrets/**)` | Secrets directory |
| `Read(.npmrc)` | Registry tokens |
| `Read(credentials.json)` / `Read(service-account.json)` | Cloud credentials |
| `Read(id_rsa)` / `Read(id_ed25519)` / `Read(id_ecdsa)` / `Read(id_dsa)` | SSH private keys |
| `Read(*.pem)` / `Read(*.key)` / `Read(*.p12)` / `Read(*.pfx)` / `Read(*.jks)` / `Read(*.keystore)` | Certificates and keystores |
| `Edit(./.env)` / `Edit(./.env.*)` / `Edit(*.pem)` / `Edit(*.key)` | Deny modification, NotebookEdit included |

> **Caveat**: Read/Edit deny rules only cover Claude's built-in file tools and the
> Bash file commands it recognizes. They do not stop a Python or Node script that
> opens files itself. For OS-level enforcement, enable `sandbox` (below).

### Ask rules (operations that always confirm)

Outbound and irreversible operations that **always prompt**, even under
`acceptEdits` / `bypassPermissions`:

| Pattern | Purpose |
| ------- | ------- |
| `Bash(git push *)` | Confirm every push to a remote |
| `Bash(gh pr merge *)` / `Bash(gh release *)` / `Bash(gh repo delete *)` | Merge, release, delete |
| `Bash(npm publish *)` / `Bash(yarn publish *)` / `Bash(pnpm publish *)` | Package publication |
| `Bash(docker push *)` | Image publication |
| `Bash(kubectl apply *)` / `Bash(kubectl delete *)` | Cluster changes |
| `Bash(terraform apply *)` / `Bash(terraform destroy *)` | Infrastructure changes |
| `Bash(curl *)` / `Bash(wget *)` | Arbitrary outbound requests (restrict URLs via `WebFetch(domain:...)`) |

> Evaluation order is `deny` > `ask` > `allow`. Even with `Bash(git push *)` in the
> allow list of `settings.local.json`, the ask rule wins — that is intentional.

---

## Protected files

### Secrets and credentials (protect-files.sh + deny rules)

| File / pattern | Reason |
| -------------- | ------ |
| `.env`, `.env.local`, `.env.production`, … | Environment variables (may contain secrets) |
| `id_rsa`, `id_ed25519`, `id_ecdsa`, `id_dsa` | SSH private keys |
| `credentials.json`, `service-account.json` | Cloud credentials |
| `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.jks`, `*.keystore` | Certificates and keystores |
| `.claude/settings.json`, `.claude/settings.local.json` | Claude Code configuration |

### Toolchain configuration (protect-files.sh)

| File / pattern | Reason |
| -------------- | ------ |
| `biome.json`, `biome.jsonc` | Biome linter/formatter config |
| `.eslintrc.*`, `eslint.config.*` | ESLint config |
| `.prettierrc.*`, `prettier.config.*` | Prettier config |
| `tsconfig.json`, `tsconfig.*.json` | TypeScript compiler config |
| `.editorconfig` | Editor config |

---

## Prohibited operations (CLAUDE.md + safety-check.sh)

| Operation | Reason |
| --------- | ------ |
| `--no-verify` | Bypassing Git hooks is prohibited |
| `--force` (git push) | Rewriting history is prohibited by default |
| `sudo` | Privilege escalation is prohibited |
| `curl \| bash` | Piping remote scripts into a shell is prohibited |
| `chmod 777` | Excessive permission grants are prohibited |
| `dd if=` / `mkfs` | Disk operations are prohibited |

---

## Three-layer defense model

```text
Layer 0: OS sandbox (optional / opt-in via settings.local.json)
   └─ sandbox.enabled = true runs Bash sandboxed. Restricts file and network
      access at the OS level, even for arbitrary subprocesses
  ↓
Layer 1: Hooks (active even under --dangerously-skip-permissions)
   ├─ PreToolUse: safety-check / protect-files / scan-harness (Skill)
   ├─ PostToolUse: commit-quality / console-warn
   ├─ PostToolUseFailure: post-failure-log
   ├─ UserPromptSubmit: user-prompt-submit
   ├─ SessionStart / SessionEnd: session-start / session-end
   ├─ SubagentStart / SubagentStop: subagent-audit
   ├─ PreCompact / PostCompact: pre-compact-backup / post-compact-restore
   └─ Stop / Notification: notify-claude (async)
  ↓
Layer 2: Deny / Ask rules (settings.json — shared by the team)
   ├─ deny: unconditionally blocks destructive operations and secret reads
   └─ ask : always confirms outbound and irreversible operations, in any permission mode
  ↓ active in normal mode
Layer 3: Allow rules (settings.local.json — personal)
  ↓ active only in normal mode
meta : self-SAST (scan-harness.sh detects constitution hash drift, secret leakage, deny weakening)
```

> Layer 1 contains blocking hooks (`safety-check.sh`, `protect-files.sh`, `scan-harness.sh`),
> observation hooks (`subagent-audit.sh`, `pre-compact-backup.sh`, `post-compact-restore.sh`,
> `post-failure-log.sh`, `session-end.sh`), warning hooks (`commit-quality.sh`,
> `console-warn.sh`, `user-prompt-submit.sh`) and notification hooks (`notify-claude.sh`).
> The observation and notification hooks never block, but they keep recording and
> notifying under `--dangerously-skip-permissions`, which makes them part of the defense.

- Layer 0 is off by default. Enable it for air-gapped work or projects that execute external code
- Layer 1 is always active and is the most reliable layer
- Layer 2 applies automatically in normal mode; `ask` also applies under `acceptEdits` / `bypassPermissions`
- Layer 3 holds project-specific allow rules (configured from the template)

### Enabling Layer 0 (optional)

```json
// .claude/settings.local.json
{
  "sandbox": {
    "enabled": true,
    "network": {
      "allowedDomains": ["registry.npmjs.org", "github.com", "api.github.com"]
    }
  }
}
```

If a command fails inside the sandbox, exempt it individually with `sandbox.excludedCommands`.
