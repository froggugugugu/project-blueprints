# Project Blueprints

[**日本語**](README.md) · [English] · [CHANGELOG](CHANGELOG.md) · [constitution](constitution.md)

> **The only JP↔EN bilingual development harness for Claude Code.**
> Hand a one-line requirement note to AI and get PRD → design → TDD implementation → QA reports.
> Just **3 lines** in `project-config.md` to start.

---

## Run it in 5 lines

```bash
git clone https://github.com/froggugugugu/project-blueprints.git
bash project-blueprints/project-blueprint-en/setup.sh ./my-app
echo -e "\n## §2 Tech Stack\n- TypeScript / Vite / Vitest" >> ./my-app/project-config.md
cd ./my-app && claude
# → Inside Claude Code:  /plan login feature design
```

After line 5, you can already run `/prd`, `/plan`, `/implementing-features`, code review, and more.

> **Demo** (30s): `/prd` → `/architecture` → `/plan` → `/implementing-features` flow
> *(GIF coming soon)*

---

## Why this — 5 differentiators

| | Strength | What others lack |
|---|---|---|
| 🌏 | **JP↔EN structural mirror** | All competitors (superpowers, ECC, spec-kit, BMAD, claude-flow) are English-only |
| 🛡️ | **Self-SAST** (`scan-harness.sh`) | The harness inspects itself for secret leaks, constitution drift, and weakened denies |
| 📜 | **Constitution-driven** | 7 inviolable principles in `constitution.md`, sha256 hash-monitored |
| 🚦 | **5 quality gates** | Optional human intervention at PRD / design / task / implementation / verification |
| 🧩 | **Three-layer separation** | skill (work) / team (orchestration) / agent (specialist) — never blurred |

The 7 inviolable principles are codified in [`constitution.md`](constitution.md) (changes require a hash-bumping PR).

---

## What's inside

```text
16 skills    /brainstorm, /prd, /architecture, /plan, /implementing-features,
             /code-review, /security-scan, /legal-check, /performance,
             /refactoring, /e2e-testing, /ui-ux-design, /hig-compliance,
             /design-system-audit, /adr, /review-fix
 6 teams     PJM (full lifecycle) / Feature / QA / Planning / Design / Refactor
 6 agents    explorer, planner, security-reviewer, performance-analyst,
             doc-synchronizer, test-writer
12 hooks     PreToolUse(Bash/Edit/Write/Skill) / PostToolUse / UserPromptSubmit /
             SessionStart / SessionEnd / SubagentStop / PreCompact / Stop / Notification
 4 styles    phase-prd, phase-design, phase-implementation, phase-review
 4 rules     document-management, git-conventions, workflow-advanced (+ README)
 1 plugin    .claude-plugin/marketplace.json (Anthropic marketplace ready)
```

For the full spec, see [`project-blueprint-en/README.md`](project-blueprint-en/README.md) and [`CHANGELOG.md`](CHANGELOG.md).

---

## Adopt incrementally

| Stage | Sections to fill | Unlocks |
| --- | --- | --- |
| **Minimal** | §1 + §2 + §3 | `/brainstorm`, `/prd`, `/plan` for requirements & design |
| **Recommended** | + §4 (Architecture) | `/implementing-features` (TDD), all teams |
| **Full** | All 13 sections | `/security-scan`, `/legal-check`, model-tier strategy (§13) |

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

## License

MIT
