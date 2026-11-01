# Guardrails — Safety Mechanism Overview

This file is the single reference for every safety mechanism applied to the project.
Rules that are scattered across `AGENTS.md` / `CLAUDE.md` sections are consolidated here.

---

## Hook inventory (18 scripts / 27 settings registrations + 3 agent-frontmatter registrations)

| Hook | Event | Target | Behavior | Description |
| ---- | ----- | ------ | -------- | ----------- |
| `safety-check.sh` | PreToolUse | Bash | block | Detects and blocks dangerous shell commands |
| `protect-files.sh` | PreToolUse | Edit\|Write\|NotebookEdit | block | Blocks writes to secret and toolchain config files |
| `scan-harness.sh` | PreToolUse | Skill | warn/block | Self-SAST of the harness (secret leakage, constitution tampering, deny-rule weakening) |
| `scan-harness.sh` | **UserPromptExpansion** | `*` (slash commands) | warn/block | Typing `/skill` directly bypasses PreToolUse(Skill), so the same check (high-risk skill suppression, self-SAST) runs before the expansion |
| `scan-harness.sh filechanged` | **FileChanged** | `constitution.md` | warn + log | Detects changes to `constitution.md` made outside the Edit tool (`sed -i`, an external editor) through the file watcher (cannot block; `testreport/config-changes/`) |
| `user-prompt-submit.sh` | UserPromptSubmit | — | warn/block | Detects secret patterns |
| `session-start.sh` | SessionStart | `startup` etc. / **`compact`** | warn + context | At startup checks project-config.md / docs/ / settings.local.json and injects PROGRESS.md; right after a compact re-injects the core rules immediately |
| `session-end.sh` | SessionEnd | — | observe | Appends a session summary to `output/reports/sessions/<date>.md` |
| `commit-quality.sh` | PostToolUse | Bash (`if: Bash(git commit *)`) | warn | Conventional Commits format check and secret detection. `if` spawns it only on git commit |
| `console-warn.sh` | PostToolUse | Edit\|Write | warn | Detects leftover debug statements (console.log etc.) |
| `verify-gate.sh track` | PostToolUse | Bash\|Edit\|Write\|NotebookEdit | observe | Records timestamps of source edits / verification commands (`testreport/.verify/`) |
| `verify-gate.sh gate` | **Stop** | — | warn/send back | If no verification command ran after the last edit: standard = warning / strict = sent back once (verification gate) |
| `verify-gate.sh task` | **TaskCompleted** | — | warn/refuse | Same condition on the completion mark: standard = warning / strict = exit 2 refuses it (mechanical enforcement of quality gate ③) |
| `verify-gate.sh teammate` | **TeammateIdle** | — | warn/refuse | Same condition right before an agent-team teammate goes idle (strict = exit 2 keeps it working) |
| `permission-denied-log.sh` | **PermissionDenied** | `*` | observe | Records auto mode classifier denials (`testreport/denials/`) |
| `permission-denied-log.sh request` | **PermissionRequest** | `*` | observe | Records calls that raised a permission dialog, or were auto-denied in an unattended run (dontAsk, background subagents), as `kind=request`. Input for new allow rules |
| `config-guard.sh` | **ConfigChange** | `*` | log + block | Logs settings changes and stops `disableAllHooks`, a deny list in local settings, or the removal of a Layer 1 blocking hook from applying to the session (`testreport/config-changes/`) |
| `scope-guard.sh <scope>` | PreToolUse (**agent frontmatter**) | Edit\|Write\|NotebookEdit | block | Stops out-of-scope writes by write-capable subagents (doc-synchronizer=docs / doc-writer=output / test-writer=tests) |
| `post-failure-log.sh` | **PostToolUseFailure** | `*` | observe | Structured error log on tool failure (`testreport/failures/`) |
| `post-failure-log.sh` | **StopFailure** | `*` | observe | Records a turn ended by an API error (rate_limit / overloaded / billing_error ...) as `tool=api:<error>` |
| `instructions-log.sh` | **InstructionsLoaded** | `*` | observe | Records each CLAUDE.md / rule entering the context with its `load_reason` (`testreport/instructions/`). The measured input for the rule inventory |
| `subagent-audit.sh` | **SubagentStart** | — | observe + context | Logs the launch and injects guardrails into the subagent |
| `subagent-audit.sh` | SubagentStop | — | observe | Logs completion (`testreport/agents/`) |
| `pre-compact-backup.sh` | PreCompact | — | observe | Backs up the transcript before compaction (`testreport/transcripts/`) |
| `post-compact-restore.sh` | **PostCompact** | — | observe | Preserves the post-compact summary under `testreport/transcripts/` |
| `notify-claude.sh` | Stop / Notification / **StopFailure** | — | notify (async) | External notification on completion, input needed, and API-error stops (ntfy) |

### Fail-closed hooks (`onFailure: block`)

Hooks are **fail-open** by default: when the script cannot start (wrong path, missing execute bit), times out, or exits with an
unexpected code, the action goes ahead. A broken safety hook is the same as no hook. The four blocking hooks carry
`onFailure: "block"` (v2.1.295), so a failure of the hook itself stops the action (fail-closed):

| Hook | Registered in | On hook failure |
| ---- | ------------- | --------------- |
| `safety-check.sh` / `protect-files.sh` | `settings.json` PreToolUse | the tool call is blocked |
| `config-guard.sh` | `settings.json` ConfigChange | the settings change is not applied to the session |
| `scope-guard.sh` | agent frontmatter (3 agents) | the subagent's write is blocked |

The scripts' internal fail-open (exit 0 when jq is missing or parsing fails) stays. `onFailure` covers "the hook could not run";
"the hook ran but could not decide" still lets the work continue. Observation and warning hooks do not get it (a failed log is
no reason to stop work). `validate-harness.sh` warns when any of the four lacks `onFailure: block`.

### Compaction recovery (the SessionStart `compact` source)

Countermeasure for instructions fading after a context compact (pitfalls #21):

```text
PreCompact   → pre-compact-backup.sh   saves the transcript to testreport/transcripts/
PostCompact  → post-compact-restore.sh preserves the post-compact summary under testreport/transcripts/ (side effect only)
SessionStart → session-start.sh        on source == "compact", re-injects the core rules and the head of
  (compact)                            PROGRESS.md into the compacted context right away via additionalContext
```

> **Why SessionStart**: per the official spec, `PostCompact` has **no decision control at all**
> (it cannot even return `additionalContext`) and is a side-effect-only event. The official
> re-injection pattern is a `SessionStart` hook with the `compact` matcher, whose output is added
> to the compacted context without waiting for the next prompt. The root CLAUDE.md, AGENTS.md and
> rules without `paths:` are re-injected from disk automatically; rules with `paths:` and skill
> bodies (capped at 5,000 tokens per skill) fade.

> **Idle compaction** (v2.1.299+): a conversation over 200K tokens left idle for about 54 minutes is compacted before its
> prompt cache expires. Update PROGRESS.md before stepping away and the re-injection above works the same way when you return.
> Turn it off with `"idleCompaction": false`.

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
- strict sends Claude back only once. Claude Code itself overrides a Stop / SubagentStop hook after 8 consecutive blocks
  (`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`; `0` removes the cap)
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
- Routines (`/schedule`) run at a minimum interval of one hour and without permission prompts (write tools of included connectors run unconfirmed).
  Include the fewest repositories, connectors and environment; a green status is not task success, so read the transcript

### Control inventory (against harness rot)

Every harness component encodes one assumption about what the model cannot yet do on its own. As model generations advance the
assumptions go stale, and leftover instructions not only cost context but contradict each other and stop being followed.
`/harness-refine` Round 0 takes this inventory:

| Kind | Evidence | Pruning rule |
| ---- | -------- | ------------ |
| Instructions (CLAUDE.md / rules / skill bodies) | `testreport/instructions/` (load record), `/doctor prompt-audit` (older-model phrasing, dangling references, contradictions), `/skill-doctor` (unused skills and listing cost) | Delete a `paths:` rule that neither loaded nor fired in the last N sessions, and any line whose removal changes nothing |
| Enforcement (hooks / deny / ask) | `testreport/denials/` (denials and dialogs), `testreport/config-changes/`, `testreport/failures/` | **Keep even when it never fires** (safety and irreversible-operation rules only; delete hooks that encode preferences). Record the originating pitfall number or incident here; remove only what a spec change made meaningless |
| Verification (verify-gate / evals) | pass rates under `testreport/evals/`, `validate-harness.sh --hooks` | Re-run the same evals on a new model; if they hold, cut the redundant verification prose in the instructions |

Rules: every enforcement has an "incident → control" record (its `pitfalls.md` number). Every instruction is re-judged by
"would removing it make Claude make mistakes?". After a model update, remove one component at a time and confirm with evals
(removing several at once hides the cause).

Official rule of thumb: use enforcement (hooks / deny) only for a rule with zero exceptions, and delete hooks that encode a
preference so Claude decides again. This template has 5 blocking hooks plus the deny / ask rules; everything else observes or
notifies. Near forty enforced items, most are probably preferences.

### Organization rollout (managed settings / OpenTelemetry)

Use managed settings to pin policy that individuals cannot override. The bundled
`.claude/managed-settings.example.json` shows deny rules / `disableBypassPermissionsMode` / sandbox /
OpenTelemetry (`CLAUDE_CODE_ENABLE_TELEMETRY` + an OTLP exporter) / `requiredMinimumVersion`.
This template's `testreport/` logs are machine-local, so aggregate team-wide usage and skill adoption through OTel
(`OTEL_LOG_TOOL_DETAILS=1` records skill names so unused skills can be identified).

- **Cross-session messaging**: another session on the same machine can deliver text that reads like an instruction. `settings.json`
  sets `isolatePeerMachines: true` (confirm before any message leaves the machine; honored from project settings). In CI and
  unattended runs stop both directions with `crossSessionInbound: "refuse"` plus `permissions.deny` on `SendMessage` / `ListAgents`
  (example in `managed-settings.example.json`)
- **Guardrail counts over OpenTelemetry**: `claude_code.safety_event` (v2.1.307) is no longer sent since v2.1.312 (the docs still
  describe it). Take fleet-wide hit rates from `claude_code.tool_decision` (`decision: reject`, `source: config | hook | user`,
  auto mode verdicts in `classifier_verdict`) and find which rule fired in this template's `testreport/denials/` /
  `config-changes/` / `failures/` JSONL
- **Agent memory is code under review**: `memory: project` learnings are committed under `.claude/agent-memory/<name>/` and later
  subagents read them as instructions. Treat a PR that touches that directory as an instruction change (prompt injection via memory)

### Hook profile switch

`BLUEPRINT_HOOK_PROFILE` switches behavior
(honored by `user-prompt-submit.sh`, `session-end.sh`, `scan-harness.sh`, `post-compact-restore.sh`, `subagent-audit.sh`,
`verify-gate.sh`, `permission-denied-log.sh`, `config-guard.sh`, `instructions-log.sh`; only `minimal` turns `config-guard.sh` off, standard and strict behave the same):

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
- Extra handler fields: `if` (narrow the trigger with permission-rule syntax, e.g. `"if": "Bash(git *)"`; tool events only and best-effort, so never for safety) /
  `once` (removed after the first success; skill-frontmatter hooks only) / `asyncRewake` (runs in the background and wakes Claude on exit 2) / `args` (exec form) / `statusMessage` /
  `onFailure` (`block` stops the action when the hook itself fails; see "Fail-closed hooks" above)

### Decision control by event (excerpt)

| Event | Control |
| ----- | ------- |
| `PreToolUse` | `hookSpecificOutput.permissionDecision` (allow / deny / ask / defer) |
| `UserPromptSubmit` / `PostToolUse` / `PostToolUseFailure` / `Stop` / `SubagentStop` / `PreCompact` | Top-level `decision: "block"` + `reason` |
| `SessionStart` / `Setup` / `SubagentStart` | **Context only** (`additionalContext`). Cannot block |
| `ConfigChange` | Top-level `decision: "block"` or exit 2 stops the change from applying (not for `policy_settings`; the block message is shown to nobody) |
| `UserPromptExpansion` / `TeammateIdle` / `TaskCompleted` | exit 2 blocks (cancels the expansion / refuses going idle / refuses the completion mark). `UserPromptExpansion` also passes plain-text stdout as context |
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
| `PreModelSwitch` / `PostModelSwitch` | Before / after a model switch via `/model` etc. | Confirming or auditing switches to expensive models (a switch invalidates the cache) |
| `PostToolBatch` | A parallel tool batch completes | Per-batch verification |
| `TaskCreated` | Task created (on Claude 5-family models the Task tools need `CLAUDE_CODE_ENABLE_TODO_TOOLS=1`, which this template sets) | Enforcing task naming |
| `WorktreeCreate` / `WorktreeRemove` | Worktree created / removed | Setting up isolated environments |
| `CwdChanged` / `DirectoryAdded` | Working directory changed or added | Auditing environment drift (reloading direnv etc.) |
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

## Prohibited operations (AGENTS.md / CLAUDE.md + safety-check.sh)

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
   ├─ UserPromptExpansion: scan-harness (direct /skill input)
   ├─ PostToolUse: commit-quality / console-warn / verify-gate (track)
   ├─ PostToolUseFailure / StopFailure: post-failure-log
   ├─ PermissionRequest / PermissionDenied: permission-denied-log
   ├─ ConfigChange: config-guard (refuses to apply settings changes that weaken the guardrails)
   ├─ FileChanged (constitution.md): scan-harness (detects on-disk tampering)
   ├─ UserPromptSubmit: user-prompt-submit
   ├─ SessionStart / SessionEnd / InstructionsLoaded: session-start / session-end / instructions-log
   ├─ SubagentStart / SubagentStop: subagent-audit
   ├─ PreCompact / PostCompact: pre-compact-backup / post-compact-restore
   ├─ Stop / TaskCompleted / TeammateIdle: verify-gate (verification gate)
   └─ Stop / StopFailure / Notification: notify-claude (async)
  ↓
Layer 2: Deny / Ask rules (settings.json — shared by the team)
   ├─ deny: unconditionally blocks destructive operations and secret reads
   └─ ask : always confirms outbound and irreversible operations, in any permission mode
  ↓ active in normal mode
Layer 3: Allow rules (settings.local.json — personal)
  ↓ active only in normal mode
meta : self-SAST (scan-harness.sh detects constitution hash drift, secret leakage, deny weakening)
env  : CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1 (no agent nesting = constitution ④) /
       CLAUDE_CODE_ENABLE_TODO_TOOLS=1 (prerequisite of the TaskCompleted gate; absent by default on Claude 5-family models)
```

> Layer 1 contains blocking hooks (`safety-check.sh`, `protect-files.sh`, `scan-harness.sh`, `config-guard.sh`, `scope-guard.sh`;
> fail-closed through `onFailure: block`), observation hooks (`subagent-audit.sh`, `pre-compact-backup.sh`, `post-compact-restore.sh`,
> `post-failure-log.sh`, `permission-denied-log.sh`, `instructions-log.sh`, `session-end.sh`), warning hooks (`commit-quality.sh`,
> `console-warn.sh`, `user-prompt-submit.sh`) and notification hooks (`notify-claude.sh`).
> The observation and notification hooks never block, but they keep recording and
> notifying under `--dangerously-skip-permissions`, which makes them part of the defense.

- Layer 0 is off by default. Enable it for air-gapped work or projects that execute external code
- Layer 1 is always active and is the most reliable layer
- Layer 2 applies automatically in normal mode; `ask` also applies under `acceptEdits` / `bypassPermissions`
- Optional Layer 2 reinforcement: `permissions.blockReadsOutsideWorkingDirectories` and `blockWritesOutsideWorkingDirectories`
  (v2.1.314) refuse reads and writes outside the working directories in every permission mode (a `true` cannot be lifted by
  another settings file). Example in `managed-settings.example.json`; to try it personally, see `_comment_working_dir_fence` in
  `settings.local.json.template`
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

There is **no built-in credential deny list** (`~/.aws/credentials` and `~/.ssh` are readable by default). Block them explicitly with `sandbox.credentials`:

```json
{
  "sandbox": {
    "credentials": {
      "files": [{ "path": "~/.aws/credentials", "mode": "deny" }, { "path": "~/.ssh", "mode": "deny" }],
      "envVars": [{ "name": "GITHUB_TOKEN", "mode": "deny" }, { "name": "NPM_TOKEN", "mode": "deny" }]
    }
  }
}
```

To refuse reads outside the working directories in every permission mode, set `permissions.blockReadsOutsideWorkingDirectories: true` (honored in project settings).
See `.claude/managed-settings.example.json` for an org-wide example.
