# architecture — Output templates

> Skeletons referenced from SKILL.md. Copy the structure and fill it in.

## Contents

- Output Format
- 1. Architecture Overview
- 2. Technology Stack
- 3. Layer Structure
- 4. Directory Structure
- 5. Module Design
- 6. State Management Design
- 7. Data Flow
- 8. Routing Design
- 9. UI Design Approach
- 10. Test Strategy
- 11. Entry Point and Provider Structure
- 12. Security Design
- 13. Development Environment & Toolchain
- 14. Documentation Structure
- 15. Items Requiring Confirmation
- 16. Future Extension Points

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
