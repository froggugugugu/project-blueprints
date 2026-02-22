---
name: prd
description: >
  Generates a PRD (Product Requirements Document) from requirement notes or memos.
  Triggers: prd, requirements, PRD generation, requirement specification.
  Source-code read-only — never modifies source code or test files.
  Outputs structured PRD to output/prd/ (requires Write permission to output/prd/).
  Takes a file path as argument: /prd <file-path>
context: fork
---

# PRD Generator

A skill that takes requirement notes/memos as input and generates a structured
PRD (Product Requirements Document) optimized for Claude Code comprehension.
**Never modifies source code.**

## Prerequisites

| Reference File | Purpose | Fallback When Stub |
| -------------- | ------- | ------------------ |
| `docs/project.md` | Tech stack, routing | Refer directly to `project-config.md` §1–§3 |
| `docs/architecture.md` | Directory structure, test placement | Refer directly to `project-config.md` §4 |
| `docs/data-model.md` | Existing schemas | Skip (not yet generated for new projects) |
| `docs/development-patterns.md` | Code conventions, pitfalls | Refer directly to `project-config.md` §11 |

PRD generation is possible even when `docs/` contains only stubs. Falls back to referencing `project-config.md` directly.

## Core Principles

- Read-only (source code modification prohibited)
- Faithfully reflect input file content (do not add or remove requirements arbitrarily)
- Mark ambiguous descriptions as "[Needs Confirmation]" and present options
- Output is intended for human review and approval
- Maintain consistency with existing `docs/` documentation

## Usage

```
/prd <path-to-requirement-notes>
```

File paths can be absolute or relative.
Specify multiple files separated by spaces.

### Examples

```text
/prd requirements.md
/prd input/requirements/REQ_001.md
/prd memo1.md memo2.md
```

### Output Destination

- Default: `output/prd/PRD_<feature-name>.md` (when `output/` directory exists)
- Fallback: `docs/PRD.md`

### Integration with Other Skills

| Previous Step | This Skill | Next Step |
| ------------- | ---------- | --------- |
| Requirement note creation | `/prd` | `/architecture` → `/plan` → `/implementing-features` |

## Workflow

### Phase 1: Input Analysis

1. **File Reading** — Read the provided files using the `Read` tool
2. **Structural Analysis** — Classify the types of requirements:
   - New feature additions
   - Changes/improvements to existing features
   - Bug fixes
   - Non-functional requirements (performance, security, etc.)
3. **Terminology Extraction** — Extract and define domain-specific terms

### Phase 2: Current State Investigation

1. **Existing Codebase Survey** — Identify related existing features, components, and stores
2. **Existing Documentation Review** — Check related information under `docs/`
3. **Technical Constraints** — Organize constraints from tech stack and architecture

### Phase 3: PRD Generation

1. **Structuring** — Generate the PRD following the output format below
2. **Consistency Check** — Verify no contradictions or gaps between requirements
3. **Ambiguity Flagging** — Mark items requiring decisions as "[Needs Confirmation]"

### Phase 4: Output

1. **File Output** — Write to `output/prd/PRD_<feature-name>.md` (or `docs/PRD.md` if `output/` doesn't exist)
2. **Summary Presentation** — Present a PRD overview to the user

## Output Format

```markdown
# PRD: [Feature/Project Name]

> Source: [Input file name]
> Generated: [YYYY-MM-DD]
> Status: Draft

## 1. Overview

### 1.1 Background & Purpose
### 1.2 Scope

#### In Scope
#### Out of Scope

## 2. Terminology

| Term | Definition |
| ---- | ---------- |

## 3. Functional Requirements

### FR-001: [Feature Name]
- **Summary**: [Feature description]
- **User Story**: As a [who], I want to [what] so that [why]
- **Acceptance Criteria**:
  - [ ] [Specific condition]
- **Screen/Interaction Flow**: [UI behavior description]
- **Data Model Changes**: [Required schema changes]
- **Priority**: Must / Should / Could / Won't

## 4. Non-Functional Requirements

### NFR-001: [Requirement Name]
- **Category**: Performance / Security / Usability / Maintainability
- **Requirement**: [Specific criteria]
- **Measurement Method**: [How to verify]

## 5. Data Model

### New Schemas
### Existing Schema Changes

| Schema | Field | Change Description | Backward Compatibility |
| ------ | ----- | ------------------ | ---------------------- |

## 6. Screen/UI Specifications
## 7. Technical Considerations
## 8. Test Strategy
## 9. Implementation Phases (Recommended)
## 10. Items Requiring Confirmation

| # | Item | Options | Impact Scope |
| - | ---- | ------- | ------------ |

## 11. Risks & Concerns

| Risk | Impact Level | Mitigation |
| ---- | ------------ | ---------- |
```

## Output Contract

### Section Definitions

| # | Section | Required | Constraints |
| - | ------- | -------- | ----------- |
| 1 | Overview (Background/Purpose, Scope) | ✅ | Explicitly separate in-scope/out-of-scope |
| 2 | Terminology | ✅ | Define domain-specific terms in a table. Minimum 1 entry |
| 3 | Functional Requirements | ✅ | FR-NNN format IDs. Each FR must have acceptance criteria |
| 4 | Non-Functional Requirements | Conditional | When input memo contains non-functional requirements |
| 5 | Data Model | ✅ | New/changed schemas. State backward compatibility |
| 6 | Screen/UI Specifications | ✅ | Paths, layout, dark mode support |
| 7 | Technical Considerations | ✅ | Architecture impact, dependency direction |
| 8 | Test Strategy | ✅ | Unit/E2E targets and approach |
| 9 | Implementation Phases | ✅ | Phase-based. State dependencies |
| 10 | Items Requiring Confirmation | Conditional | When ambiguous decision points exist |
| 11 | Risks & Concerns | Conditional | When risks exist |

### Functional Requirement (FR) Writing Constraints

- FR IDs are sequential from `FR-001`, zero-padded to 3 digits
- Acceptance criteria use "shall" phrasing (verifiable statements)
- Priority enumeration values: `Must` / `Should` / `Could` / `Won't`

### Vocabulary Constraints

| Term | Definition |
| ---- | ---------- |
| [Needs Confirmation] | Ambiguous point requiring user decision. Include options alongside |
| In Scope | Features/changes covered by this PRD |
| Out of Scope | Features/changes explicitly excluded |
| Backward Compatible | Existing data reading is not broken |

### Structural Constraints

- Sections are output in numerical order (1–11)
- Do not add requirements to FRs that are not in the input memo
- Do not decide technology choices; present options and rationale
- [Needs Confirmation] must always include options (Option A/Option B) and impact scope

## PRD Quality Checklist

- [ ] All requirements from the input memo are reflected in FR/NFR
- [ ] Each functional requirement has acceptance criteria
- [ ] Acceptance criteria are specific and testable
- [ ] Data model changes consider backward compatibility
- [ ] Consistent with existing architecture
- [ ] Ambiguous points are flagged as "[Needs Confirmation]"
- [ ] Terminology is consistent throughout
- [ ] In scope/out of scope are clearly defined

## Consistency with Existing Documentation

Reference the following documents during PRD generation to ensure consistency:

| Document | Reference Purpose |
| -------- | ----------------- |
| `docs/project.md` | Tech stack, routing, store list |
| `docs/architecture.md` | Directory structure, test placement |
| `docs/data-model.md` | Existing schemas, validation rules |
| `docs/development-patterns.md` | Code conventions, pitfalls |

## Output Files

- When `output/prd/` directory exists: `output/prd/PRD_<feature-name>.md`
- Fallback: `docs/PRD.md`
- If already exists: Confirm overwrite with the user
- When multiple PRDs are needed: Name as `PRD_<feature-name>.md`

## Prohibited Actions

- Modifying source code (including test files)
- Adding requirements not in the input memo (do not inflate features with guesses)
- Making final technology decisions (limit to presenting options and rationale)
- Including project-specific data (IDs, passwords, etc.) in documentation
- Modifying existing documentation (under `docs/`)
