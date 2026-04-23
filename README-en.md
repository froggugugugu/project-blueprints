# Project Blueprints

AI-collaborative development environment templates for Claude Code.

Consolidate all human decisions into a single `project-config.md` file, and let AI handle everything from requirements analysis to PRD generation, design, implementation, testing, and review.

## Project Blueprints in 30 Seconds

```
What You Write              ->  What AI Generates
---------------------         ---------------------
Requirement notes (a few    ->  PRD, Architecture Docs, Task Breakdown
  lines of notes)
project-config.md           ->  TDD Implementation, Tests, Code Review
(Tech stack, Quality        ->  Quality Reports, Technical Documentation
  standards)
```

**1 config file + 15 skills + 6 teams + 5 quality gates + 9 hooks + subagent layer** -- scales from solo to team development.

## Getting Started

```
New project? --- Yes --> One-command setup with setup.sh
       |
       No (existing project)
       |
       v
  Run setup.sh (existing .claude/ auto-backed up)
       |
       v
  Fill in project-config.md (S1-S3, S6 -- 4 sections minimum)
       |
       v
  Run /plan in Claude Code to verify setup
       |
       v
  Start developing! (/prd -> /architecture -> /implementing-features)
```

### One-Command Setup

```bash
git clone https://github.com/your-org/project-blueprints.git
cd project-blueprints
bash project-blueprint-en/setup.sh /path/to/your-project
```

### Manual Setup

```bash
cp -r project-blueprint-en/.claude /path/to/new-project/.claude
cp -r project-blueprint-en/docs /path/to/new-project/docs
cp -r project-blueprint-en/input /path/to/new-project/input
cp -r project-blueprint-en/output /path/to/new-project/output
cp -r project-blueprint-en/testreport /path/to/new-project/testreport
cp project-blueprint-en/project-config.md /path/to/new-project/project-config.md

# Move CLAUDE.md to the project root
mv /path/to/new-project/.claude/CLAUDE.md /path/to/new-project/CLAUDE.md
```

### Fill in project-config.md (Minimum 4 Sections)

| Section | Content |
| --- | --- |
| S1 Project Basics | Name, description, language |
| S2 Tech Stack | Frameworks, libraries |
| S3 Commands | dev / build / test / lint |
| S6 Quality Standards | Coverage target, TDD on/off |

> Example: [project-config.sample.md](project-blueprint-en/project-config.sample.md) (fully filled sample using a task management app)

### Start Development

```text
# Full lifecycle with PJM team (recommended)
.claude/teams/TEAM_PJM.md input/requirements/REQ_001.md

# Individual skills
/prd input/requirements/REQ_001.md
/plan Design user authentication feature
/implementing-features output/tasks/TASK_auth.md
```

For detailed setup instructions, step-by-step configuration guide, and integration into existing projects, see [project-blueprint-en/README.md](project-blueprint-en/README.md).

## Features

- **Single config file**: Consolidate tech stack, quality standards, and policies in `project-config.md`. Fill in incrementally
- **15 skills**: PRD / architecture / task breakdown / TDD implementation / UI/UX / HIG compliance / design-token audit / code review / E2E / performance / refactoring / security scan / legal check / ADR / review-fix
- **6 team templates**: Full lifecycle (PJM) / feature / QA / planning / design / refactoring
- **6 subagents**: explorer / planner / security-reviewer / performance-analyst / doc-synchronizer / test-writer (`.claude/agents/`)
- **5 quality gates**: Checkpoints where humans can review and approve at each phase
- **9 hooks**: Defense in depth (5 block + 3 observe + 1 notify). Active even with `--dangerously-skip-permissions`
- **Input/Output separation**: Clear separation between human requirements (`input/`) and AI deliverables (`output/`)
- **MCP / GitHub Actions templates**: Project-shared MCP (`.mcp.json.template`) and `@claude` PR review (`.github/workflows/`)

## Skill Pipeline

```text
/prd -> /architecture -> /plan -> /implementing-features -> /code-review
                                                         -> /security-scan
                                                         -> /legal-check
                                                         -> /e2e-testing
                                                         -> /performance
                                                         -> /refactoring

Auxiliary: /ui-ux-design, /hig-compliance, /design-system-audit, /adr, /review-fix
```

Each skill can be used standalone, as part of a team (multi-agent), or delegated to a one-off subagent (`.claude/agents/`).

## Teams

| Template | Purpose | Members | Skills |
| --- | --- | --- | --- |
| **`TEAM_PJM.md`** | **Full lifecycle management (recommended)** | **6** | **All skills covered** |
| `TEAM_FEATURE.md` | Feature development / bug fixes | 5 | 5 |
| `TEAM_QA.md` | Quality assurance / audit | 5 | 5 |
| `TEAM_PLANNING.md` | Design phase | 4 | 3 |
| `TEAM_DESIGN.md` | Design system integration | 5 | 4 |
| `TEAM_REFACTOR.md` | Refactoring | 4 | 5 |

## File Structure

```
project-blueprint-en/
+-- README.md                      Setup instructions & detailed guide
+-- setup.sh                       One-command setup script
+-- project-config.md              [Human+AI] Config file (13 sections)
+-- project-config.sample.md       Filled sample (task management app)
+-- input/requirements/            [Human] Requirement notes
+-- output/                        [AI-generated] PRD, design, tasks, quality reports
+-- docs/                          [AI-generated] Technical docs (auto-maintained)
+-- testreport/                    [AI-generated] Raw tool output (.gitignore target)
+-- .mcp.json.template             Shared MCP server configuration template
+-- .github/workflows/             Claude Code PR review workflow template
+-- .claude/
    +-- CLAUDE.md                  Development guide (moved to root during setup)
    +-- skills/                    15 skill definitions
    +-- teams/                     6 team definitions
    +-- agents/                    6 subagent definitions
    +-- rules/                     Language/path-specific rule extensions
    +-- hooks/                     9 hook scripts
    +-- pitfalls.md                Common pitfalls in AI-collaborative dev
    +-- tasks/                     Task instruction templates
```

## License

MIT
