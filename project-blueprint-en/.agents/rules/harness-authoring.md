---
paths:
  - ".agents/**/*.md"
  - ".agents/hooks/**"
  - ".claude/**/*.md"
  - ".claude/**/*.json"
  - ".claude/workflows/**"
  - ".codex/**"
  - "CLAUDE.md"
  - "AGENTS.md"
---
# Harness Authoring Conventions — how to write CLAUDE.md / AGENTS.md / skills / agents / rules / hooks / workflows

> **path-specific rule**: loads only when editing the harness's own files.
> Sources: Anthropic official docs (best-practices / memory / skills / sub-agents / hooks / workflows / skill authoring best practices / the Claude 5-family prompting guides) and agentskills.io.

## Common (writing Markdown)

- Structure with headings and bullets. Put parallel data in tables. Don't explain in paragraphs
- Write concretely enough to verify ("2-space indentation", not "format properly"; "run `npm test`", not "test your changes")
- One term per concept. Never call the same thing by different names
- Use **bold** only on the one line that truly must hold. Overuse makes it ineffective (for all-caps warning words, see the table below)
- Don't keep contradicting rules in different files. When you find one, delete the other
- Give each rule its reason ("don't X because Y", not "don't X"). Claude 5-family models generalize from the reason, and an absolute rule without one is the first to be dropped when rules conflict
- Reserve absolute rules (prohibitions) for safety and irreversible operations. Describe the desired state for everything else ("match the surrounding comment density", not "never write comments")
- To merely mention a path, use a code span. A bare `@path` at the start of a line is read as a load instruction
- Put maintainer notes in block HTML comments (stripped from context in CLAUDE.md)
- Use `/` as the only path separator

## Don't carry over phrasing written for older models (official best-practices "What you can stop doing")

| Don't write | Why, and what to do instead |
| ----------- | --------------------------- |
| `IMPORTANT` / `CRITICAL` / `YOU MUST` / all-caps emphasis | Current models follow a plainly worded line, and emphasis makes them over-apply the rule. Turn a rule with no exceptions into a hook / deny rule; fix a line that gets lost by shortening the file |
| `think hard` / `think harder` / `be thorough` | Effort controls reasoning (`project-config.md` §13.1b). For one deeper turn, use `ultrathink` |
| "keep going", "don't be lazy", "loop until done" | These cause over-work. Hand over a pass/fail check instead, and enforce unattended runs with `/goal` or a Stop hook |
| "use subagents to protect your context", "delegate for a better answer" | With a 1M window, running out is rare, and delegating the same task does not improve the answer. Use subagents only for parallelism, isolating long output, an independent reviewer that hasn't seen the reasoning, or restricted tools |
| Architecture or directory layout in CLAUDE.md | Claude reads the repo. Write only what isn't in it (check commands, misleading spots, decisions made outside the repo, anything corrected twice) |

`validate-harness.sh` flags `IMPORTANT` / `YOU MUST` and the `think hard` family with a WARN (`CRITICAL` is excluded because it cannot be told apart from a severity label).

## Enforce or leave to Claude (deterministic / non-deterministic)

- Default to letting Claude decide (CLAUDE.md, skills, prompts). Current models judge whether a guideline fits the code in front of them
- Enforce only what must *always* (or *never*) happen: hooks, deny rules, managed settings, CI, branch protection
- A line Claude still misses after you add emphasis belongs in a hook. Conversely, delete hooks that encode a preference and let Claude decide

## Where content belongs

| What you want to write | Where it goes |
| ---------------------- | ------------- |
| Rules needed every session that hold for any agent (principles, quality standards, Git, security) | `AGENTS.md` |
| What Claude Code and Codex each own, which auxiliary agents are used and their write scopes (a human decision) | `project-config.md` §13.7 |
| Claude Code-specific facts needed every session (skills, teams, hooks, permissions) | `CLAUDE.md` (under 200 lines together with `AGENTS.md`) |
| Conventions that apply only to certain paths | `.agents/rules/*.md` + `paths:` |
| Procedures, checklists, long references | a skill (procedure in the body, detail in `references/`) |
| "Always do X", "never do Y" | a hook (`.agents/hooks/`) and a deny rule: `permissions.deny` for Claude Code, `.codex/rules/` and the permission profile for Codex (enforcement, not instruction) |
| Context-heavy investigation, independent review | a subagent |
| Exhaustive or adversarial work across dozens of agents | `.claude/workflows/*.js` |

## Sharing between the two agents (one source)

| What | Source | Claude Code | Codex |
| ---- | ------ | ----------- | ----- |
| Skills, rules | `.agents/skills/` `.agents/rules/` | Links in `.claude/skills/` `.claude/rules/` (`setup.sh --relink`) | Reads `.agents/skills/` directly; reads rules on the conditions in `AGENTS.md` |
| Hook scripts | `.agents/hooks/*.sh` | Registered in `.claude/settings.json` | Registered in `.codex/hooks.json` (through `lib/codex-adapter.sh`) |
| Subagents | `.claude/agents/*.md` | Read as is | `.codex/agents/*.toml` (generated by `python3 scripts/sync_codex_agents.py`; do not edit) |
| Deny / ask | — | `permissions.deny` / `ask` | `.codex/rules/default.rules` and the permission profile in `.codex/config.toml` |

- Do not stop at one side. After adding a skill, a hook or a deny rule, state how the other agent handles it (the counterpart, or why there is none)
- Write `/name` in skill bodies (Codex reads it as `$name`; `AGENTS.md` says so). Where a step relies on a Claude Code-only feature, add one line with the Codex substitute
- Write hooks against Claude Code's input shape only (`tool_input.file_path` / `tool_input.command`). The adapter converts Codex's `apply_patch`. Read the project root from `BLUEPRINT_PROJECT_DIR`, then `CLAUDE_PROJECT_DIR`
- A skill with `disable-model-invocation: true` needs `agents/openai.yaml` (`policy.allow_implicit_invocation: false`). Without it Codex invokes the skill implicitly from the prompt
- Keep deny / ask and the rules, and the `Read()` deny list and the permission profile, at the same intent (the validator reports gaps as ERROR)

## CLAUDE.md

- Judge each line by "would removing it make Claude make mistakes?" Omit what code shows and common knowledge
- `@import` targets load in full every session. An import organizes a file but does not reduce its context cost. Import only files needed every time and name the rest as "path — when to read it"
- With any CLAUDE.md present, Claude Code does not read `AGENTS.md` directly. Keep the `@AGENTS.md` line at the top of CLAUDE.md and never duplicate shared rules into CLAUDE.md. The exception is safety prohibitions, which also go in CLAUDE.md itself so they reach the auto mode classifier
- Do not put a line-start `@` in `AGENTS.md` (agents other than Claude Code do not interpret imports). Name files to read in the body instead

## Skills (SKILL.md)

- `description` = what it does + when to use it (the words users actually say). Third person, key use case first, at most 1024 characters (aim for 300)
  - The listing budget is 1% of context; on overflow, the least-used skills lose their descriptions. Keep constraints and argument help in the body and `argument-hint`
- The body stays in context after invocation. Skip explanations Claude already knows and state what to do in the imperative. Under 500 lines
- Put the most important instructions at the top of the body. After compaction each skill is re-injected truncated to its first 5,000 tokens
- Number steps only when the order matters. Never write "think carefully", "show your reasoning" or "double-check to be safe": on Claude 5-family models these cause over-verification and reasoning disclosure
- Never tell a review skill "only report the serious ones" or "be conservative". Have it report everything, then narrow by severity and by what must be acted on
- Give a skill `paths:` when it should be a candidate only while working under certain paths (saves listing budget)
- **Never put `@path` at the start of a line**. In a local skill, that file is attached in full at invocation.
  List references as pairs of path and reading condition, e.g. "`.agents/pitfalls.md` — when a known failure pattern may apply"
- Split detail into `references/` and link each one directly from SKILL.md (one level deep). Never chain from one reference file to another
- Put a table of contents at the top of any reference file longer than 100 lines
- Don't write date-stamped statements. Move things that change into an "old patterns" section
- Turn complex procedures into a copyable checklist and spell out the "validate → fix → re-validate" loop
- Show output formats as templates. When style matters, include 2-3 input/output example pairs
- Add `disable-model-invocation: true` to workflows with side effects (push, deploy)
- After editing a skill, check `/skill-doctor` (listing cost and usage). After each model update, run `/doctor prompt-audit` for older-model phrasing, dangling references, and contradictions

## Skill evals (eval-first)

- Give every skill an `evals/evals.json` (agentskills.io format). Start with 2-3 cases
  - `prompt` is a realistic request (file paths, casual phrasing), `expected_output` describes success, `assertions` are statements verifiable from the output
  - Make one case typical and one a boundary (ambiguous input, or a request that invites a prohibited action)
- Run them with the saved workflow `/skill-eval skill=<name>`: the same prompt runs with and without the skill, and an agent that did not produce the output grades the assertions
  - Output: `testreport/evals/<skill>/iteration-N/` (gitignored)
  - Where dynamic workflows are unavailable, the skill-creator plugin (`/plugin install skill-creator@claude-plugins-official`) runs the same `evals.json`
  - When distributing as a plugin, `claude plugin eval` (a separate format) can gate CI
- After changing a skill, rerun the same evals and keep evidence that the pass rate did not drop
- Existing cases are regression evals (keep the pass rate near 100%). Start new hard cases at a low pass rate to drive improvement, and promote them to the regression set once stable

## Agents (.claude/agents/*.md)

- `description` states the delegation condition in 1-2 sentences. Keep `tools` minimal
- For a write-capable agent, register `scope-guard.sh <docs|output|tests>` under `hooks.PreToolUse` in the frontmatter to enforce the write scope
- Never list `Agent` in an agent's `tools` (constitution ④). Nesting is refused mechanically by the env `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` in `settings.json`; put parallel fan-out in a workflow
- Give a read-only agent that needs none of the CLAUDE.md rules `omitClaudeMd: true` to cut its startup cost (never on a write-capable agent)
- For the spec check right before completion, hand `verifier` (read-only, fresh context) only the diff and the spec. Never use a subagent for mid-implementation re-checks (over-verification)

## Hooks (settings.json)

- On tool events (PreToolUse / PostToolUse / PostToolUseFailure / PermissionRequest / PermissionDenied), narrow a hook with `if` (e.g. `"if": "Bash(git commit *)"`). It is best-effort, so safety checks stay in `permissions.deny` and in hooks on the whole matcher
- Re-inject context after compaction from the SessionStart hook with the `compact` source (PostCompact cannot inject context)
- Rules with `paths:` dissolve into the compaction summary. A rule that must always hold goes in CLAUDE.md or in a rule without `paths:`
- Give blocking hooks (the safety devices doubled up with deny rules) `onFailure: block`. Without it, an action goes through whenever the hook cannot start
- Typing `/skill` directly bypasses PreToolUse(Skill). Register the same script on `UserPromptExpansion` for any per-skill suppression
- Use a hook only for a rule with zero exceptions. Delete hooks that encode a preference (naming, style) and move them back to CLAUDE.md prose. Keep the enforced set small (near forty, most are preferences)

## Workflows (.claude/workflows/*.js)

- The first statement is `export const meta = {...}`, written with pure literals only (no variables, function calls, or template strings)
- Match the titles in `meta.phases` with `phase()` / `{phase: ...}` in the body
- `Date.now()` / `Math.random()` / argless `new Date()` / `import` are unavailable. Let an agent obtain the time
- When you cap coverage (top N, vote counts), report what was dropped with `log()`

## After a change

In the template's source repository, `bash scripts/validate-harness.sh` machine-checks frontmatter, references, eval format, and workflow conventions.
