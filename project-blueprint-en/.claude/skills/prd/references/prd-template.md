# prd — Output templates

> Skeletons referenced from SKILL.md. Copy the structure and fill it in.

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
- **Acceptance Criteria** (EARS form recommended: "WHEN [condition/event] THE SYSTEM SHALL [behavior]"; one criterion maps to one test):
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
