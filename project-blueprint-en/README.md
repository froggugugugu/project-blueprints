# Project Blueprint

AI-collaborative development environment template for Claude Code projects.

Consolidate all project-specific human decisions into a **single `project-config.md` file**,
and let AI automatically generate and maintain design artifacts such as routing maps, store inventories, and data models.

---

## Setup Instructions

### Method A: One-command setup with setup.sh (recommended)

```bash
bash setup.sh /path/to/your-project
```

This single command handles everything:
- Copies `.claude/`, `docs/`, `input/`, `output/`, `testreport/`, and `project-config.md`
- Places `CLAUDE.md` at the project root
- Adds `testreport/` to `.gitignore`
- Automatically backs up any existing `.claude/` to `.claude.bak/`

### Method B: Manual copy

```bash
cp -r project-blueprint-en/.claude /path/to/new-project/.claude
cp -r project-blueprint-en/docs /path/to/new-project/docs
cp -r project-blueprint-en/input /path/to/new-project/input
cp -r project-blueprint-en/output /path/to/new-project/output
cp -r project-blueprint-en/testreport /path/to/new-project/testreport
cp project-blueprint-en/project-config.md /path/to/new-project/project-config.md

# Move CLAUDE.md to the project root (removing the copy inside .claude/)
mv /path/to/new-project/.claude/CLAUDE.md /path/to/new-project/CLAUDE.md
```

### 2. Fill in project-config.md

> For a fully filled example, see [project-config.sample.md](project-config.sample.md) (a task management app used as a reference with all sections completed).

**Required sections** (minimum needed to get started):

| Section | Content |
| --- | --- |
| 1. Project Basics | Name, description, language |
| 2. Tech Stack | Frameworks and libraries in use |
| 3. Commands | Dev, test, and build commands |
| 6. Quality Standards | Coverage target, TDD on/off |

**Recommended sections** (filling these in improves output quality):

| Section | Content |
| --- | --- |
| 4. Architecture | Patterns, dependency rules |
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

---

## Quick Start (after setup)

Once setup is complete, start developing with these steps.

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
|  .claude/CLAUDE.md ............ Development guide         |
|  .claude/skills/ .............. 11 skill definitions      |
|  .claude/teams/ ............... 5 team definitions        |
|  .claude/tasks/ ............... Task instruction templates |
|  .claude/settings.json ........ Plugin configuration      |
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
+-- setup.sh                               <-- One-command setup script
+-- project-config.md                      <-- [Human+AI] Config file (12 sections)
+-- project-config.sample.md               <-- Filled sample (task management app)
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
+-- .claude/
|   +-- CLAUDE.md                          <-- [Generic] Development guide
|   +-- settings.json                      <-- [Generic] Plugin configuration
|   +-- settings.local.json.template       <-- [Customizable] Permission settings template
|   |
|   +-- skills/                            <-- [Generic] 11 skill definitions
|   |   +-- plan/SKILL.md                    Planning & design
|   |   +-- implementing-features/SKILL.md   TDD implementation
|   |   +-- ui-ux-design/SKILL.md            UI/UX design
|   |   +-- e2e-testing/SKILL.md             E2E testing
|   |   +-- code-review/SKILL.md             Code review
|   |   +-- performance/SKILL.md             Performance optimization
|   |   +-- refactoring/SKILL.md             Refactoring
|   |   +-- legal-check/SKILL.md             IT legal compliance check
|   |   +-- security-scan/                   Security scan
|   |   |   +-- SKILL.md
|   |   |   +-- SETUP_GUIDE.md                 Tool setup guide
|   |   +-- prd/SKILL.md                     PRD generation
|   |   +-- architecture/SKILL.md            Architecture design
|   |
|   +-- teams/                             <-- [Generic] 5 team definitions
|   |   +-- README.md                        Team usage guide
|   |   +-- TEAM_PJM.md                      Full lifecycle management
|   |   +-- TEAM_FEATURE.md                  Feature development
|   |   +-- TEAM_QA.md                       Quality assurance
|   |   +-- TEAM_PLANNING.md                 Design phase
|   |   +-- TEAM_REFACTOR.md                 Refactoring
|   |
|   +-- tasks/                             <-- [Generic] Task templates
|       +-- TASK_TEMPLATE.md                 Feature development instructions
|       +-- TASK_REVIEW_TEMPLATE.md          Review instructions
|       +-- LESSONS_TEMPLATE.md              Lessons learned template
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
| **`TEAM_PJM.md`** | **Full lifecycle management (recommended)** | **6** | **11/11** |
| `TEAM_FEATURE.md` | Feature development / bug fixes | 5 | 5 |
| `TEAM_QA.md` | Quality assurance / audit | 5 | 5 |
| `TEAM_PLANNING.md` | Design phase | 4 | 3 |
| `TEAM_REFACTOR.md` | Refactoring | 4 | 5 |

For team selection guidance, workflow details, launch patterns, and skill coverage, see `.claude/teams/README.md`.

### Skills (all 11)

All skills accept optional arguments. When omitted, the user is prompted interactively.
Read-only skills use `context: fork` (executed on a copy of the conversation context).

| Skill | Command | Mode | project-config.md Updates |
| ------ | -------- | ------ | ---------------------- |
| PRD | `/prd <file-path>` | Read-only | -- |
| Architecture | `/architecture <file-path>` | Read-only | -- |
| Plan | `/plan <description or file-path>` | Read-only | May update S11 |
| Implementing Features | `/implementing-features <task-file or instructions>` | Read/Write | Updates S2, S3, S11 |
| UI/UX Design | `/ui-ux-design <target-file or instructions>` | Review/Implement | -- |
| Code Review | `/code-review <target-file or instructions>` | Read-only | -- |
| E2E Testing | `/e2e-testing <target-feature or instructions>` | Read/Write | -- |
| Performance | `/performance <target or instructions>` | Read/Write | Updates S11 |
| Refactoring | `/refactoring <target-directory or instructions>` | Read/Write | -- |
| Security Scan | `/security-scan <scope or instructions>` | Read-only | -- |
| Legal Check | `/legal-check <scope or instructions>` | Read-only | -- |

Skill pipeline: `/prd` -> `/architecture` -> `/plan` -> `/implementing-features` -> `/code-review` + `/security-scan` + `/e2e-testing` + `/performance`

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

Using `setup.sh` completes everything in one command, including automatic backup of any existing `.claude/`:

```bash
bash setup.sh /path/to/existing-project
```

For manual setup (back up any existing `.claude/` first):

```bash
# Back up existing .claude/ if present
[ -d /path/to/project/.claude ] && mv /path/to/project/.claude /path/to/project/.claude.bak

cp -r project-blueprint-en/.claude /path/to/project/.claude
cp -r project-blueprint-en/docs /path/to/project/docs
cp -r project-blueprint-en/input /path/to/project/input
cp -r project-blueprint-en/output /path/to/project/output
cp -r project-blueprint-en/testreport /path/to/project/testreport
cp project-blueprint-en/project-config.md /path/to/project/project-config.md

mv /path/to/project/.claude/CLAUDE.md /path/to/project/CLAUDE.md
```

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

### 4. Migrating from an existing .claude/

If your backed-up `.claude.bak/` contains project-specific settings:

- `settings.local.json` -> Merge into the new template
- Custom skills -> Copy into `.claude/skills/`
- memory/ -> Located outside `.claude/` at the user level, so no impact
