# Project Blueprint

AI-collaborative development environment template for Claude Code and Codex. Use either one alone, or both as equals.

Consolidate all project-specific human decisions into a **single `project-config.md` file**,
and let AI automatically generate and maintain design artifacts such as routing maps, store inventories, and data models.

---

## Minimal Start (5 minutes)

You don't need to use every section, team, or skill. **Get started in 3 steps.**

### Step 1: Copy

```bash
bash setup.sh /path/to/your-project                  # Claude Code and Codex (default)
bash setup.sh /path/to/your-project --agent claude   # Claude Code only
bash setup.sh /path/to/your-project --agent codex    # Codex only
```

> Want it even lighter? Add `--profile minimal` to install just 5 skills / 2 agents / 2 hooks (see "Profiles" below for details).

### Step 2: Fill in just 3 sections of project-config.md

```markdown
## S1. Project Basics
Project name: MyApp
Description: TODO app
Language: English

## S2. Tech Stack
- React 19 + TypeScript 5
- Vite 6

## S3. Commands
- dev: npm run dev
- test: npm run test
- build: npm run build
```

> The remaining 10 sections can be left blank — everything still works. Add them incrementally as needed.

### Step 3: Try one skill

```text
/plan Design a login feature       # Claude Code
$plan Design a login feature       # Codex
```

That's it. AI reads `project-config.md` and generates a structured design document.
The examples below use Claude Code's `/name`. Under Codex read it as `$name`.

### Scale up gradually

| When you want to... | Next step |
|---|---|
| Let AI handle everything from PRD to implementation | Add `project-config.md` S4 → `.claude/teams/TEAM_PJM.md input/requirements/REQ_001.md` |
| Get help with implementation only | `/implementing-features Add a login feature` |
| Get a code review | `/code-review src/features/auth/` |
| Run team-based quality assurance | `.claude/teams/TEAM_QA.md src/` |
| Extend AI tools by adding MCP servers | `cp .mcp.json.template .mcp.json` → fill in required MCP servers and commit (project-shared) |

> For detailed setup instructions and the full feature set, see the sections below.

---

## Setup Instructions (Detailed)

### Prerequisites

| Requirement | Used for | Check |
| --- | --- | --- |
| Claude Code 2.1.314 or later (`--agent claude` / `both`) | `onFailure: block` (2.1.295), `blockWritesOutsideWorkingDirectories` (2.1.314), enabling the Task tools via env | `claude --version` |
| Codex CLI 0.162 or later (`--agent codex` / `both`) | Hooks (`.codex/hooks.json`), permission profiles, loading `.agents/skills/` | `codex --version` |
| bash 3.2 or later + git | `setup.sh` (install and `--upgrade`), `migrate.sh`, the hooks | The stock macOS bash works |
| jq | Every hook reads and writes JSON with it (without it `safety-check.sh` skips everything but the most critical patterns) | `brew install jq` / `apt-get install jq` |
| python3 | Only `scripts/validate-harness.sh` in the template repository (not needed in the target project) | `python3 --version` |

On Windows, use WSL2 or Git Bash to provide the above. Git Bash sometimes cannot create symbolic links; `setup.sh` then falls back to copies (see "Shared core and links" below).

### Method A: One-command setup with setup.sh (recommended)

```bash
bash setup.sh /path/to/your-project
```

This single command does all of the following:
- Places `.agents/` (the shared core: skills, hooks, rules, quality gates)
- Places `.claude/` (the Claude Code adapter) and `.codex/` (the Codex adapter). `--agent` limits it to one
- Places `docs/`, `input/`, `output/`, `testreport/`, `project-config.md` (existing files are not overwritten)
- Places `AGENTS.md` (tool-agnostic rules) and `CLAUDE.md` at the project root (an existing `AGENTS.md` is kept with `AGENTS.blueprint.md` placed next to it, and an existing `CLAUDE.md` is kept with `CLAUDE.md.blueprint-new` placed next to it)
- Places `constitution.md`, `REVIEW.md` (review criteria for Claude's Code Review), `.mcp.json.template` and `.github/` (workflow templates) without overwriting existing files
- Links `.claude/skills/` and `.claude/rules/` to `.agents/`, and generates `.claude/settings.local.json` from the template (only if missing)
- Adds `testreport/` and other local state to `.gitignore`
- Backs up an existing `.agents/` `.claude/` `.codex/` to `<name>.bak/` (an existing `.bak/` is never deleted; the new backup goes to `<name>.bak.<timestamp>/`)
- Records `.agents/blueprint-manifest.txt` (installed version, agent and per-file hashes), the baseline for `--upgrade`

An installed project cannot be installed again (`setup.sh` stops, because that would push the skills you added and your edits into a backup). Use `--upgrade` to follow a new version,
`--upgrade --agent both` to add an adapter and `--relink` to refresh the links. It also stops without changing anything when `.agents`, `.claude` or `.codex` is a symbolic link,
or when the target is the template itself.

#### Agent (`--agent`)

| Value | What is installed | First step after starting |
| --- | --- | --- |
| `both` (default) | `.agents/` + `.claude/` + `.codex/` + `CLAUDE.md` | Both of the below |
| `claude` | `.agents/` + `.claude/` + `CLAUDE.md` | Start `claude` and run `/plan ...` |
| `codex` | `.agents/` + `.codex/` | Start `codex`, trust the project, review and trust the hooks with `/hooks`, then run `$plan ...` |

Codex does not read `.codex/` until the project is trusted, and does not run a hook until you trust it with `/hooks` (again after every hook update).
To add the other agent later, run `bash setup.sh <dir> --upgrade --agent both`. The mapping of safety mechanisms and their differences is in "Per-agent mapping" in `.agents/guardrails.md`.

#### Shared core and links (`--links` / `--relink`)

Skills, hooks and rules have a single source under `.agents/`. Codex reads `.agents/skills/` directly.
Claude Code reads only `.claude/skills/` and `.claude/rules/`, so `setup.sh` creates one symbolic link per entry.

| Goal | What to do |
| --- | --- |
| Add or remove a skill or a rule | Edit `.agents/skills/<name>/` or `.agents/rules/<name>.md`, then run `bash setup.sh <dir> --relink` |
| Enable a sample rule | `cp .agents/rules/language-typescript.md.example .agents/rules/language-typescript.md`, then `--relink` |
| Symbolic links are unavailable | Install with `--links copy`. Edit under `.agents/` only and apply to `.claude/` with `--relink` |

#### Profiles (staged installation)

The `--profile` option controls how many skills, agents and hooks get installed (defaults to `full`; combine it with `--agent`):

| Profile | skills | agents | hooks | teams | Use case |
| --- | --- | --- | --- | --- | --- |
| `minimal` | 5 | 2 | 2 | none | Fastest way to try it out, lightweight |
| `standard` | 18 | 9 | 18 | none | Everything but team mode |
| `full` (default) | 18 | 9 | 18 | 6 | Same as the current full setup |

```bash
bash setup.sh /path/to/your-project --profile minimal
bash setup.sh /path/to/your-project --profile standard
```

`minimal` installs only the 5 core skills (`brainstorm` / `prd` / `plan` / `implementing-features` /
`code-review`) and the minimum guardrails (`safety-check.sh` / `protect-files.sh`). Note that it also
trims safeguard hooks such as `session-start.sh`.

> This is a **separate, independent axis** from project-config.md's "minimal/recommended/full"
> guidance (which is about how much of project-config.md to fill in). For example, you can install
> with `--profile minimal` and still fill in project-config.md all the way to full.

#### Upgrading (`--upgrade`)

Brings an installed project up to a newer version of the template. It compares against `.agents/blueprint-manifest.txt` (version, profile, agent and per-file hashes) written at install time and applies only the differences.

```bash
git -C /path/to/project-blueprints pull                   # update the template
bash setup.sh /path/to/your-project --upgrade --dry-run   # show the plan only
bash setup.sh /path/to/your-project --upgrade             # apply
```

| State | Behavior |
| --- | --- |
| File untouched since install | Overwritten with the new version |
| File you modified | Left alone; the new version is placed next to it as `<path>.blueprint-new` (merge with `diff`, then delete). A leftover `.blueprint-new` with different content is kept as `.blueprint-new.old` |
| File added to the template | Added (profile pruning is preserved) |
| File you deleted locally | Not restored |
| `project-config.md` / `docs/` / `input/` / `output/` / `settings.local.json` | Never touched (a warning is printed when the template's `project-config.md` changed) |

Aggregate the observation-hook logs with `bash .agents/scripts/harness-stats.sh --since 30`.

#### Migrating from 0.x (`migrate.sh`)

A project installed with 0.x keeps its skills and hooks under `.claude/` and cannot be updated with `--upgrade`. Move it to the 1.0 layout with `migrate.sh` first.

```bash
git -C /path/to/project-blueprints pull                    # the 1.0 template (cloned with its git history)
bash migrate.sh /path/to/your-project --dry-run            # run the whole migration on a temporary copy and print the result
bash migrate.sh /path/to/your-project                      # apply (stops when there are uncommitted changes)
bash migrate.sh /path/to/your-project --rollback           # undo (possible until you delete the backup)
```

| Stage | What happens |
| --- | --- |
| Classify | Decides for each file whether it is untouched or modified. 0.x kept no install record, so the content is matched against the template's git history |
| Back up | Saves `.claude/` and every file it will change to `.blueprint-migrate-backup/` (added to `.gitignore`) |
| Move | `.claude/{skills,hooks,rules,scripts,learnings,tasks}` and `guardrails.md` / `quality-gates.md` / `pitfalls.md` go to `.agents/`. Skills and hooks you added move with them |
| Rewrite references | References such as `.claude/hooks/...` become `.agents/...` in `.agents/` `.claude/` `CLAUDE.md` `AGENTS.md` `project-config.md` `constitution.md` `docs/` `.github/` `.gitignore`. The paths of your own hooks registered in `settings.json` are fixed here too |
| Update | Calls `setup.sh --upgrade`: untouched files get the 1.0 content, the Codex adapter and other new files are added, and files you modified are kept with `<path>.blueprint-new` placed next to them |

| Option | Use |
| --- | --- |
| `--agent claude` | Migrate without adding the Codex adapter, staying Claude Code only (the default is `both`) |
| `--assume-pristine` | When you never edited the harness, or the template clone has no git history. Overwrites every file with 1.0 (your versions stay in the backup) |
| `--allow-dirty` | Proceed despite uncommitted changes (not recommended) |

A failure midway, or an interruption such as Ctrl-C, restores the pre-migration state automatically (if something cannot be restored, the backup is kept and you are told).
After migrating, review the result with `git status`, merge and delete each `.blueprint-new`, and restart Claude Code (the hook paths changed).

Old paths left in places the script does not rewrite are listed at the end (for example `package.json`, a `Makefile`, git-hook configuration or the root `README.md` calling
`.claude/scripts/` or `.claude/hooks/`). Home-directory paths such as `~/.claude/skills/` are not part of the move and are left alone.
A project whose `.claude` is a symbolic link is not migrated, to keep the link target intact (turn it into a real directory first).

### Method B: Manual copy

> A manual copy always equals `full` and writes no manifest (so `--upgrade` cannot be used later). Use Method A unless you have a specific reason.

```bash
cd /path/to/new-project
B=/path/to/project-blueprints/project-blueprint-en

cp -r "$B/.agents" .agents                      # shared core
cp -r "$B/.claude" .claude                      # if you use Claude Code
cp -r "$B/.codex" .codex                        # if you use Codex
cp -r "$B/docs" "$B/input" "$B/output" "$B/testreport" .
cp "$B/project-config.md" "$B/constitution.md" "$B/AGENTS.md" "$B/.mcp.json.template" .
cp -r "$B/.github" .github

# For Claude Code: move CLAUDE.md to the root and link skills and rules to .agents/
mv .claude/CLAUDE.md CLAUDE.md
rm -f .claude/settings.minimal.json .codex/hooks.minimal.json
mkdir -p .claude/skills .claude/rules
for d in .agents/skills/*/; do ln -s "../../.agents/skills/$(basename "$d")" ".claude/skills/$(basename "$d")"; done
for f in .agents/rules/*.md; do [ "$(basename "$f")" = README.md ] || ln -s "../../.agents/rules/$(basename "$f")" ".claude/rules/$(basename "$f")"; done
chmod +x .agents/hooks/*.sh .agents/hooks/lib/*.sh .agents/scripts/*.sh
```

### 2. Fill in project-config.md

> For a fully filled example, see [project-config.sample.md](project-config.sample.md) (a task management app used as a reference with all sections completed).

**Required sections** (minimum needed to get started):

| Section | Content |
| --- | --- |
| 1. Project Basics | Name, description, language |
| 2. Tech Stack | Frameworks and libraries in use |
| 3. Commands | Dev, test, and build commands |

**Recommended sections** (filling these in improves output quality):

| Section | Content |
| --- | --- |
| 4. Architecture | Patterns, dependency rules |
| 6. Quality Standards | Coverage target, TDD on/off |
| 7. Design System | Design guide references |
| 11. Known Pitfalls | Framework-specific gotchas (AI can also append here) |

#### Incremental Configuration Guide

You do not need to fill in every section at once. Configure incrementally based on your needs:

| Step | Sections to Fill | Skills Unlocked |
| -------- | -------------- | -------------------- |
| Minimal | S1 + S2 + S3 | `/prd`, `/plan` |
| Recommended | + S4 | `/architecture`, `/implementing-features`, all teams |
| Full | All sections | All skills (`/security-scan`, `/legal-check`, etc.) |

S6 (Quality Standards) is not a prerequisite for any skill, but it controls TDD, coverage targets, and quality gate activation.
Optional sections left blank are simply skipped during skill execution.

### 3. Add to .gitignore

> This step is not needed if you used `setup.sh` (it adds this automatically).

`testreport/` contains raw tool output (HTML/JSON/LCOV, etc.) and should not be committed to the repository:

```gitignore
# Raw tool output (AI-generated data)
testreport/
```

### 4. Customize permissions

```bash
cp .claude/settings.local.json.template .claude/settings.local.json
```

### 5. Verify setup (Hello World)

Confirm that setup completed correctly with this minimal check:

```text
# Verify with a single skill (requires project-config.md S1-S3 to be filled in)
/plan Review the initial project setup status

# If this works, project-config.md and docs/ references are resolving correctly
```

Expected behavior:

- AI reads `project-config.md` and `docs/`, then analyzes the current project structure
- Output includes an impact analysis and task breakdown
- If errors occur, check for missing file copies or unfilled sections in `project-config.md`

### 6. Initial docs/ generation (optional)

Immediately after setup, `docs/` contains only stubs (empty templates).
These are automatically generated when the following skills are run:

| File | Generation Trigger | Required project-config.md |
| -------- | ------------ | ----------------------- |
| `docs/architecture.md` | `/architecture` | S1-S4 |
| `docs/project.md` | `/architecture` or `/implementing-features` | S1-S3 (minimum); also references S5, S7, S11-S12 |
| `docs/data-model.md` | `/implementing-features` (first implementation) | S2, S5 |
| `docs/development-patterns.md` | `/implementing-features` (first implementation) | S2, S7, S11 |

> **Skills work even when docs/ contains only stubs.** Each skill falls back to
> reading `project-config.md` directly when `docs/` files are still stubs.
> When using the PJM team, these are automatically generated during Phases 2-4.

### 7. Claude Code and Codex, plus other agents (optional)

Claude Code and Codex are treated as equals. Both read `AGENTS.md` (tool-agnostic rules) and `.agents/` (skills, hooks, rules), and each can run every phase alone.
When you use both, record the owner of each phase in `project-config.md` §13.7 (for example, a different agent reviews and verifies what the other implemented).

| | Claude Code | Codex |
| --- | --- | --- |
| Instruction file | `CLAUDE.md` (imports `@AGENTS.md`) | `AGENTS.md` |
| Invoking a skill | `/name` | `$name` |
| Settings | `.claude/settings.json` | `.codex/config.toml` + `.codex/hooks.json` + `.codex/rules/` |
| Subagents | `.claude/agents/*.md` | `.codex/agents/*.toml` |
| Teams / saved workflows | Yes (`full` profile) | No (run the same skills in order) |

Any other agent reads `AGENTS.md` as an auxiliary and acts read-only unless marked `yes` in §13.7.

| Agent | How it reads `AGENTS.md` |
| --- | --- |
| Cursor | Reads it by default |
| GitHub Copilot (VS Code) | Setting `chat.useAgentsMdFile: true` |
| Gemini CLI | `{"context": {"fileName": ["AGENTS.md"]}}` in `.gemini/settings.json` (the default is `GEMINI.md`) |

> Hooks and deny rules apply to Claude Code and Codex only. If an auxiliary agent may write, also enforce the prohibitions through CI or git hooks.

---

## Quick Start (after setup)

Once setup is complete, start developing with these steps.

> Run `/auto-mode-setup` in the first session (since v2.1.283 auto mode is the default permission mode on every plan).
> It reads the project and recent sessions, drafts the environment definition for the classifier, and saves it to `~/.claude/settings.json` (project settings are not read for this).
> Inventory the instruction files with `/doctor prompt-audit` and skill costs with `/skill-doctor`.

### PJM Team (full lifecycle)

```text
1. Place a requirements memo in input/requirements/ (e.g., input/requirements/REQ_001.md)
2. Run the following in Claude Code:

   .claude/teams/TEAM_PJM.md input/requirements/REQ_001.md

   # Autonomous mode (gate approvals delegated to PJM; only the final report is presented to you)
   .claude/teams/TEAM_PJM.md input/requirements/REQ_001.md --auto

3. Review and approve the generated artifacts in output/
```

### Individual Skills (without a team)

Skills can also be used standalone. All arguments are optional:

```text
/prd input/requirements/REQ_001.md
/plan Design user authentication feature
/implementing-features output/tasks/TASK_auth.md
/code-review src/features/assignment/
```

### Specialist Teams

Teams focused on specific phases are also available. All arguments are optional:

```text
.claude/teams/TEAM_FEATURE.md output/tasks/TASK_auth.md
.claude/teams/TEAM_PLANNING.md input/requirements/REQ_001.md
.claude/teams/TEAM_QA.md src/features/assignment/
.claude/teams/TEAM_REFACTOR.md src/features/assignment/
```

---

## Concept

```text
+-----------------------------------------------------------+
|  Human Input                                              |
|                                                           |
|  input/requirements/ .... Requirements & feature memos    |
|  project-config.md ...... Tech stack, quality standards,  |
|                           policies                        |
|                                                           |
+-----------------------------+-----------------------------+
                              | AI processes (PJM Team)
                              v
+-----------------------------------------------------------+
|  AI Output (reviewed by humans)                           |
|                                                           |
|  output/prd/ ............ PRD (product requirements doc)  |
|  output/design/ ......... Architecture design docs        |
|  output/tasks/ .......... Task breakdown & impl guides    |
|  output/reports/ ........ Quality reports                 |
|    review/ .............. Code review                     |
|    test/ ................ Test results                    |
|    security/ ............ Security scan                   |
|    legal/ ............... Legal compliance check          |
|                                                           |
|  testreport/ ............ Raw tool output (.gitignore)    |
|    coverage/ ............ Unit test coverage              |
|    e2e/ ................. E2E test reports                |
|    security/ ............ Security scan raw data          |
|                                                           |
|  docs/ .................. Technical docs (auto-generated) |
|                                                           |
+-----------------------------------------------------------+

+-----------------------------------------------------------+
|  Generic (reusable as-is across projects)                 |
|                                                           |
|  AGENTS.md .................... Shared rules (any agent)  |
|  .claude/CLAUDE.md ............ Guide (Claude Code only)  |
|  .agents/hooks/ ............... Safety hooks (defense)    |
|  .agents/skills/ .............. 18 skill definitions      |
|  .claude/teams/ ............... 6 team definitions        |
|  .agents/tasks/ ............... Task instruction templates |
|  .claude/settings.json ........ Plugin & hook config      |
|  .claude/settings.local.json .. Permission settings       |
|                                                           |
+-----------------------------------------------------------+
```

---

## File Structure

```text
project-blueprint-en/
|
+-- README.md                              <-- This file
+-- setup.sh                               <-- One-command setup script (install / --upgrade / --relink)
+-- migrate.sh                             <-- Migration script from the 0.x layout (everything under .claude/) to 1.0
+-- AGENTS.md                              <-- [Generic] Tool-agnostic development rules (also read by Codex / Cursor / Copilot, etc.)
+-- project-config.md                      <-- [Human+AI] Config file (13 sections)
+-- project-config.sample.md               <-- Filled sample (task management app)
+-- constitution.md                        <-- [Human] The 7 inviolable principles (tampering detected by hash)
+-- .mcp.json.template                     <-- [Customizable] Project-shared MCP servers (rename to .mcp.json to enable)
+-- .github/                               <-- [Generic] GitHub Actions templates (drop .template to enable)
|   +-- CLAUDE_REVIEW_SETUP.md               Setup guide
|   +-- workflows/                           claude-review / claude-skills-ci / claude-scheduled-audit
|
+-- input/                                 <-- [Human] Input
|   +-- README.md                            Usage guide
|   +-- requirements/                        Requirements memo directory
|
+-- output/                                <-- [AI-generated] Output (reviewed by humans)
|   +-- README.md                            Artifact descriptions
|   +-- prd/                                 PRD
|   +-- design/                              Architecture design docs
|   +-- tasks/                               Task breakdown
|   +-- reports/                             Quality reports
|       +-- review/                            Code review
|       +-- test/                              Test results
|       +-- security/                          Security scan
|       +-- legal/                             Legal compliance check
|
+-- testreport/                            <-- [AI-generated] Raw tool output (.gitignore target)
|   +-- coverage/                            Unit test coverage (HTML/LCOV)
|   +-- e2e/                                 E2E test reports & traces
|   +-- security/                            Security scan raw data
|
+-- .agents/                               <-- [Generic] Shared core (used by Claude Code and Codex; the single source lives here)
|   +-- .constitution.sha256               <-- [Auto] Hash of constitution.md
|   +-- guardrails.md                      <-- [Generic] Safety mechanisms as a whole
|   +-- quality-gates.md                   <-- [Generic] Criteria for the 5 quality gates
|   +-- pitfalls.md                        <-- [Generic] 31 failure patterns and mitigations
|   +-- rules/                             <-- [Generic] Rules (1 always-on + 3 path-scoped + 3 samples)
|   |   +-- git-conventions.md               Always loaded: Git and commit conventions
|   |   +-- document-management.md           When editing docs/ or output/: document management
|   |   +-- workflow-advanced.md             When editing source: advanced workflow guidance
|   |   +-- harness-authoring.md             When editing the harness: authoring conventions
|   |   +-- *.md.example                     Language / path samples (drop .example to enable)
|   |
|   +-- learnings/                         <-- [Generic] Success-pattern records (README.md / TEMPLATE.md / example)
|   +-- hooks/                             <-- [Generic] Safety hooks (defense in depth, 18 scripts)
|   |   +-- lib/codex-adapter.sh             Turns Codex input into the shared shape and calls the same hooks
|   |   +-- safety-check.sh                  Blocks dangerous commands (PreToolUse)
|   |   +-- protect-files.sh                 Protects sensitive & config files (PreToolUse)
|   |   +-- scan-harness.sh                  Harness self-SAST & risky-skill blocking (PreToolUse)
|   |   +-- user-prompt-submit.sh            Secret pattern detection (UserPromptSubmit)
|   |   +-- session-start.sh                 Session readiness check and post-compact re-injection (SessionStart)
|   |   +-- session-end.sh                   Session-end logging (SessionEnd)
|   |   +-- commit-quality.sh                Commit quality check (PostToolUse)
|   |   +-- console-warn.sh                  Debug statement detection (PostToolUse)
|   |   +-- verify-gate.sh                   Verification gate: detects unverified stops / completion marks after edits (PostToolUse/Stop/TaskCompleted)
|   |   +-- permission-denied-log.sh         Auto mode denial log (PermissionDenied)
|   |   +-- config-guard.sh                  Refuses and logs settings changes that weaken the guardrails (ConfigChange)
|   |   +-- scope-guard.sh                   Write-scope enforcement for agents (agent frontmatter)
|   |   +-- post-failure-log.sh              Tool failure logging (PostToolUseFailure)
|   |   +-- subagent-audit.sh                Subagent run auditing (SubagentStart/Stop)
|   |   +-- pre-compact-backup.sh            Transcript backup before compaction (PreCompact)
|   |   +-- post-compact-restore.sh          Summary preservation after compaction (PostCompact)
|   |   +-- notify-claude.sh                 Completion/confirmation push notifications (Stop/Notification)
|   |   +-- ntfy-topic.txt                   Notification topic for notify-claude.sh (replace it)
|   |
|   +-- scripts/                           <-- [Generic] Observability aggregation
|   |   +-- harness-stats.sh                 One-page summary of the testreport/ JSONL (denials, failures, settings changes, rule loads, subagents)
|   |
|   +-- skills/                            <-- [Generic] 18 skill definitions (SKILL.md + evals/evals.json + references/ where needed)
|   |   +-- brainstorm/SKILL.md              Premise elicitation (pre-/prd)
|   |   +-- prd/SKILL.md                     PRD generation
|   |   +-- architecture/SKILL.md            Architecture design
|   |   +-- plan/SKILL.md                    Planning & design
|   |   +-- adr/SKILL.md                     Architecture Decision Records
|   |   +-- implementing-features/SKILL.md   TDD implementation
|   |   +-- ui-ux-design/SKILL.md            UI/UX design
|   |   +-- hig-compliance/SKILL.md          HIG compliance check
|   |   +-- design-system-audit/             Design token audit
|   |   |   +-- SKILL.md
|   |   |   +-- references/                    Audit checklist & ratio reference
|   |   +-- e2e-testing/SKILL.md             E2E testing
|   |   +-- code-review/SKILL.md             Code review
|   |   +-- security-scan/                   Security scan
|   |   |   +-- SKILL.md
|   |   |   +-- SETUP_GUIDE.md                 Tool setup guide
|   |   +-- legal-check/SKILL.md             IT legal compliance check
|   |   +-- performance/SKILL.md             Performance optimization
|   |   +-- refactoring/SKILL.md             Refactoring
|   |   +-- review-fix/SKILL.md              PR review auto-fix
|   |   +-- harness-refine/SKILL.md          Harness self-audit & refinement
|   |   +-- limit-resume/                    Unattended runner that waits out usage limits
|   |   |   +-- SKILL.md
|   |   |   +-- scripts/limit_resume.py
|   |
|   +-- tasks/                             <-- [Generic] Task templates
|       +-- TASK_TEMPLATE.md                 Feature development instructions
|       +-- TASK_REVIEW_TEMPLATE.md          Review instructions
|       +-- LESSONS_TEMPLATE.md              Lessons learned template
|       +-- PROGRESS_TEMPLATE.md             Multi-session progress handoff note
|
+-- .claude/                               <-- [Generic] Claude Code adapter (setup.sh links skills/ and rules/ to .agents/)
|   +-- CLAUDE.md                          <-- [Generic] Development guide (Claude Code-specific; imports @AGENTS.md)
|   +-- settings.json                      <-- [Generic] Plugin & hook configuration
|   +-- settings.local.json.template       <-- [Customizable] Permission settings template (generated by setup.sh)
|   +-- managed-settings.example.json      <-- [Reference] Org policy example (deny / sandbox / OTel)
|   +-- settings.minimal.json              <-- [Generic] Settings for the minimal profile (swapped in by setup.sh)
|   +-- statusline.sh                      <-- [Generic] Shows the current output style and phase
|   +-- permissions-guide.md               <-- [Generic] Permission design and auto mode guidance
|   +-- agents/                            <-- [Generic] 9 subagents + README.md (selection guide)
|   |                                        explorer / researcher / planner / security-reviewer /
|   |                                        performance-analyst / doc-synchronizer / doc-writer / test-writer
|   |
|   +-- output-styles/                     <-- [Generic] 4 phase output styles (phase-prd / design / implementation / review)
|   +-- teams/                             <-- [Generic] 6 team definitions
|   |   +-- README.md                        Team usage guide
|   |   +-- TEAM_PJM.md                      Full lifecycle management
|   |   +-- TEAM_FEATURE.md                  Feature development
|   |   +-- TEAM_QA.md                       Quality assurance
|   |   +-- TEAM_PLANNING.md                 Design phase
|   |   +-- TEAM_DESIGN.md                   Design system
|   |   +-- TEAM_REFACTOR.md                 Refactoring
|   |
|   +-- workflows/                         <-- [Generic] Saved workflow (full profile only)
|       +-- review-sweep.js                  4-angle parallel review + adversarial MUST verification
|       +-- skill-eval.js                    Runs a skill's evals with and without the skill
|
+-- .codex/                                <-- [Generic] Codex adapter
|   +-- config.toml                        <-- [Generic] Approval policy, permission profile (secret-read denial), Codex-specific readings
|   +-- hooks.json                         <-- [Generic] Registers the shared hooks (through lib/codex-adapter.sh)
|   +-- hooks.minimal.json                 <-- [Generic] For the minimal profile (swapped in by setup.sh)
|   +-- rules/default.rules                <-- [Generic] Forbidden / prompted commands (matches deny / ask in .claude/settings.json)
|   +-- agents/                            <-- [Generated] 9 subagents (generated from .claude/agents/*.md; do not edit)
|
+-- docs/                                  <-- [AI-generated] Technical documentation
    +-- project.md                           Routing, stores, commands
    +-- architecture.md                      Directory structure, tests
    +-- data-model.md                        Schema, validation rules
    +-- development-patterns.md              Code conventions, pitfalls
```

### Human vs AI Responsibilities

| Area | Created by Humans | Generated by AI |
| ---- | ---------- | --------- |
| Requirements | Placed in `input/requirements/` | PRD generated in `output/prd/` |
| Tech choices & policies | Written in `project-config.md` | Auto-updated on version changes |
| Architecture design | -- | Generated in `output/design/` |
| Task breakdown | -- | Generated in `output/tasks/` |
| Implementation | -- | Modifies source code directly |
| Quality reports | -- | Generated in `output/reports/` |
| Raw tool output | -- | Output to `testreport/` (.gitignore target) |
| Technical documentation | -- | Auto-generated in `docs/` |

---

## Teams and Skills

### Teams

| Template | Purpose | Members | Skills |
| --- | --- | --- | --- |
| **`TEAM_PJM.md`** | **Full lifecycle management (recommended)** | **6** | **13/18** |
| `TEAM_FEATURE.md` | Feature development / bug fixes | 5 | 5 |
| `TEAM_QA.md` | Quality assurance / audit | 5 | 5 |
| `TEAM_PLANNING.md` | Design phase | 4 | 3 |
| `TEAM_DESIGN.md` | Design system / UI consistency | 5 | 4 |
| `TEAM_REFACTOR.md` | Refactoring | 4 | 5 |

For team selection guidance, workflow details, launch patterns, and skill coverage, see `.claude/teams/README.md`.

### Skills (all 18)

All skills accept optional arguments. When omitted, the user is prompted interactively.
Read-only skills use `context: fork` (executed on a copy of the conversation context).

| Skill | Command | Mode | project-config.md Updates |
| ------ | -------- | ------ | ---------------------- |
| Brainstorm | `/brainstorm <requirements memo>` | Read-only | -- |
| PRD | `/prd <file-path>` | Read-only | -- |
| Architecture | `/architecture <file-path>` | Read-only | -- |
| Plan | `/plan <description or file-path>` | Read-only | May update S11 |
| ADR | `/adr <decision-title or instruction>` | Read/Write | -- |
| Implementing Features | `/implementing-features <task-file or instructions>` | Read/Write | Updates S2, S3, S11 |
| UI/UX Design | `/ui-ux-design <target-file or instructions>` | Review/Implement | -- |
| HIG Compliance | `/hig-compliance <target-directory or instructions>` | Review/Implement | -- |
| Design System Audit | `/design-system-audit <target-directory or instructions>` | Read-only | -- |
| E2E Testing | `/e2e-testing <target-feature or instructions>` | Read/Write | -- |
| Code Review | `/code-review <target-file or instructions>` | Read-only | -- |
| Security Scan | `/security-scan <scope or instructions>` | Read-only | -- |
| Legal Check | `/legal-check <scope or instructions>` | Read-only | -- |
| Performance | `/performance <target or instructions>` | Read/Write | Updates S11 |
| Refactoring | `/refactoring <target-directory or instructions>` | Read/Write | -- |
| Review Fix | `/review-fix <PR-number>` | Read/Write | -- |
| Harness Refine | `/harness-refine <target-dir or instruction>` | Read/Write (`.claude/` scaffolding only) | -- |
| Limit Resume | `/limit-resume [setup \| status \| stop]` | Read/Write (queue only; the runner is started outside the session) | -- |

Skill pipeline: `/brainstorm` -> `/prd` -> `/architecture` -> `/plan` -> `/implementing-features` -> `/code-review` + `/security-scan` + `/legal-check` + `/e2e-testing` + `/performance` + `/refactoring`

Auxiliary skills (outside the pipeline, invoked on demand): `/ui-ux-design`, `/hig-compliance`, `/design-system-audit`, `/adr`, `/review-fix`, `/harness-refine`, `/limit-resume`

---

## Quality Gates

| Gate | Timing | What is Presented |
| --- | --- | --- |
| Gate 1 | After PRD generation | Requirements completeness, ambiguity resolution |
| Gate 2 | After design completion | Tech choices, structural validity |
| Gate 3 | After task breakdown | Granularity, dependency accuracy |
| Gate 4 | After implementation | Test results, coverage, static analysis |
| Gate 5 | After verification | Consolidated quality report across all checks |

Pass criteria: All tests pass + Coverage meets target + Zero static analysis errors

Human review at each gate is an optional intervention point, not a mandatory approval step (`constitution.md` principle #3). The gates themselves may not be skipped or reduced in number.

---

## Design Philosophy

### Humans decide WHAT to build; AI handles HOW to build it

- **Humans decide**: Requirements, tech stack, quality standards, policies
- **AI manages**: PRD, design, implementation, testing, reviews, documentation sync
- **Bidirectional sync**: AI also updates `project-config.md` during development

### Clear separation of Input and Output

- `input/` is where humans write (read-only for AI)
- `output/` is where AI generates (reviewed by humans)
- Humans can review and approve at each gate point

### Separation of generic vs project-specific

- Everything under `.claude/` is **generic** (reusable across any project)
- Everything under `docs/` is **project-specific** (generated and maintained by AI)
- `input/` and `output/` are **project-specific** (artifacts from each run)

---

## Integrating into an Existing Project

Steps for adding the blueprint to a project that already has source code.

### 1. Copy files

`setup.sh` works on an existing project as is. It does not overwrite your `docs/`, `project-config.md`, `AGENTS.md` and the like,
and moves an existing `.agents/` `.claude/` `.codex/` to `<name>.bak/` before placing its own:

```bash
bash setup.sh /path/to/existing-project
bash setup.sh /path/to/existing-project --agent codex --profile minimal   # Codex only, lightweight
```

A project that already has Project Blueprint 0.x uses `migrate.sh`, not `setup.sh` (see "Migrating from 0.x" above).

### 2. Fill in project-config.md from the existing project

Use the existing project's `package.json` and configuration files as references to fill in each section:

| Section | Source |
| --- | --- |
| S1 Project Basics | `package.json` name / description |
| S2 Tech Stack | `package.json` dependencies / devDependencies |
| S3 Commands | `package.json` scripts |
| S4 Architecture | Inspect the `src/` directory structure |
| S6 Quality Standards | Existing test and CI configurations |
| S9 Git Policy | `.husky/` and `lint-staged` settings |

### 3. Auto-generate docs/

After filling in `project-config.md`, generate the initial `docs/` using one of these methods:

```text
# Method A: Batch generation with the architecture skill (recommended)
/architecture Document the existing project architecture

# Method B: Incremental generation with the implementing skill
/implementing-features Initial generation of docs/
```

### 4. Carrying over existing settings

If the backed-up `.claude.bak/` `.agents.bak/` `.codex.bak/` hold settings of your own:

- `settings.local.json` → merge into the new `.claude/settings.local.json`
- Custom skills → copy into `.agents/skills/`, then run `bash setup.sh <dir> --relink`
- Your own Codex settings → merge into `.codex/config.toml` (personal allows belong in `~/.codex/`)
- memory/ → unaffected (user-level settings outside `.claude/`)
