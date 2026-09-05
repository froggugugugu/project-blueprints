# Guardrails — Safety Mechanism Overview

This file is the single reference for every safety mechanism applied to the project.
Rules that are scattered across `CLAUDE.md` sections are consolidated here.

---

## Hook inventory (15 scripts / 19 registrations)

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
| `verify-gate.sh track` | PostToolUse | Bash\|Edit\|Write\|NotebookEdit | observe | Records timestamps of source edits / verification commands (`testreport/.verify/`) |
| `verify-gate.sh gate` | **Stop** | — | warn/send back | If no verification command ran after the last edit: standard = warning / strict = sent back once (verification gate) |
| `verify-gate.sh task` | **TaskCompleted** | — | warn/refuse | Same condition on the completion mark: standard = warning / strict = exit 2 refuses it (mechanical enforcement of quality gate ③) |
| `permission-denied-log.sh` | **PermissionDenied** | `*` | observe | Records auto mode classifier denials (`testreport/denials/`) |
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

### Verification gate (Stop hook)

Implements the official best practice "give Claude a way to verify its work and gate the
stop deterministically with a Stop hook". Mechanically closes the trust-then-verify gap
(pitfalls #19) where work ends on "it should work".

```text
PostToolUse → verify-gate.sh track   records timestamps of source edits / verification commands
Stop        → verify-gate.sh gate    if no verification command ran after the last edit:
                                        standard: warns the human via systemMessage
                                        strict:   decision:block, sending Claude back once
```

- Verification commands: `npm test` / `vitest` / `jest` / `pytest` / `cargo test` / `go test` / `tsc` /
  `eslint` / `biome` / `playwright test` / `make test` and so on (`VERIFY_PATTERNS` in the script; extend per project)
- Not counted as source: edits under `docs/` `output/` `input/` `.claude/` `.github/` and `.md` / `.json` / `.yaml` / `.toml` files
- `stop_hook_active: true` (after our own block) and a non-empty `background_tasks` (paused) always pass (pitfalls #27)
- For a flexible, model-judged completion condition inside one conversation, combine with `/goal <condition>`
- Regression test: `bash scripts/validate-harness.sh --hooks` feeds hook JSON to every hook and checks exit codes / output (also runs in CI)

### Behavior per runtime

Hooks fire on **the same events** in the terminal, the IDE extension, the Desktop
app, and Claude Code on the web. What they can reach differs, though, and this
template has hooks that write to disk and send outbound notifications.

| | Terminal / IDE / Desktop | Claude Code on the web (cloud) | CI (`claude -p`) |
| --- | --- | --- | --- |
| Local files | ✅ Persistent | ⚠️ **Fresh clone**; `testreport/` is lost when the session ends | ⚠️ Lost when the job ends (upload as an artifact) |
| `notify-claude.sh` (ntfy) | ✅ | ⚠️ Depends on the environment's network access (restricted by default) | ❌ Pointless — stop it with `BLUEPRINT_HOOK_PROFILE=minimal` |
| `session-end.sh` / `pre-compact-backup.sh` | ✅ | ⚠️ Output does not persist | ⚠️ Same |
| `safety-check.sh` / `protect-files.sh` | ✅ | ✅ | ✅ |
| MCP servers | `.mcp.json` | Connectors configured per environment | `.mcp.json` (not read under `--bare`) |
| Permission prompts | Interactive | Autonomous (no prompts) | Follows `--permission-mode` |

**Recommended settings**:

- Set `BLUEPRINT_HOOK_PROFILE=minimal` in cloud and CI runs. It avoids paying the
  write cost of observation hooks whose output does not persist there
- When you want an audit trail from a cloud run, extract `testreport/` explicitly
  (in CI, `actions/upload-artifact`)
- Cloud environments restrict network access by default. Check the environment
  configuration before relying on a skill that needs `WebFetch` or an external MCP server

### Choosing how to schedule work

For recurring work such as a weekly security audit there are three options, and
their **durability differs sharply**.

| | In-session (`/loop`, `CronCreate`) | GitHub Actions `schedule` | Routines (cloud) |
| --- | --- | --- | --- |
| Needs a running session | **Yes** (fires only when idle) | No | No |
| Durability | ⚠️ Recurring tasks **expire after 7 days** | ✅ | ✅ |
| Minimum interval | 1 minute | 5 minutes (delays in practice) | 1 hour |
| Local files | ✅ | ✅ (clone) | ❌ (fresh clone) |
| Cleared by a new conversation | **Yes** | — | — |

- **Use GitHub Actions for repository audits.** The bundled
  `claude-scheduled-audit.yml.template` runs `/security-scan` and `/legal-check`
  weekly and collects the results in an issue
- Keep `/loop` for short-lived in-session polling (waiting on a build, say)
- Avoid `:00` in an Actions cron — that slot is congested and prone to delay

### Organization rollout (managed settings / OpenTelemetry)

Use managed settings to pin policy that individuals cannot override. The bundled
`.claude/managed-settings.example.json` shows deny rules / `disableBypassPermissionsMode` / sandbox /
OpenTelemetry (`CLAUDE_CODE_ENABLE_TELEMETRY` + an OTLP exporter) / `requiredMinimumVersion`.
This template's `testreport/` logs are machine-local, so aggregate team-wide usage and skill adoption through OTel
(`OTEL_LOG_TOOL_DETAILS=1` records skill names so unused skills can be identified).

### Hook profile switch

`BLUEPRINT_HOOK_PROFILE` switches behavior
(honored by `user-prompt-submit.sh`, `session-end.sh`, `scan-harness.sh`, `post-compact-restore.sh`, `subagent-audit.sh`,
`verify-gate.sh`, `permission-denied-log.sh`):

| Profile | Use for | Behavior |
| ------- | ------- | -------- |
| `minimal` | CI / automation | Pass-through (skip inspection). Minimal overhead |
| `standard` (default) | Everyday development | Warn only on detection (non-blocking) |
| `strict` | High-risk work | Block the skill / prompt on detection. Send an unverified stop back |

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
- **Claude Code overrides a Stop hook after 8 consecutive blocks**. Check `stop_hook_active` and block only once
- Extra handler fields: `if` (narrow the trigger with permission-rule syntax, e.g. `"if": "Bash(git *)"`) / `once` (removed after the first success) /
  `asyncRewake` (runs in the background and wakes Claude on exit 2) / `args` (exec form) / `statusMessage`

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
| `agent` | A subagent verifies the condition with tools (Read / Grep / Bash) before deciding | On Stop: "run the test suite and confirm everything passes" (experimental) |

- Prefer `command` by default (deterministic and fast)
- Use `prompt` / `agent` only when context-dependent judgement is required (they cost tokens). `/goal` is a session-scoped prompt-type Stop hook
- Multiple types can be combined on the same event

### Unused official hook events (room to extend)

Events this template does not use but a project can add:

| Event | When it fires | Example use |
| ----- | ------------- | ----------- |
| `Setup` | `--init-only` / `-p --init` | Dependency install in CI, scheduled cleanup |
| `InstructionsLoaded` | CLAUDE.md / rules loaded | Observability of rule application |
| `PermissionRequest` | A permission dialog appears | Automatic allow/deny by org policy |
| `PreModelSwitch` / `PostModelSwitch` | Before / after a model switch via `/model` etc. | Confirming or auditing switches to expensive models (a switch invalidates the cache) |
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
