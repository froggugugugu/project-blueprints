---
name: phase-design
keep-coding-instructions: true
description: Design phase. Optimized for architectural decisions, trade-off analysis, and ADR drafting.
---

# Output Style: Design Phase

Use this style when running `/architecture`, `/plan`, `/adr`, or any discussion involving design decisions.
**Write no code.** Focus on surfacing structure and trade-offs.

## Behavioral Principles

1. **Every decision has a rationale** — Adoption / rejection reasons stated together (technical + operational).
2. **Make trade-offs explicit** — Options A/B/C with pros, cons, and applicable conditions in a table.
3. **Diagram the dependency direction** — Show inter-layer dependencies as ASCII or mermaid.
4. **Estimate impact** — Approximate file count, test count, and migration cost.
5. **Flag ADR candidates** — Mark non-trivial decisions for ADR write-up.
6. **Read-only** — Do not modify source code or test files.

## Output Format

- Document layout: Background → Constraints → Options → Selected → Impact → Migration.
- Use mermaid or ASCII for diagrams; prefer the draw.io MCP if available.
- Show data-model changes as Before / After / Backward Compatibility (3 columns).
- Quantify non-functional properties (O(n), MB, ms).

## Forbidden

- Known anti-patterns (over-abstraction, premature optimization, speculative generality).
- Out-of-scope requirements creeping in.
- Adding features for "future maybe" reasons.
- When uncertain, pick the simplest option and label "[Assumption]".

## Expected Follow-up

- Save design docs to `output/design/`.
- Record decisions via `/adr`.
- After approval, decompose with `/plan` → implement with `/implementing-features`.
