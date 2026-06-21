# Project Blueprints

[**日本語**](README.md) · [English] · [CHANGELOG](CHANGELOG.md) · [constitution](constitution.md)

> An AI-collaborative development harness for Claude Code, characterized by its
> **JP↔EN structural mirror** and **self-SAST** (the harness inspects itself).
> Hand a one-line requirement note to AI and get PRD → design → TDD → QA reports.
> Just **one line in `project-config.md` §2** to start.

**Prerequisite**: [Claude Code](https://docs.claude.com/en/docs/claude-code) installed and on `PATH`.

---

## Run it in 5 lines

```bash
git clone https://github.com/froggugugugu/project-blueprints.git
bash project-blueprints/project-blueprint-en/setup.sh ./my-app
printf '\n## §2 Tech Stack\n- TypeScript / Vite / Vitest\n' >> ./my-app/project-config.md
cd ./my-app && claude
# → Once Claude Code launches, type:  /plan login feature design
```

At this point, the **design phase** runs: `/brainstorm` (when requirements are vague) → `/prd` → `/plan`.
Implementation-side skills like `/implementing-features` need `§4` (Architecture) filled in first —
see "[Adopt incrementally](#adopt-incrementally)" below.

![5-line quickstart demo](.github/demo/quickstart.gif)

> The 5 lines walk through `git clone` → `setup.sh` (places constitution.md, skills, hooks)
> → `printf` to add §2 → launching `claude` → `/plan` accepted by Opus 4.7 —
> all visible in **30 seconds**.

---

## Why this — 5 differentiators

| | Strength | Summary |
|---|---|---|
| 🌏 | **JP↔EN structural mirror** | `project-blueprint/` (Japanese) and `project-blueprint-en/` (English) are kept in lockstep. Multilingual Claude Code harnesses are rare in the ecosystem |
| 🛡️ | **Self-SAST** (`scan-harness.sh`) | The harness inspects itself for secret leaks, constitution drift, and weakened denies |
| 📜 | **Constitution-driven** | 7 immutable principles in `constitution.md`, sha256-monitored. Hooks block AI attempts to alter them |
| 🚦 | **5 quality gates** | Optional human intervention points at PRD / design / task / implementation / verification |
| 🧩 | **Three-layer separation** | skill (work) / team (orchestration) / agent (specialist) — never blurred. No cyclic references between layers |
| 🪶 | **Pro-plan friendly** | **Session-start** load compressed to ~7K tokens (70% reduction). Details (`pitfalls.md`, `guardrails.md`, etc.) are loaded by each skill via `@import` only when invoked. Sessions that don't run a skill save 17K+ tokens of context window |

---

## What's inside

```text
17 skills    /brainstorm, /prd, /architecture, /plan, /implementing-features,
             /code-review, /security-scan, /legal-check, /performance,
             /refactoring, /e2e-testing, /ui-ux-design, /hig-compliance,
             /design-system-audit, /adr, /review-fix, /harness-refine
 6 teams     PJM (full lifecycle) / Feature / QA / Planning / Design / Refactor
 8 agents    explorer, planner, researcher, security-reviewer,
             performance-analyst, doc-synchronizer, doc-writer, test-writer
12 hooks     PreToolUse(Bash/Edit/Write/Skill) / PostToolUse / UserPromptSubmit /
             SessionStart / SessionEnd / SubagentStop / PreCompact / Stop / Notification
 4 styles    phase-prd, phase-design, phase-implementation, phase-review
 4 rules     document-management, git-conventions, workflow-advanced (+ README)
```

For the full spec, see [`project-blueprint-en/README.md`](project-blueprint-en/README.md) and [`CHANGELOG.md`](CHANGELOG.md).

---

## Adopt incrementally

| Stage | Sections to fill | Unlocks |
| --- | --- | --- |
| **Minimal** | §1 + §2 + §3 | `/brainstorm`, `/prd`, `/plan` for requirements & design |
| **Recommended** | + §4 (Architecture) | `/implementing-features` (TDD), all teams |
| **Full** | All 13 sections | `/security-scan`, `/legal-check`, model-tier strategy (§13) |

> The "Run in 5 lines" example only fills `§2` as a smoke test. For real projects,
> filling `§1` (project name) and `§3` (build/test/lint commands) unlocks more skills.

---

## Common usage

```bash
# Full lifecycle (recommended)
.claude/teams/TEAM_PJM.md input/requirements/REQ_001.md

# Single skill
/brainstorm input/requirements/REQ_001.md   # When the requirement is vague
/prd        input/requirements/REQ_001.md   # Generate PRD
/plan       Login feature design            # Task breakdown
/implementing-features output/tasks/TASK_auth.md
```

---

## 📚 Learn more

- [`project-blueprint-en/README.md`](project-blueprint-en/README.md) — Detailed setup
- [`constitution.md`](constitution.md) — 7 inviolable principles (with change protocol)
- [`project-blueprint-en/.claude/CLAUDE.md`](project-blueprint-en/.claude/CLAUDE.md) — Development guide (cross-cutting rules, ≤200 lines)
- [`project-blueprint-en/.claude/pitfalls.md`](project-blueprint-en/.claude/pitfalls.md) — 20 common AI-collaboration pitfalls
- [`project-blueprint-en/.claude/skills/`](project-blueprint-en/.claude/skills/) — All 16 SKILL.md files
- [`CHANGELOG.md`](CHANGELOG.md) — Release notes (SemVer + Keep a Changelog)

## Acknowledgments

This blueprint borrows **conceptual ideas** from several outstanding Claude Code
harness projects, independently re-implemented in our own style. We deeply thank
their authors and communities.

| Project | License | Concept borrowed | How it lives here |
|---|---|---|---|
| [spec-kit](https://github.com/github/spec-kit) | MIT | The `constitution.md` pattern — separating immutable principles from variable parameters | Independently composed (7 principles + sha256 hash monitoring) |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | MIT | The "self-SAST" approach (AgentShield) | `scan-harness.sh` is an independent implementation (own checks and thresholds) |
| [superpowers](https://github.com/obra/superpowers) | MIT | A brainstorming phase placed before `/prd` | `/brainstorm` skill independently authored (own Socratic templates) |
| [BMAD-METHOD](https://github.com/bmadcode/BMAD-METHOD) | MIT | Scale-adaptive personas / team structure | Listed as future work in `pitfalls.md` (Out of Scope) |
| [claude-flow](https://github.com/ruvnet/claude-flow) | MIT | Topology metadata (hierarchical / mesh / star) | Adopted as classification axis in [`project-blueprint-en/.claude/teams/README.md`](project-blueprint-en/.claude/teams/README.md) |

All implementations in this repository are independent — no code or text was
directly copied from these projects. Their licenses (all MIT) are fully
compatible with ours (also MIT).

## License

MIT
