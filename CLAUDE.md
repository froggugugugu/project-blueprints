# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **template repository** (not a runnable application) providing an AI-collaborative development harness for **Claude Code and OpenAI Codex, treated as equals**. It is stack-agnostic: the blueprint ships instructions, skills, subagents, guardrails and a validation gate, never application code. All documentation and instructions are written in **Japanese**. Always respond in Japanese when working on this project.

The concept is deliberately "Claude Code and Codex", not "multi-LLM": the harness only promises what it implements and verifies for these two. Other agents (Cursor / Copilot / Gemini CLI) just read `AGENTS.md`.

The blueprint is designed to be copied into target projects via the setup steps in `project-blueprint/README.md`.

## Repository Structure

```text
project-blueprints/
├── README.md                    # Root docs (Japanese)
├── README-en.md                 # Root docs (English)
├── CLAUDE.md                    # This file (repo-wide guidance)
├── constitution.md              # Inviolable principles (7)
├── VERSION                      # Released version (x.y.z); must match the newest CHANGELOG heading (validator checks)
├── SECURITY.md                  # Vulnerability scope, reporting channel, supported versions (JP + EN)
├── evals/                       # Skill eval evidence: fixtures/ (seed projects), baseline/ (committed pass rates); results/ is gitignored
├── .github/
│   ├── pages/                   # GitHub Pages source (index.html, en/index.html, assets/, _config.yml)
│   ├── demo/                    # quickstart.gif used by the READMEs and the site
│   └── workflows/               # validate-harness.yml (CI gate) + skill-evals.yml (weekly LLM eval gate) + pages.yml (site deploy)
├── scripts/                     # Harness validator (CI gate) — see Build / Test / Lint
│   ├── validate-harness.sh      # Entry point
│   ├── validate_harness.py      # Checks (shared core, Claude Code adapter, Codex adapter, JP/EN parity)
│   ├── sync_codex_agents.py     # Generates .codex/agents/*.toml from .claude/agents/*.md (validator checks they are in sync)
│   ├── test_validate_harness.py # Negative tests for the checks
│   ├── test_hooks.sh            # Functional tests of the hook scripts and the Codex adapter (--hooks)
│   ├── test_setup.sh            # Functional tests of setup.sh install / --agent / links / --upgrade (--setup)
│   ├── test_migrate.sh          # Functional tests of migrate.sh against real 0.x installs rebuilt from git history (--migrate)
│   ├── test_limit_resume.py     # Functional tests of the /limit-resume runner with a fake claude CLI (--limit-resume)
│   ├── run_skill_evals.py       # Headless skill evals: with / without the skill, independent grader, baseline comparison (Claude Code only)
│   └── release.sh               # prepare (VERSION + CHANGELOG on a branch) / publish (tag + GitHub Release)
├── project-blueprint/           # The Japanese blueprint template
│   ├── README.md                # Setup guide & quick start
│   ├── setup.sh                 # Install (--agent claude|codex|both, --profile, --links) / --upgrade / --relink; identical in both mirrors
│   ├── migrate.sh               # 0.x layout (everything under .claude/) → 1.0 layout; --dry-run / --rollback; identical in both mirrors
│   ├── AGENTS.md                # Tool-agnostic rules (copied to target root; Codex reads it directly, CLAUDE.md imports it via @AGENTS.md)
│   ├── REVIEW.md                # Review-only criteria for Claude's Code Review (GitHub App); the local /code-review does not read it
│   ├── project-config.md        # Template: human decisions (13 sections)
│   ├── .mcp.json.template       # Project-shared MCP server config template (Claude Code); Codex examples live in .codex/config.toml
│   ├── .github/workflows/       # CI templates: claude-review / claude-skills-ci / claude-scheduled-audit / codex-skills-ci
│   ├── .agents/                 # Shared core — the single source both agents read
│   │   ├── skills/              # 18 skill definitions (SKILL.md + evals/evals.json; agents/openai.yaml for manual-only skills)
│   │   ├── hooks/               # 18 hook scripts + lib/codex-adapter.sh (turns Codex input into the shared shape)
│   │   ├── rules/               # Rule extensions (path-scoped for Claude Code via links; read on condition by Codex)
│   │   ├── scripts/             # harness-stats.sh: aggregates the hooks' testreport/ JSONL into one Markdown report
│   │   ├── tasks/ learnings/    # Task instruction templates / success-pattern records
│   │   ├── guardrails.md        # Safety mechanism overview, incl. the Claude Code / Codex mapping and where guarantees differ
│   │   ├── quality-gates.md     # Quality gate definitions
│   │   └── pitfalls.md          # Common failure patterns (anti-patterns)
│   ├── .claude/                 # Claude Code adapter
│   │   ├── CLAUDE.md            # Development guide (copied to target project root)
│   │   ├── settings.json        # Hook registrations + deny/ask + plugin config (context7, playwright, etc.)
│   │   ├── settings.local.json.template
│   │   ├── loop.md              # Default prompt for a bare /loop (PROGRESS.md next step → PR upkeep → /code-review)
│   │   ├── teams/               # 6 team templates (TEAM_*.md files) — a Claude Code extension
│   │   ├── workflows/           # 2 saved dynamic workflows (review-sweep.js, skill-eval.js; full profile only) — a Claude Code extension
│   │   └── agents/              # 9 subagent definitions — the source the Codex versions are generated from
│   ├── .codex/                  # Codex adapter
│   │   ├── config.toml          # approval policy, permission profile (secret-read denial, harness read-only), Codex-specific readings
│   │   ├── hooks.json           # Registers the shared hooks through lib/codex-adapter.sh (hooks.minimal.json for the minimal profile)
│   │   ├── rules/default.rules  # forbidden / prompt command rules matching the Claude Code deny / ask lists
│   │   └── agents/              # 9 generated subagent definitions (do not edit; run scripts/sync_codex_agents.py)
│   ├── docs/                    # AI-managed technical docs (stubs)
│   ├── input/                   # Human requirements input
│   │   └── requirements/        # Requirement memos go here
│   ├── output/                  # AI-generated deliverables
│   │   ├── prd/                 # Phase 1: PRDs
│   │   ├── design/              # Phase 2: Architecture docs
│   │   ├── tasks/               # Phase 3: Task decomposition
│   │   └── reports/             # Phase 5: Quality reports
│   └── testreport/              # Tool raw output (.gitignore target)
└── project-blueprint-en/        # English mirror of the blueprint (same structure)
```

The template tree has no `.claude/skills/` or `.claude/rules/`: Claude Code reads only those paths, so `setup.sh` creates one symbolic link per entry into `.agents/` in the target project (copies with `--links copy`).

## Architecture: Key Design Decisions

**Human vs AI separation**: `project-config.md` centralizes all human decisions (tech stack, quality standards, policies) in one file. AI generates and maintains `docs/`, `output/`, and `testreport/`.

**Input/Output flow**: `input/requirements/` (human-written, read-only for AI) → AI processing → `output/` (AI-generated, human reviews at quality gates).

**Two agents, one core** (the 1.0 layout): `.agents/` holds everything Claude Code and Codex share — skills, hook scripts, rules, quality gates. `.claude/` and `.codex/` are thin adapters holding only what each agent's runtime reads (settings, hook registrations, deny rules, subagent definitions). Either agent can run the whole lifecycle alone; `setup.sh --agent claude|codex|both` chooses which adapters are installed. When adding a mechanism, do not stop at one side: implement the counterpart, or record why there is none in `.agents/guardrails.md` ("Where Codex does not give the same guarantee"). The validator fails when the Claude Code deny / ask lists and the Codex rules / permission profile drift apart.

**Generic vs project-specific**: Everything under `.agents/`, `.claude/` and `.codex/` is reusable across projects. `docs/`, `input/`, `output/` are project-specific and generated per-use.

**Skill system** (18 skills in `.agents/skills/*/SKILL.md`): Each skill is a standalone prompt with a defined pipeline order: `/brainstorm` → `/prd` → `/architecture` → `/plan` → `/implementing-features` → `/code-review` + `/security-scan` + `/legal-check` + `/e2e-testing` + `/performance` + `/refactoring`. Auxiliary skills: `/ui-ux-design`, `/hig-compliance`, `/design-system-audit`, `/adr`, `/review-fix`, `/harness-refine` (meta-skill: self-diagnoses and refines the harness configuration), `/limit-resume` (prepares an unattended queue runner that waits out subscription usage limits; the runner itself is `scripts/limit_resume.py` inside the skill and is started by the user outside the session). Claude Code invokes a skill as `/name`, Codex as `$name`; bodies are written with `/name` and `AGENTS.md` tells Codex to read it as `$name`. Codex loads the same `SKILL.md` files (verified with codex-cli 0.162.1: the Claude Code-specific frontmatter keys are tolerated). The `/prd` skill follows the spec-driven framing (specification first, technology later) aligned with GitHub Spec-Kit / BMAD-METHOD. Every skill ships `evals/evals.json` (agentskills.io format: a typical case and a boundary case with verifiable assertions, run via the skill-creator plugin). Descriptions follow the official "what it does + when to use it" pattern because the skill listing is capped at 1% of context, and skills never use a line-start `@path` (Claude Code attaches that file in full at invocation); they list references with a reading condition instead. A skill with `disable-model-invocation: true` also carries `agents/openai.yaml` (`policy.allow_implicit_invocation: false`) so Codex does not invoke it implicitly. Writing conventions live in the path-scoped rule `.agents/rules/harness-authoring.md`.

**Team system** (6 teams in `.claude/teams/TEAM_*.md`): Multi-agent orchestration templates — a Claude Code extension with no Codex counterpart (under Codex the same skills are run in order). `TEAM_PJM.md` is the recommended full-lifecycle team (6 members, covers the 13 core lifecycle skills, 5 quality gates). The 5 auxiliary skills (`/design-system-audit`, `/adr`, `/review-fix`, `/harness-refine`, `/limit-resume`) are invoked on demand outside the standard team flow. `.claude/workflows/review-sweep.js` is the scripted form of the team layer: a saved dynamic workflow that reviews a diff from 4 angles in parallel and adversarially verifies each MUST finding with 3 votes. `skill-eval.js` runs a skill's `evals/evals.json` with and without the skill and compares pass rates, so skill edits are judged on numbers rather than impressions.

**Subagent layer** (9 agents; source in `.claude/agents/*.md`, generated Codex versions in `.codex/agents/*.toml`): Single-shot specialist delegation (`explorer`, `researcher`, `planner`, `security-reviewer`, `performance-analyst`, `doc-synchronizer`, `doc-writer`, `test-writer`, `verifier`). `verifier` is the read-only spec-conformance check run once right before a task is declared complete (the official adversarial-review step); it has no `memory` so verdicts never carry over. `researcher` handles external technical investigation; `doc-writer` authors new documents under `output/` (complementing `doc-synchronizer` which syncs existing `docs/`). Complements teams and skills with isolated-context execution. `scripts/sync_codex_agents.py` writes the Codex versions; because Codex has no per-agent sandbox or hooks, the `tools` restriction and the `scope-guard.sh` scope are written out as instructions at the top of each generated file.

**Hook system** (18 hook scripts in `.agents/hooks/*.sh`; Claude Code: 27 registered invocations in `.claude/settings.json` plus 3 agent-frontmatter registrations of `scope-guard.sh`; Codex: 15 registered invocations of 12 scripts in `.codex/hooks.json`, all through `lib/codex-adapter.sh`): Defense in depth across `PreToolUse` / `PostToolUse` / `PostToolUseFailure` / `PermissionRequest` / `PermissionDenied` / `ConfigChange` / `FileChanged` / `TaskCompleted` / `TeammateIdle` / `SessionStart` / `InstructionsLoaded` / `SessionEnd` / `SubagentStart` / `SubagentStop` / `PreCompact` / `PostCompact` / `UserPromptSubmit` / `UserPromptExpansion` / `Stop` / `StopFailure` / `Notification` on the Claude Code side. The four blocking hooks (`safety-check.sh`, `protect-files.sh`, `config-guard.sh`, agent-frontmatter `scope-guard.sh`) carry `onFailure: "block"` so a hook that cannot start fails closed; the validator warns when that is missing. Codex has no such setting, so the adapter's `--fail-closed` flag stops the action when a blocking hook script is missing. The adapter also converts a Codex `apply_patch` (patch text in `tool_input.command`) into one Claude Code-shaped input per touched file, so hooks are written against one input shape only, and reads the project root from its own location (`BLUEPRINT_PROJECT_DIR`, then `CLAUDE_PROJECT_DIR`). `scan-harness.sh` is registered on `UserPromptExpansion` as well because typing `/skill` directly bypasses `PreToolUse(Skill)`, and on Codex's `UserPromptSubmit` where a skill is named as `$name`. Mix of block / observe / notify / backup / gate roles. `verify-gate.sh` (PostToolUse + Stop + TaskCompleted) is the deterministic verification gate from the official best practices; `permission-denied-log.sh` records auto mode denials; `config-guard.sh` (ConfigChange) refuses settings changes that weaken the guardrails; `session-start.sh` re-injects the core rules on the `compact` source (the official pattern; the older PostCompact-marker approach is gone). `settings.json` `env` enables the Task tools (absent by default on Claude 5-family models, required by the TaskCompleted gate) and pins subagent spawn depth to 1 (constitution ④). See `.agents/guardrails.md`.

**Codex-side deny layer**: `.codex/rules/default.rules` mirrors the Claude Code deny (`forbidden`) and ask (`prompt`) command rules; the `blueprint` permission profile in `.codex/config.toml` mirrors the `Read()` deny list and keeps `.git`, `.agents`, `.codex` and `.claude/settings*.json` read-only. Measured with codex-cli 0.162.1: `extends = ":workspace"` alone did not keep those paths read-only (the docs say it does); measured again with 0.170.0: it did, except `.claude/settings*.json`, which the built-in protection does not cover. They stay stated explicitly because 0.162 is the oldest supported version, and the validator errors when one is missing. Known gaps (hooks do not run until trusted with `/hooks`, no per-subagent restriction, prefix-only rules, beta permission profiles) are listed in `guardrails.md` rather than hidden.

**Distribution**: `setup.sh` + clone only. `setup.sh` writes `.agents/blueprint-manifest.txt` (version, profile, agent, link mode, per-file hashes) into the target; `setup.sh <dir> --upgrade [--dry-run]` later overwrites untouched files, places `<path>.blueprint-new` next to locally modified ones, adds new template files (profile pruning preserved; `--agent both` adds the other adapter) and never touches `project-config.md`, `docs/`, `input/`, `output/` or `settings.local.json` (tested by `--setup`). `setup.sh --relink` refreshes the `.claude/skills` / `.claude/rules` links after a skill or rule is added. A 0.x install is moved to this layout with `migrate.sh` first: released 0.x versions wrote no manifest, so it tells untouched files from modified ones by matching content against the template's git history (the clone needs history), moves user-added skills and hooks along, rewrites references and hook registration paths, then calls `setup.sh --upgrade`; a failure rolls back automatically and `--rollback` undoes a successful run (tested by `--migrate` against real 0.x installs rebuilt from history). Plugin packaging was evaluated twice (adopted 2026-04, withdrawn 2026-06, re-evaluated and withdrawn again 2026-08) and does not fit: a plugin can only declare `skills`/`agents`/`outputStyles`/`hooks`, while **18 of 18 skills reference files a plugin cannot ship** (`docs/` 16, `output/` 16, `quality-gates.md` 15, `project-config.md` 14, `pitfalls.md` 12, `.agents/rules/` 3). Do not re-open this without new evidence that those dependencies have gone away.

**MCP + GitHub Actions**: `.mcp.json.template` for project-shared MCP servers (Claude Code); the same servers appear as commented examples in `.codex/config.toml`. Workflow templates: `claude-review.yml.template` (conversational `@claude` PR review via `anthropics/claude-code-action`), `claude-skills-ci.yml.template` (headless `claude -p` running `/code-review` and `/security-scan` on every PR, with `--permission-mode dontAsk` and no `--bare` so the project's `.claude/` loads), `codex-skills-ci.yml.template` (the same two skills through `openai/codex-action`), plus `claude-scheduled-audit.yml.template` (weekly `/security-scan` + `/legal-check` into a GitHub Issue). Durable scheduling belongs on Actions, not on session-scoped `/loop`/`CronCreate`, which fire only while a session is idle and expire after 7 days.

**Quality gates**: 5 checkpoints (post-PRD, post-design, post-task-decomposition, post-implementation, post-verification) where humans can review and approve.

## Build / Test / Lint

There is no application build. The check that gates this repository is the harness validator:

```bash
bash scripts/validate-harness.sh           # both mirrors + JP/EN structural parity
bash scripts/validate-harness.sh --online  # also resolve the npm packages in .mcp.json.template
bash scripts/validate-harness.sh --test    # negative tests for the validator itself
bash scripts/validate-harness.sh --hooks   # functional tests of the hook scripts and the Codex adapter (feeds hook JSON on stdin; needs jq)
bash scripts/validate-harness.sh --setup   # functional tests of setup.sh (agents, profiles, links, manifest, --upgrade conflicts)
bash scripts/validate-harness.sh --migrate # functional tests of migrate.sh (needs full git history and jq)
bash scripts/validate-harness.sh --limit-resume # functional tests of the /limit-resume runner (fake CLI; identical JP/EN copies)
python3 scripts/sync_codex_agents.py       # regenerate .codex/agents/*.toml after editing .claude/agents/*.md (--check to verify only)
```

The LLM-side counterpart is `scripts/run_skill_evals.py`: it runs each skill's `evals/evals.json` headlessly in a
throwaway project built by `setup.sh`, once with the skill and once without, grades every assertion with a separate
tool-less `claude -p` call, and compares the with-skill pass rate against `evals/baseline/latest.json`. It needs a
logged-in `claude` CLI and costs API money, so it runs weekly / on demand in `.github/workflows/skill-evals.yml`
(gated by the repository variable `SKILL_EVALS_ENABLED` and the `ANTHROPIC_API_KEY` secret), not on every PR.
Update the committed baseline from a local run (copy `summary.json` to `evals/baseline/latest.json`) so number
changes are reviewed in a PR. Method and current numbers: `evals/README.md`. It measures Claude Code only; a Codex
runner (`codex exec`) is not implemented yet.

The validator is deterministic (no LLM) and enforces the parts of the official specs that are easy to
drift from: frontmatter values outside the official enums, permission rules the runtime
never consults (`Write(path)` and friends), settings keys project settings silently ignore (user / managed / global-config-only keys
from the settings-reference "Where it's honored" column, plus removed keys), older-model phrasing in instruction files
(`IMPORTANT`, `YOU MUST`, `think hard`), hook registrations pointing at missing scripts,
unresolved `@import` targets, the constitution hash, JP/EN parity, line-start `@` attachments in skills, description length and person, `evals/evals.json` schema, reference-file ToCs and linkage from SKILL.md, skill body length, workflow `meta` / determinism rules, agent-frontmatter hooks (including a WARN for write-capable agents without `scope-guard.sh`), and the `AGENTS.md` split (the `@AGENTS.md` import in CLAUDE.md, no line-start `@` in AGENTS.md, every cited `project-config.md` § exists, combined line budget).
On the Codex side it checks that `.codex/hooks*.json` use real Codex events, call the shared hooks through the adapter and register both blocking hooks with `--fail-closed`; that `.codex/config.toml` does not weaken the guardrails (`approval_policy = "never"`, `sandbox_mode` next to a permission profile, a writable harness, keys a project config ignores); that every Claude Code deny / ask command rule and `Read()` deny has a Codex counterpart; that `.codex/agents/*.toml` equal what `sync_codex_agents.py` regenerates; that nothing from the shared core is duplicated under `.claude/`; and that `setup.sh` / `migrate.sh` are byte-identical in the two mirrors.
Run it before every commit that touches `.agents/`, `.claude/` or `.codex/`. CI runs it on push and pull request
(`.github/workflows/validate-harness.yml`, with full history for the migration tests).

`/harness-refine` is the LLM-driven counterpart and runs *after* this gate passes.

Releases: `bash scripts/release.sh prepare <x.y.z>` bumps `VERSION` and turns the CHANGELOG `Unreleased` section into
a release heading on a `chore/release-<x.y.z>` branch; after the PR merges, `bash scripts/release.sh publish <x.y.z>`
tags `main` and creates the GitHub Release from that CHANGELOG section. `main` is protected (the `validate` check is
required, force pushes and deletion are blocked, admins included), so every change goes through a PR.

## Editing Guidelines

- Skill files follow a consistent structure: context loading, step-by-step workflow, output format, and gate definitions. Maintain this pattern when adding or modifying skills.
- `project-config.md` has 13 numbered sections (§1–§13; §13 defines the Opus/Sonnet/Haiku tier strategy, and §13.7 the setup of Claude Code and Codex plus the roles and write scopes of auxiliary agents). Skills reference these by section number — keep numbering stable.
- The `.claude/CLAUDE.md` is the development guide that gets moved to the target project root during setup. It references `project-config.md` sections and `docs/` files by convention.
- Tool-agnostic rules (principles, document management, quality standards, Git, security rules, the per-agent readings table) live in the blueprint's `AGENTS.md`, which Codex reads directly; `.claude/CLAUDE.md` imports it with `@AGENTS.md` and holds only Claude Code-specific mechanisms, and Codex-specific readings go in `developer_instructions` in `.codex/config.toml`. Auxiliary agents follow `project-config.md` §13.7 and act read-only unless marked `yes` there. Safety prohibitions are kept in `CLAUDE.md` itself as well, because the docs do not say whether the auto mode classifier reads imported files. The validator enforces the import, forbids line-start `@` in `AGENTS.md`, checks that every `project-config.md` § they cite exists, and counts both files against the 200-line budget.
- Keep the two agents in step: a new skill, hook, deny rule or subagent goes into the shared core or gets its counterpart in the other adapter in the same change. Edit subagents in `.claude/agents/` and regenerate the Codex versions; never edit `.codex/agents/*.toml` by hand.
- `setup.sh` and `migrate.sh` are single bilingual files (messages via `t "<ja>" "<en>"`). Edit one mirror's copy and copy it to the other; they must stay bash 3.2 compatible (macOS default).
- Verify Codex behavior against the real CLI where possible (`codex execpolicy check`, `codex sandbox -- <cmd>`, `codex debug prompt-input`, `codex doctor` — none of these call a model) and the official docs (`https://developers.openai.com/codex/<page>.md`), and write down what was measured versus what the docs say when they differ.
- Team templates define roles, member counts, skill assignments, and phase workflows. Changes to skill names must be reflected in team templates.
- `docs/` files are stubs in this repo — they serve as templates showing the expected structure for AI to populate in target projects.
