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

**1 config file + 11 skills + 5 teams + 5 quality gates** -- scales from solo to team development.

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
- **11 skills**: PRD generation, architecture design, TDD implementation, code review, E2E testing, security scanning, and more
- **5 team templates**: From full lifecycle management to feature development, QA, and refactoring
- **5 quality gates**: Checkpoints where humans can review and approve at each phase
- **Input/Output separation**: Clear separation between human requirements (`input/`) and AI deliverables (`output/`)

## Skill Pipeline

```
/prd -> /architecture -> /plan -> /implementing-features -> /code-review
                                                         -> /security-scan
                                                         -> /e2e-testing
                                                         -> /performance
```

Each skill can be used standalone or as part of a team (multi-agent).

## Teams

| Template | Purpose | Members | Skills |
| --- | --- | --- | --- |
| **`TEAM_PJM.md`** | **Full lifecycle management (recommended)** | **6** | **11/11** |
| `TEAM_FEATURE.md` | Feature development / bug fixes | 5 | 5 |
| `TEAM_QA.md` | Quality assurance / audit | 5 | 5 |
| `TEAM_PLANNING.md` | Design phase | 4 | 3 |
| `TEAM_REFACTOR.md` | Refactoring | 4 | 5 |

## File Structure

```
project-blueprint-en/
+-- README.md                      Setup instructions & detailed guide
+-- setup.sh                       One-command setup script
+-- project-config.md              [Human+AI] Config file (12 sections)
+-- project-config.sample.md       Filled sample (task management app)
+-- input/requirements/            [Human] Requirement notes
+-- output/                        [AI-generated] PRD, design, tasks, quality reports
+-- docs/                          [AI-generated] Technical docs (auto-maintained)
+-- testreport/                    [AI-generated] Raw tool output (.gitignore target)
+-- .claude/
    +-- CLAUDE.md                  Development guide (moved to root during setup)
    +-- skills/                    11 skill definitions
    +-- teams/                     5 team definitions
    +-- tasks/                     Task instruction templates
```

## License

MIT
