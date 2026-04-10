---
name: adr
version: 1.0.0
description: >
  This skill should be used when the user asks to "record a design decision", "create an ADR", "document architecture decisions",
  or mentions "ADR", "architecture decision record", "design rationale", "why this design", "decision log".
  Creates and manages Architecture Decision Records (ADRs) to capture the context, rationale, and consequences of architectural decisions.
  Takes optional argument: /adr <decision title or instruction>
argument-hint: "<decision title or instruction>"
---

# ADR — Architecture Decision Records

A skill for recording and tracking important architectural decisions in **Nygard format**.

Captures "why this design was chosen", "what alternatives were considered", and "what trade-offs exist"
in a form that future developers (human or AI) can understand.

> **Relationship with existing skills**:
> - `/architecture`: Generates system-wide structural design documents → **The design itself**
> - `/adr` (this skill): Records the "rationale and context" of individual design decisions → **Decision records**
> - `/plan`: Task decomposition for implementation planning → **Execution plan**

---

## Prerequisites

| Reference File | Purpose |
| -------------- | ------- |
| `project-config.md` §4 | Architecture fundamentals |
| `docs/architecture.md` | Current architecture structure |
| `output/design/` | `/architecture` skill output (if available) |

---

## Usage

```text
/adr                                          # Interactively confirm decision and create ADR
/adr Change auth from JWT to session-based    # Create ADR with specified title
/adr --list                                   # List existing ADRs
/adr --update ADR_003                         # Update status of existing ADR
```

### Output Destinations

- ADR files: `output/design/ADR_NNN_<title>.md`
- ADR index: `output/design/ADR_INDEX.md`

---

## Workflow

### Step 1: Identify the Decision

Create an ADR when any of the following apply:

| Decision Category | Examples |
| ----------------- | -------- |
| Technology selection | Framework, library, database choices |
| Architecture patterns | Layer structure, API design approach, state management |
| Quality attribute trade-offs | Performance vs maintainability, consistency vs availability |
| Convention establishment | Naming rules, directory structure, error handling policy |
| Existing design changes | Direction changes in existing architecture |

### Step 2: Context Investigation

Investigate in parallel using subagents:

1. **Current state analysis**: Check related parts of existing codebase with Grep/Read
2. **Constraint identification**: Review constraints in `project-config.md`
3. **Prior ADR check**: Review related past decisions in `output/design/ADR_INDEX.md`

### Step 3: Evaluate Alternatives

Consider at least 2 alternatives, and for each:

- **Pros**: Advantages of this option (be specific)
- **Cons**: Disadvantages of this option (be specific)
- **Rejection reason** (for unchosen options only): Why this option was not selected

### Step 4: Create ADR

Follow this template:

```markdown
# ADR-NNN: [Decision Title]

## Status

[Proposed | Accepted | Deprecated | Superseded by ADR-XXX]

## Context

[Background, situation, and problem that necessitated this decision]

## Decision

[Clearly state the chosen approach in one sentence]

[Detailed explanation of the decision]

## Alternatives Considered

### Alternative A: [Name]

- **Pros**: ...
- **Cons**: ...
- **Rejection reason**: ...

### Alternative B: [Name]

- **Pros**: ...
- **Cons**: ...
- **Rejection reason**: ...

## Consequences

### Positive

- ...

### Negative / Risks

- ...

### Related Decisions

- [ADR-XXX](ADR_XXX_title.md): [Relationship description]

## References

- [Links to reference materials or literature]
```

### Step 5: Update Index

Add new entry to `output/design/ADR_INDEX.md`:

```markdown
# Architecture Decision Records

| # | Title | Status | Date |
|---|-------|--------|------|
| ADR-001 | [Title](ADR_001_title.md) | Accepted | YYYY-MM-DD |
| ADR-002 | [Title](ADR_002_title.md) | Proposed | YYYY-MM-DD |
```

---

## ADR Lifecycle

```text
Proposed → Accepted → (Deprecated | Superseded by ADR-XXX)
```

| Status | Meaning |
| ------ | ------- |
| **Proposed** | Under proposal. Awaiting review |
| **Accepted** | Approved. Current policy |
| **Deprecated** | No longer recommended. No longer applies |
| **Superseded** | Replaced by a subsequent ADR |

When changing status, append the reason and date to the ADR body.

---

## Output Contract

| Section | Required | Constraints |
| ------- | -------- | ----------- |
| Status | Yes | Proposed / Accepted / Deprecated / Superseded |
| Context | Yes | Detailed enough for a third party to understand |
| Decision | Yes | Clear in one sentence. Details follow |
| Alternatives | Yes | Minimum 2 options. Each with pros/cons |
| Consequences | Yes | Both positive and negative aspects |
| Index update | Yes | Add to ADR_INDEX.md |

---

## Prohibited Actions

- Recording a decision without considering alternatives
- Vague rationale like "it's common" or "seemed right"
- Leaving contradictions with existing ADRs unresolved (use Superseded to explicitly update)
- Bypassing hooks with `--no-verify`
- Force pushing with `--force`
