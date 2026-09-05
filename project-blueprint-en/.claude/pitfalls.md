# Pitfalls — Common Failure Patterns in Claude Code Collaborative Development

Frequent failure cases and mitigations for AI-assisted development.
Project-specific pitfalls discovered during work should be added to `project-config.md` §11 or `docs/development-patterns.md`.
This file contains **universal, template-wide pitfalls** only.

## Operational pitfalls

### 1. CLAUDE.md bloat

| Field | Content |
| ----- | ------- |
| **Symptom** | As CLAUDE.md grows, Claude stops following earlier instructions |
| **Cause** | Above ~200 lines, important rules get buried in low-priority noise. Token cost also grows per session |
| **Mitigation** | Keep CLAUDE.md to cross-cutting rules only. Split details into skills, `docs/`, or `.claude/rules/`. Use concrete `@import` paths like `@docs/*.md` / `@.claude/*.md` (root-relative) |

### 2. Subagents don't get the parent's skills automatically (CLAUDE.md / rules ARE inherited)

| Field | Content |
| ----- | ------- |
| **Symptom** | A subagent doesn't know the procedure of a skill the parent session was using. Conversely, assuming "CLAUDE.md isn't read", the agent body restates every rule and wastes tokens |
| **Cause** | Official spec: custom subagents **inherit** the CLAUDE.md hierarchy (including `.claude/rules/`) and the git status (only the built-in `Explore` / `Plan` skip them). What is not inherited: **skill bodies, conversation history, the parent's auto memory**. Only skills listed in the `skills:` frontmatter are preloaded in full |
| **Mitigation** | List required skills in the agent's `skills:`. Pass premises decided in conversation explicitly in the `prompt`. No need to restate CLAUDE.md |

### 3. `~/.claude/skills/` must be flat

| Field | Content |
| ----- | ------- |
| **Symptom** | `~/.claude/skills/category/my-skill/SKILL.md` isn't discovered |
| **Cause** | User-level skill scan is 1-level only; not recursive |
| **Mitigation** | Place as `~/.claude/skills/<skill-name>/SKILL.md` (flat). Project-level `.claude/skills/` allows nesting |

### 4. Token explosion from full-content injection

| Field | Content |
| ----- | ------- |
| **Symptom** | Skill / agent runs slow, cost is 10× expected |
| **Cause** | A skill body or agent prompt is reading huge files with `Read` in full |
| **Mitigation** | Narrow with Grep first, then Read. Use Read's `limit`/`offset`. Split large docs into `@docs/...` imports |

### 5. Hook exit code confusion (1 vs 2)

| Field | Content |
| ----- | ------- |
| **Symptom** | Dangerous commands slip through even though the hook "should" block |
| **Cause** | Hook returns `exit 1`, but Claude Code treats only `exit 2` as a block |
| **Mitigation** | Always `exit 2` for block hooks (stderr is returned to Claude as the block reason). **`exit 0` + stderr does not reach anyone** — on exit 0 stderr only goes to the debug log. Emit warnings as `{"hookSpecificOutput":{"additionalContext":"..."}}` on stdout. See `safety-check.sh` (block) and `console-warn.sh` (warn) for references |

### 6. ANTHROPIC_API_KEY scope too broad — billing accident

| Field | Content |
| ----- | ------- |
| **Symptom** | Unintended large API consumption causing high charges ($100s-$1000s) |
| **Cause** | Unlimited API keys used in GitHub Actions / CI. Runaway PR creation or autonomous loops |
| **Mitigation** | Set monthly / daily spend limits on the API key. Configure `max_turns` / `timeout_minutes` for `claude-code-action`. Use dual exit gates for autonomous loops |

## Security / permission pitfalls

### 7. Misunderstanding the MCP trust model

| Field | Content |
| ----- | ------- |
| **Symptom** | Secrets leak through an MCP server that ran arbitrary commands |
| **Cause** | MCP servers have local arbitrary-command privileges. Adding a malicious one to `.mcp.json` is dangerous |
| **Mitigation** | Use only official / trusted sources. Inject credentials via env vars (`${VAR}`). `permissions.deny` unknown MCPs and `permissions.allow` the specific ones |

### 8. Accidentally sharing `.claude/settings.local.json`

| Field | Content |
| ----- | ------- |
| **Symptom** | A personal allow list gets shared with the team, unexpectedly permitting commands in other environments |
| **Cause** | `settings.local.json` isn't in `.gitignore`, or it was committed before being listed |
| **Mitigation** | Always include it in `.gitignore`. Team-shared rules go in `settings.json` instead |

### 9. Crossing `input/` ↔ `output/` boundaries

| Field | Content |
| ----- | ------- |
| **Symptom** | AI rewrites `input/requirements/REQ_*.md`, or a human edits `output/reports/` by hand |
| **Cause** | A session doesn't know the input/output separation rules |
| **Mitigation** | Carry CLAUDE.md's "Document Management Policy" in every agent prompt. Scope write permissions via the agent's `tools` field |

### 10. Committing `testreport/`

| Field | Content |
| ----- | ------- |
| **Symptom** | Repository bloats with coverage HTML or huge JSON files |
| **Cause** | `setup.sh` updates `.gitignore`, but the project committed outputs before the setup |
| **Mitigation** | Ensure `.gitignore` includes `testreport/`. If history has mixed outputs, use `git filter-repo` to prune |

## Skill / team operation pitfalls

### 11. Skill `description` too long → ambiguous invocation

| Field | Content |
| ----- | ------- |
| **Symptom** | Skills trigger at the wrong time or fail to trigger |
| **Cause** | `description` over ~500 chars degrades Claude's matching precision |
| **Mitigation** | Keep to 1-2 sentences, ~100 chars. Use "Use when ..." phrasing |

### 12. Shared-layer conflicts with parallel teams

| Field | Content |
| ----- | ------- |
| **Symptom** | `TEAM_PJM --parallel` runs multiple Bundles that collide on `src/shared/` |
| **Cause** | Shared-layer separation was skipped when identifying Feature Bundles |
| **Mitigation** | Follow the "Feature Bundle rules" in `TEAM_PJM.md`. Handle shared-layer changes sequentially in Phase 4b |

### 13. Duplicate updates to `project-config.md` §11 and `docs/development-patterns.md`

| Field | Content |
| ----- | ------- |
| **Symptom** | Pitfalls get written to two files; it's unclear which is authoritative |
| **Cause** | Ambiguous ownership. Multiple skills write the same information in different places |
| **Mitigation** | Follow CLAUDE.md's "Conflict Prevention" tables. Primary owner is `/implementing-features` |

### 14. `@` import path mistakes

| Field | Content |
| ----- | ------- |
| **Symptom** | `@.claude/pitfalls.md` can't be found; CLAUDE.md references break |
| **Cause** | `@` imports are resolved relative to the repository root (via Claude Code), not CLAUDE.md's own directory |
| **Mitigation** | Existing `@docs/*.md` / `@.claude/*.md` patterns are repo-root relative. When in doubt, verify with `ls` |

### 15. Temptation to bypass Git hooks

| Field | Content |
| ----- | ------- |
| **Symptom** | Hook fails, developer uses `--no-verify` to push through; bugs surface later |
| **Cause** | Bypassing feels faster than fixing the hook failure |
| **Mitigation** | `--no-verify` is blocked by `safety-check.sh`. When tempted, first investigate what the hook is protecting. See also CLAUDE.md §Git Operations Policy |

## Context-management pitfalls

Five high-frequency failure patterns extracted from the official best practices,
common in long-running Claude Code sessions.

### 16. Kitchen sink session (mixing unrelated tasks)

| Field | Content |
| ----- | ------- |
| **Symptom** | A single conversation flips between requirements, debugging, an unrelated investigation, and back; context bloats and instruction precision drops |
| **Cause** | History, file reads, and command output from loosely-related tasks all linger in the context window |
| **Mitigation** | Run `/clear` when the task switches. Habit-forming at the phase gates defined in `.claude/quality-gates.md` is the most effective |

### 17. Over-correction loop (correcting the same issue repeatedly)

| Field | Content |
| ----- | ------- |
| **Symptom** | The same spot is corrected 3+ times and still wrong. Failed approaches stay in context |
| **Cause** | The model retains every failed attempt, so it cannot decide which to commit to |
| **Mitigation** | After two consecutive failures, run `/clear` and re-issue the prompt with what you learned baked in. `/rewind` to a pre-failure checkpoint also works |

### 18. Bloated CLAUDE.md (instructions buried)

| Field | Content |
| ----- | ------- |
| **Symptom** | Rules in CLAUDE.md stop being followed |
| **Cause** | Above ~200 lines, low-priority instructions drown the high-priority ones (same root as #1) |
| **Mitigation** | For each line, ask "would Claude make a mistake without this?". If no, delete. Consider promoting rules into hooks. Move details into `.claude/rules/` or skills |

### 19. Trust-then-verify gap (committing without verification)

| Field | Content |
| ----- | ------- |
| **Symptom** | "Looks-like-it-works" code is approved and merged, then breaks on edge cases |
| **Cause** | Approval was granted without tests, screenshots, or other evidence |
| **Mitigation** | The `/implementing-features` skill enforces TDD. Verify UI changes with the Playwright MCP. Make "no change ships without a verification artifact" a phase-gate criterion |

### 20. Infinite exploration (unbounded investigation)

| Field | Content |
| ----- | ------- |
| **Symptom** | A "please investigate" task ends up reading 100+ files, exhausts context, and reaches no conclusion |
| **Cause** | The exploration runs in the parent session instead of a subagent |
| **Mitigation** | Delegate investigations to the `explorer` subagent (separate context, summary returned). Always bound the scope: "max 3 files" or "only under X/" |

### 21. Rules lost after compaction

| Field | Content |
| ----- | ------- |
| **Symptom** | Partway through a long session, rules stop being followed — output locations and prohibitions are forgotten |
| **Cause** | Context compaction produces a summary, and the fine-grained rules from CLAUDE.md do not survive into it |
| **Mitigation** | Save the transcript on `PreCompact`, drop a marker on `PostCompact`, and collect it on `UserPromptSubmit` to re-inject the core rules (implemented in this template). Note that `PostCompact` itself has no decision control and cannot inject context |

### 22. `Write(path)` permission rules are ignored

| Field | Content |
| ----- | ------- |
| **Symptom** | `Write(output/**)` is in `allowed-tools`, yet every write still prompts — and a warning appears at startup |
| **Cause** | File-path permissions are checked against `Edit(path)` and `Read(path)` only. Path rules for `Write` / `NotebookEdit` / `Glob` / `MultiEdit` are accepted but never consulted |
| **Mitigation** | Write `Edit(output/**)` even when what you want to permit is a Write. A `Read(path)` deny rule blocks Edit and Write on the same path too |

### 23. Assuming something was confirmed in auto mode

| Field | Content |
| ----- | ------- |
| **Symptom** | Auto mode is the default on Pro / Max / Team, so work proceeds with no permission prompts, and a boundary that relied only on "never do X" in CLAUDE.md is crossed |
| **Cause** | Auto mode routes each action through a classifier model. Prompted instructions can be lost in long sessions or through prompt injection from a file |
| **Mitigation** | Use `permissions.deny` for actions that must never run (applies before the classifier) and `permissions.ask` for actions to confirm every time (always prompts, even in auto mode). Hooks (Layer 1) stay active. The classifier also reads CLAUDE.md, so write prohibitions there too. Denials are recorded by `permission-denied-log.sh` under `testreport/denials/` |

### 24. Mid-session edits to CLAUDE.md / output styles don't apply

| Field | Content |
| ----- | ------- |
| **Symptom** | You fix CLAUDE.md or an output style during a session and nothing changes |
| **Cause** | Root / user CLAUDE.md and the output style are read once at session start. A mid-session edit neither invalidates the cache nor takes effect |
| **Mitigation** | Apply with `/clear` or a restart. Path-scoped rules and subdirectory CLAUDE.md files use the content as of their first load |

### 25. `defaultMode: auto` / `autoMode` in project settings are ignored

| Field | Content |
| ----- | ------- |
| **Symptom** | `"permissions": {"defaultMode": "auto"}` or `autoMode.environment` in `.claude/settings.json` has no effect |
| **Cause** | Official spec: `auto` / `bypassPermissions` as `defaultMode`, and the `autoMode` block, are not read from project / local settings (prevents privilege escalation through a checked-in repo) |
| **Mitigation** | Put them in your personal `~/.claude/settings.json` or managed settings. `/auto-mode-setup` drafts them. Share only `deny` / `ask` (those do work in project settings) |

### 26. A skill with the same name overrides a bundled skill

| Field | Content |
| ----- | ------- |
| **Symptom** | Typing `/code-review` runs this template's skill instead of the bundled diff bug review (or you expected the opposite) |
| **Cause** | Project / user skills override a bundled skill with the same name. The bundled alias (`/review`) is not overridden |
| **Mitigation** | State the override explicitly in the skill (this template does). Use `/review` when you want the bundled fresh-subagent bug hunt |

### 27. Stop hook loops / forced end after 8 blocks

| Field | Content |
| ----- | ------- |
| **Symptom** | A Stop hook that keeps sending Claude back to "run the tests" repeats the same block, or Claude Code force-ends the turn on the 8th |
| **Cause** | A Stop hook re-fires after every block. Blocking without checking `stop_hook_active: true` reacts to its own block again. Per the official spec the hook is overridden after 8 consecutive blocks |
| **Mitigation** | Always pass when `stop_hook_active` is true (block only once). Also pass when `background_tasks` is non-empty (paused, not finished). This template's `verify-gate.sh` follows this contract |

## Recommended session-management commands

| Scenario | Command | Effect |
| -------- | ------- | ------ |
| Switching tasks | `/clear` | Fully reset context. The strongest context-compression lever |
| Roll back exploration | `/rewind` or `Esc Esc` | Restore conversation/code to a pre-failure checkpoint |
| Partial compaction | `/compact <focus>` | Summarize while keeping a specific topic |
| Side question | `/btw <q>` | Asks without entering history (overlay display) |
| Parallel work | `claude --continue` in another terminal | Writer / Reviewer multi-session pattern |

## Future expansion candidates (out of scope)

The following are not in the current template but under consideration:

- **Dedicated `/bug-fix` skill**: Pimzino-style Report → Analyze → Fix → Verify pipeline
- **EARS-format requirements**: Introduce gotalab/cc-sdd style Kiro spec-driven approach in `/prd`
- **`brief.md` artifact**: Add a Phase 0 scope summary for session resumption
- **Scale-adaptive teams**: BMAD-METHOD-style XS/S/M/L variants of `TEAM_*.md` (currently fixed)
- **`monitors/` / `bin/`**: Bundle background watchers and PATH-auto-extended scripts in the plugin (2026 spec)
- **Standardized EnterWorktree**: Auto-worktree on `/security-scan` / `/refactoring` entry

> Already-ingested features (plugin packaging / learnings / constitution / `/brainstorm` /
> the 3 new hooks, etc.) are noted at the top of the root `README-en.md`. This file's
> charter is "failure-pattern catalog", so the implemented-feature list does not live here.
