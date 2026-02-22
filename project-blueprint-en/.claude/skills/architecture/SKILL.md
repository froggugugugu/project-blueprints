---
name: architecture
description: >
  Designs system architecture from requirement notes and generates architecture.md.
  Triggers: architecture, system design, structure design, layer design.
  Source-code read-only — never modifies source code or test files.
  Outputs structured architecture document to output/design/ (requires Write permission to output/design/).
  Takes a file path as argument: /architecture <file-path>
context: fork
---

# Architecture Designer

A skill that takes requirement notes, memos, or PRD files as input and designs/generates
a structured system architecture document optimized for Claude Code comprehension.
**Never modifies source code.**

## Prerequisites

No prerequisite files. This skill is the one that generates `docs/architecture.md` and `docs/project.md`.
Input: `project-config.md` §1–§4 + requirement note files.

## Core Principles

- Read-only (source code modification prohibited)
- Faithfully translate input file requirements into architecture
- Present technology choices as options with rationale; defer decisions to the user
- Mark ambiguous design decisions as "[Needs Confirmation]" and present options
- Output is intended for human review and approval
- Avoid over-engineering; design with the minimum sufficient structure for the requirements

## Usage

```bash
/architecture <path-to-requirement-notes>
```

File paths can be absolute or relative.
Specify multiple files separated by spaces.

### Examples

```text
/architecture input/requirements/REQ_001.md
/architecture output/prd/PRD_auth.md
/architecture memo1.md memo2.md
```

### Output Destination

- Default: `output/design/ARCH_<feature-name>.md` (when `output/` directory exists)
- Fallback: `docs/architecture.md`

## Workflow

### Phase 1: Input Analysis

1. **File Reading** — Read the provided files using the `Read` tool
2. **Requirements Extraction** — Classify requirements that affect architecture:
   - Functional requirements (number of screens, data types, processing flows)
   - Non-functional requirements (performance, scalability, security)
   - Technical constraints (specified technologies, integration with existing systems)
   - Operational requirements (deployment, monitoring, backup)
3. **Scale Assessment** — Estimate the system's scale and complexity

### Phase 2: Existing Codebase Survey (For Existing Projects)

1. **Directory Structure** — Understand the current source structure using `Glob` / `Read`
2. **Dependencies** — Check package/module dependencies
3. **Existing Patterns** — Identify architecture patterns currently in use
4. **Existing Documentation** — Review related information under `docs/`

### Phase 3: Architecture Design

1. **Layer Design** — Define responsibility separation and dependency directions between layers
2. **Module Decomposition** — Determine module boundaries for each feature
3. **Data Flow Design** — Define data flow and state management approach
4. **Technology Selection** — Organize technology candidates and selection rationale for each layer
5. **Consistency Check** — Verify no gaps in requirement coverage

### Phase 4: Output

1. **File Output** — Write to `output/design/ARCH_<feature-name>.md` (or `docs/architecture.md` if `output/` doesn't exist)
2. **Summary Presentation** — Present the architecture overview and key design decisions to the user

## Output Format

```markdown
# Architecture: [System/Project Name]

> Source: [Input file name]
> Generated: [YYYY-MM-DD]
> Status: Draft

## 1. Architecture Overview

### 1.1 Design Principles
[Fundamental architectural principles and rationale for adoption]

### 1.2 System Diagram
[Text-based diagram. ASCII or Mermaid format]

### 1.3 Key Design Decisions

| # | Decision Point | Decision | Rationale |
| - | -------------- | -------- | --------- |
| 1 | [Decision point] | [Adopted approach] | [Rationale] |

## 2. Technology Stack

| Category | Technology | Version | Selection Rationale |
| -------- | ---------- | ------- | ------------------- |
| Language | ... | ... | ... |
| Framework | ... | ... | ... |

## 3. Layer Structure

### 3.1 Layer Definitions

| Layer | Responsibility | Allowed Dependencies |
| ----- | -------------- | -------------------- |
| [Layer name] | [Responsibility] | [Dependency targets] |

### 3.2 Dependency Direction Rules

[Prohibited dependency directions in bullet point format]

### 3.3 Verification Method

[Dependency direction verification commands/tools]

## 4. Directory Structure

[Tree format. Annotate each directory with a comment for its responsibility]

## 5. Module Design

### 5.1 Feature Module List

| Module | Responsibility | Key Components | Dependent Stores |
| ------ | -------------- | -------------- | ---------------- |
| [name] | [Responsibility] | [Component names] | [Store names] |

### 5.2 Inter-Module Communication

[Data flow and communication methods between modules]

## 6. State Management Design

### 6.1 Store List

| Store | Responsibility | Persistence | Storage Key |
| ----- | -------------- | ----------- | ----------- |
| [name] | [Responsibility] | Yes/No | [Key name] |

### 6.2 Persistence Strategy
### 6.3 Inter-Store Reference Rules

## 7. Data Flow

### 7.1 Data Flow
### 7.2 Validation Strategy

## 8. Routing Design

| Path | Page | Feature |
| ---- | ---- | ------- |
| [path] | [PageComponent] | [Feature name] |

## 9. UI Design Approach

### 9.1 Component Design
### 9.2 Styling Approach
### 9.3 Dark Mode Support

## 10. Test Strategy

### 10.1 Test Structure

| Type | Tool | Target | Placement |
| ---- | ---- | ------ | --------- |
| Unit | [Tool name] | [Target] | [Placement] |

### 10.2 Test Approach

## 11. Entry Point and Provider Structure
## 12. Security Design
## 13. Development Environment & Toolchain

### 13.1 Command List
### 13.2 Git Hooks
### 13.3 CI/CD

## 14. Documentation Structure

| File | Responsibility |
| ---- | -------------- |
| docs/project.md | Tech stack, commands, routing, store list |
| docs/architecture.md | Directory structure, layer design, test structure |
| docs/data-model.md | Schema definitions, field specs, validation |
| docs/development-patterns.md | Code conventions, pitfalls, anti-patterns |

## 15. Items Requiring Confirmation

| # | Item | Options | Impact Scope |
| - | ---- | ------- | ------------ |

## 16. Future Extension Points
```

## Output Contract

### Section Definitions

| # | Section | Required | Constraints |
| - | ------- | -------- | ----------- |
| 1 | Architecture Overview (Design principles, Diagram, Key decisions) | ✅ | Diagram in ASCII or Mermaid format |
| 2 | Technology Stack | ✅ | Table format. Include selection rationale per row |
| 3 | Layer Structure (Definitions, Dependency directions, Verification) | ✅ | State prohibited dependencies in bullet points |
| 4 | Directory Structure | ✅ | Tree format in `text` code block. Add `#` comments to each directory |
| 5 | Module Design (List, Communication) | ✅ | Table listing responsibilities, components, and dependent stores |
| 6 | State Management Design (Store list, Persistence, Reference rules) | ✅ | State persistence pattern |
| 7 | Data Flow | ✅ | User action → UI → Store → Storage flow |
| 8 | Routing Design | ✅ | Table format (Path, Page, Feature) |
| 9 | UI Design Approach | ✅ | Container/Presentational, Styling, Dark mode |
| 10 | Test Strategy | ✅ | Table format (Type, Tool, Target, Placement) |
| 11 | Entry Point and Provider Structure | ✅ | State provider ordering |
| 12 | Security Design | ✅ | XSS mitigation, Data protection, Validation |
| 13 | Development Environment & Toolchain | ✅ | Command list, Git Hooks |
| 14 | Documentation Structure | ✅ | Table format (File, Responsibility) |
| 15 | Items Requiring Confirmation | Conditional | When design decisions are needed |
| 16 | Future Extension Points | Conditional | When future considerations exist |

### Vocabulary Constraints

| Term | Definition |
| ---- | ---------- |
| Layer | A code classification unit with controlled dependency direction |
| Module | A feature module directory that implements a specific business function, following the chosen architecture pattern |
| Persistence Pattern | The method for saving data to storage |
| [Needs Confirmation] | A design decision requiring user judgment. Include options alongside |

### Structural Constraints

- Sections are output in numerical order (1–16)
- Table cells must not be empty (use `—` when not applicable)
- Directory trees are written inside `text` code blocks
- Annotate each directory with `# comment` for its responsibility
- Do not decide technology choices; present options and rationale

## Design Principles

### Responsibility Separation

- Define each layer/module's responsibility as single and clear
- Allow dependency direction only from upper to lower (one-way)
- Prohibit direct dependencies between feature modules; coordinate through the shared layer

### Claude Code Readability

- **Use table format extensively** — Present information with high scannability as tables
- **Directory trees** — Show tree structure in `text` code blocks
- **Annotation** — Add `#` comments to each directory in the tree
- **Consistent path notation** — Use `src/...` format consistently
- **Explicit dependency rules** — List prohibitions in bullet points
- **Numbered sections** — Number sections for easy reference

### Minimum Sufficiency Principle

- Design with minimum sufficient complexity for the requirements
- Do not create abstractions for "might need in the future"
- State extension points but do not implement them now

## Quality Checklist

- [ ] Input memo requirements are reflected in the architecture
- [ ] Each layer's responsibility is clearly defined
- [ ] Dependency direction rules are stated
- [ ] Directory structure is in tree format
- [ ] All modules' responsibilities and dependencies are listed
- [ ] State management approach and persistence pattern are defined
- [ ] Test strategy (type, tool, placement) is defined
- [ ] Security design is included
- [ ] Ambiguous decision points are flagged as "[Needs Confirmation]"
- [ ] Command list is comprehensive
- [ ] Documentation structure is defined

## Output Files

- When `output/design/` directory exists: `output/design/ARCH_<feature-name>.md`
- Fallback: `docs/architecture.md`
- If already exists: Present options to the user (overwrite / save with different name / diff merge)

## Investigation Tools

- `Glob` / `Grep` — File and code search
- `Read` — File content review
- Dependency direction check command (when documented in `project-config.md`)

## Integration with Other Skills

| Previous Step | This Skill | Next Step |
| ------------- | ---------- | --------- |
| `/prd` for requirements definition | `/architecture` for design | `/plan` for task breakdown → `/implementing-features` for implementation |

## Prohibited Actions

- Modifying source code (including test files)
- Adding requirements not in the input memo (do not inflate features with guesses)
- Making final technology decisions (limit to presenting options and rationale)
- Including project-specific data (IDs, passwords, etc.) in documentation
- Unauthorized modification of existing `docs/` files
