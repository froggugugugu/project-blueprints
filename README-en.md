# Project Blueprints

**A template for standing up Claude Code as a development harness.**

It carries a single requirement note through PRD, design, task breakdown, implementation and review.
Instructions, skills, subagents, guardrails and a validation gate arrive together and work as soon as they are copied.
Nothing here is tied to a language or a framework.

[Site](https://froggugugugu.github.io/project-blueprints/en/) ·
[日本語](README.md) ·
[Constitution](constitution.md) ·
[Changelog](CHANGELOG.md)

![Five-line quickstart demo](.github/demo/quickstart.gif)

---

## What this is

- A scaffold that sets up an **AI-collaborative working environment** in one command at the start of a project
- Decisions a person must make (tech choices, quality bars, policies) are collected in the 13 sections of `project-config.md`
- What the model produces and maintains (`docs/`, `output/`, `testreport/`) stays separate, as generated content
- The Japanese mirror `project-blueprint/` and the English mirror `project-blueprint-en/` share the **same structure**

**What it is not**: an application starter. There is no React, no FastAPI, no Rails.
What ships is the instructions and mechanisms handed to Claude Code, so the target project can use any stack.
It can also be added to an existing project later.

---

## Five lines to run it

```bash
git clone https://github.com/froggugugugu/project-blueprints.git
cd project-blueprints
bash project-blueprint-en/setup.sh /path/to/your-project   # Japanese: project-blueprint/setup.sh
cd /path/to/your-project
claude
```

| Profile | What you get | Good for |
| --- | --- | --- |
| `--profile minimal` | 5 skills / 2 agents / 2 hooks | Trying it out, or adding the smallest useful piece to an existing project |
| `--profile standard` | All skills, agents and hooks; no teams or workflows | Running the whole lifecycle solo |
| `--profile full` (default) | Everything | Using the multi-agent formations as well |

### Three entries are enough to start

```markdown
## §1. Project Basics
Name: MyApp
Summary: Internal inventory management

## §2. Tech Stack
- Python 3.13 / FastAPI

## §3. Commands
- test: pytest
- lint: ruff check .
```

The remaining ten sections can stay empty. Fill them in when a skill needs them.

```text
/plan design the stocktaking feature
```

That alone reads `project-config.md` and writes a structured design document into `output/`.

---

## Skill order and quality gates

The order is fixed, with five points where a human can stop and correct the work.
You do not have to use all of them. One skill on its own is a valid way to start.

| # | Skill | Role | Gate |
| --- | --- | --- | --- |
| 1 | `/brainstorm` | Socratic questions that give a vague request its shape (read-only) | |
| 2 | `/prd` | Turns the note into a PRD. Specification first, technology later | 🚏 PRD |
| 3 | `/architecture` | System structure and the allowed direction of dependencies | 🚏 Design |
| 4 | `/plan` | Breaks the design into tasks and fixes the order of work | 🚏 Task breakdown |
| 5 | `/implementing-features` | Test-driven implementation. It also owns `docs/` and `project-config.md` updates | 🚏 Implementation |
| 6 | `/code-review` `/security-scan` `/legal-check` `/e2e-testing` `/performance` `/refactoring` | Verification in a fresh context | 🚏 Verification |

Auxiliary skills: `/ui-ux-design`, `/hig-compliance`, `/design-system-audit`, `/adr`, `/review-fix`, `/harness-refine`.
The last one is a meta-skill that diagnoses and strengthens the harness itself.

---

## What is in the box

```text
17 skills    ideation, design, implementation, review, security, legal, performance, refactoring
             long detail moves into references/ (20 files) so SKILL.md keeps only the procedure
 8 agents    explorer / researcher / planner / security-reviewer / performance-analyst /
             doc-synchronizer / doc-writer / test-writer
 6 teams     TEAM_PJM (full lifecycle, recommended) / FEATURE / QA / PLANNING / DESIGN / REFACTOR
16 hooks     PreToolUse / PostToolUse / SessionStart / SubagentStop / PreCompact / Stop and more
             dangerous-command blocking, protected files, unverified-stop detection, write-scope enforcement
 4 styles    phase-prd / phase-design / phase-implementation / phase-review
 7 rules     4 active (git conventions, document management, workflow detail, harness authoring)
             + 3 language samples (drop the .example suffix to enable)
 2 workflows review-sweep (4-angle parallel review + adversarial verification) / skill-eval (with and without)
34 evals     evals.json for all 17 skills (typical + boundary), 128 assertions
 1 gate      scripts/validate-harness.sh — a static check that fails CI on spec drift
 3 CI        claude-review.yml (conversational @claude review) /
             claude-skills-ci.yml (/code-review + /security-scan on every PR) /
             claude-scheduled-audit.yml (weekly /security-scan + /legal-check into an Issue)
```

---

## Design choices

- **Separate human and AI ownership** — human decisions live in one file, never mixed into AI-managed areas
- **Enforce instead of instruct** — "always do X" becomes a hook, not a paragraph. Three layers: hooks → deny/ask → allow
- **Give the work places to stop** — five quality gates, plus a hook that catches a stop with unverified source edits
- **Do not burn the context** — CLAUDE.md stays under 200 lines together with the AGENTS.md it imports; skills read detail only when they need it
- **Claude Code first, rules shared with other agents** — tool-agnostic rules live in `AGENTS.md` and only Claude Code-specific mechanisms stay in `CLAUDE.md`. When Codex / Cursor / Copilot / Gemini CLI join in, a human sets their roles and write scopes in `project-config.md` §13.7
- **Keep expected behaviour as tests** — after changing a skill, compare pass rates with and without it via `/skill-eval`
- **Break it and CI fails** — the harness validates itself, including drift between the two mirrors

The seven inviolable principles live in [`constitution.md`](constitution.md) and are hash-checked against tampering.

---

## Validation

After editing anything under `.claude/`, run the gate before committing.

```bash
bash scripts/validate-harness.sh            # both mirrors and their structural parity
bash scripts/validate-harness.sh --test     # negative tests for the validator itself
bash scripts/validate-harness.sh --hooks    # functional tests for the hooks
bash scripts/validate-harness.sh --online   # resolve the npm packages in .mcp.json
```

It checks the following deterministically, with no LLM involved.

- Frontmatter values outside the official enums, and permission rules the runtime never consults (`Write(path)` and friends)
- Hook registrations pointing at missing scripts, unresolved `@import` targets, broken links into `references/`
- Skill body length, description length and person, and a line-start `@` (the form that attaches a file in full)
- The schema of `evals/evals.json`, the `meta` declaration of workflows, and calls that break determinism
- The hash of `constitution.md` and the file layout parity of both mirrors

CI (`.github/workflows/validate-harness.yml`) runs the same thing on push and pull request.
`/harness-refine` is the LLM-side counterpart and runs after this gate passes.

---

## Adopt it incrementally

| Step | Sections filled in | What starts working |
| --- | --- | --- |
| **Minimal** | §1 + §2 + §3 | `/brainstorm`, `/prd`, `/plan` for requirements and design |
| **Recommended** | + §4 (architecture) | `/implementing-features` for TDD, and all team templates |
| **Full** | All 13 sections | `/security-scan`, `/legal-check`, and the model-tier strategy |

```bash
# Full lifecycle (recommended)
.claude/teams/TEAM_PJM.md input/requirements/REQ_001.md

# A single skill
/prd        input/requirements/REQ_001.md   # PRD generation
/plan       design the user authentication  # task breakdown
/implementing-features output/tasks/TASK_auth.md
/code-review src/features/auth/
```

To add MCP servers, `cp .mcp.json.template .mcp.json`, fill it in and commit it (shared across the project).

---

## Distribution is clone + `setup.sh`, nothing else

**There is no plugin or marketplace distribution.** It was adopted in April 2026, withdrawn in June 2026,
re-evaluated in August 2026 and withdrawn again. The reason is structural, not a matter of taste.

A plugin can declare only `skills`, `agents`, `outputStyles` and `hooks`. It cannot ship
`project-config.md`, `docs/`, `input/`, `output/`, `.claude/rules/` or `.claude/teams/`.
This harness, meanwhile, is in the following state.

```text
17 of 17 skills reference files a plugin cannot ship

  docs/               16 / 17        project-config.md   14 / 17
  output/             15 / 17        pitfalls.md         12 / 17
  quality-gates.md    15 / 17        .claude/rules/       4 / 17
```

Installed as a plugin alone, **every skill would run with its premises missing**.
This is a project scaffold rather than a general-purpose tool collection, and
"ship the skills, leave the surrounding files behind" does not fit it.

> Reopening this needs new evidence that those dependencies are gone.

---

## Read more

- [`project-blueprint-en/README.md`](project-blueprint-en/README.md) — detailed setup guide
- [`project-blueprint-en/AGENTS.md`](project-blueprint-en/AGENTS.md) — tool-agnostic development rules (read by any coding agent)
- [`project-blueprint-en/.claude/CLAUDE.md`](project-blueprint-en/.claude/CLAUDE.md) — the Claude Code-specific development guide (imports AGENTS.md; under 200 lines combined)
- [`project-blueprint-en/.claude/guardrails.md`](project-blueprint-en/.claude/guardrails.md) — the safety mechanisms as a whole
- [`project-blueprint-en/.claude/pitfalls.md`](project-blueprint-en/.claude/pitfalls.md) — recurring failure patterns in AI-assisted development
- [`project-blueprint-en/.claude/skills/`](project-blueprint-en/.claude/skills/) — SKILL.md for all 17 skills
- [`constitution.md`](constitution.md) — the seven principles, with the protocol for changing them
- [`CHANGELOG.md`](CHANGELOG.md) — release notes (SemVer + Keep a Changelog)

---

## Acknowledgments

This blueprint learned **concepts** from the following Claude Code harness projects and
implements them independently. Deep thanks to their authors and communities.

| Project | License | Concept borrowed | How it is implemented here |
|---|---|---|---|
| [spec-kit](https://github.com/github/spec-kit) | MIT | Separating inviolable principles into a `constitution.md` | Rebuilt independently (7 principles + sha256 hash monitoring) |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | MIT | The idea of running SAST on the harness itself (AgentShield) | `scan-harness.sh` is an independent implementation (checks and thresholds are our own) |
| [superpowers](https://github.com/obra/superpowers) | MIT | Placing a brainstorming phase before `/prd` | Implemented independently as the `/brainstorm` skill (the Socratic template is our own) |
| [BMAD-METHOD](https://github.com/bmadcode/BMAD-METHOD) | MIT | Scale-adaptive personas and team structures | Noted as future scope in the Out of Scope section of `pitfalls.md` |
| [claude-flow](https://github.com/ruvnet/claude-flow) | MIT | Topology metadata (hierarchical / mesh / star) | Adopted as a classification axis in [`project-blueprint-en/.claude/teams/README.md`](project-blueprint-en/.claude/teams/README.md) |

Everything in this repository was written independently; no code was copied from those projects.
Their licenses (all MIT) and this repository's MIT license are fully compatible.

## License

MIT
