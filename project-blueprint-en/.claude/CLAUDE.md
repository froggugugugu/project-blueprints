# Development Guide

Cross-project development rules, quality standards, and workflows.
Referenced by all roles (PM / PdM / Developer / Reviewer / Tester).

> **Project-specific parameters**: Consolidated in `project-config.md`.
> For details on tech stack, routing, data models, etc., refer to files under `docs/`.
> **Inviolable principles (7)**: Separated into `@constitution.md` (repo root).

## General

- Always respond in English
- Use subagents for research and debugging to conserve context
- Record important decisions periodically in markdown files
- CLAUDE.md contains only cross-cutting rules; detailed procedures are delegated to skills

## Skill catalog (all arguments optional, interactive confirmation when omitted)

| Skill | Purpose / trigger |
| ----- | ----------------- |
| `/brainstorm <requirement-note>` | Pre-`/prd` Socratic clarification (read-only) |
| `/prd <file>` | PRD generation from a requirement note (read-only) |
| `/architecture <file>` | System architecture design from a requirement note (read-only) |
| `/plan <description or file>` | Design document generation (read-only, for large changes) |
| `/adr <decision-title>` | Record design decision rationale as an ADR |
| `/implementing-features <task>` | Feature implementation and bug fixes via TDD |
| `/ui-ux-design <target>` | Design-system-aware UI/UX (a11y / dark mode included) |
| `/hig-compliance <target>` | Apple HIG-based system-wide UI consistency check |
| `/design-system-audit <target>` | Design token consistency audit & standardization |
| `/e2e-testing <feature>` | Playwright E2E test creation |
| `/code-review <target>` | Code review (read-only, pre-PR quality check) |
| `/security-scan <target>` | Vulnerability scan, OWASP ZAP, dependency audit (read-only) |
| `/legal-check <target>` | OSS license, privacy, IP legal compliance (read-only) |
| `/performance <target>` | Measurement-first performance optimization |
| `/refactoring <target>` | Large-scale code restructuring, responsibility migration |
| `/review-fix <PR#>` | Auto-fix CodeRabbit/Copilot review comments and push |

@.claude/rules/document-management.md  <!-- human/AI separation, docs/ ownership, conflict prevention -->

## Development principles

- When specifications are ambiguous, do not proceed by guessing — present 1-2 specific options and confirm
- Follow specification options if available; otherwise choose the simplest option and explicitly mark it as an assumption
- Delete or overwrite user data only when explicitly required by specifications
- Separate stored values and display values in data model and UI when they differ
- Be deterministic. Clearly define rounding modes, formats, and aggregation scopes
- Avoid over-engineering. Implement with the minimum complexity needed for current requirements
- Do not duplicate in documentation what can be read from code

## Architecture governance

Restrict dependency directions between layers. Rule details defined in `project-config.md` §4.4.

- Verify dependency direction violations with the detection command (in `project-config.md`)
- Circular dependencies are prohibited

## Quality standards

- Implement incrementally with test-first (TDD) approach (when enabled in `project-config.md` §6)
- Provide unit tests for important business logic
- Cover major user flows with E2E tests
- Test coverage targets are defined in `project-config.md` §6

## Quality reports and gates

@.claude/quality-gates.md  <!-- Report destinations, gate points, passage criteria -->

- Present quality evidence in human-readable format at each phase completion
- Quality gates are points where humans can intervene (intervention is optional)
- Reports separate `testreport/` (tool raw data) from `output/reports/` (human-readable summaries)
- Gates come in two types: **Skill gates (3)** and **Phase gates (5)**

## Concurrent development principles

- Avoid conflicts at the file level. Do not simultaneously edit the same file
- Changes to the shared layer are performed sequentially
- Pre-decompose large feature additions with `/plan` to identify parallelizable units
- When using Agent Teams, follow team templates under `.claude/teams/` (all arguments optional)
- **teammateMode selection**: Use `in-process` (fast) when members don't touch the same files; use `worktree` (git worktree isolation) when parallel branches are needed
- Team list with topology metadata: see `.claude/teams/README.md`
- The PJM team reads notes from `input/` and generates deliverables in `output/`
- The PL decomposes tasks, sets dependencies, and assigns them; members implement only assigned tasks

## Implementation workflow

1. Requirements confirmation: Present options and resolve ambiguities
2. Impact analysis: Check existing code, tests, and dependencies
3. Test design: Derive test cases from acceptance criteria
4. **🚏 Design Gate**: Present requirements interpretation and test approach, wait for confirmation
5. Implementation: Write the minimum code to pass tests
6. Refactor: Eliminate duplication, improve readability (keep tests green)
7. **🚏 Implementation Gate**: Present test results, coverage, and static analysis summary
8. Self-review: Verify with the checklist below
9. **🚏 Final Gate**: Present checklist fulfillment status as a list

## Implementation checklist

Verify before submitting design or code:

- [ ] Documented data model/schema changes
- [ ] Defined UI behavior (editable vs read-only)
- [ ] Clarified core algorithms (rounding, formatting, aggregation)
- [ ] Showed correspondence with acceptance criteria
- [ ] Confirmed existing tests are not broken
- [ ] Considered edge cases (empty arrays, boundary values, null)
- [ ] Updated documents under `docs/` to reflect implementation changes
- [ ] Confirmed no dependency direction rule violations
- [ ] Confirmed `--no-verify` was not used

## Communication standards

- Always provide rationale for technical decisions
- Present impact scope before starting specification changes
- Respond to review feedback with both the fix and the reason
- Mark uncertain assumptions as "[Assumption]"

## Tool usage policy

- Documentation reference priority:
  1. `docs/` files within the project
  2. Directly reference official sites with `WebFetch`
  3. Context7 MCP (only when official sites are insufficient)
  4. `WebSearch` (only when the latest information is needed)
- Playwright MCP: Used for E2E test debugging and visual verification
- draw.io MCP: Used for architecture diagrams and flow charts

## Security hardening

@.claude/guardrails.md         <!-- Hooks, deny rules, protected files, 3-layer defense -->
@.claude/pitfalls.md           <!-- Common failure patterns and mitigations -->
@.claude/permissions-guide.md  <!-- 3-tier permission operation: allowlist / auto / sandbox -->

> **Inviolable principles**: `@constitution.md`'s 7 principles are monitored by `scan-harness.sh`,
> which blocks AI attempts to violate them. Security policy details are in `project-config.md` §10.

- Always validate user input
- Regularly check dependency package vulnerabilities
- **3-layer defense**: Hooks (Layer 1) → Deny rules (Layer 2) → Allow rules (Layer 3)
- **Hook-based safety**: Active even with `--dangerously-skip-permissions`
- **SessionStart hook**: Auto-checks `project-config.md` / `docs/` / `settings.local.json` at session start

## Git operations and commit conventions

@.claude/rules/git-conventions.md  <!-- --no-verify ban, Conventional Commits 11 prefixes -->

## Project-specific information

Recommended loading order: `constitution.md` (immutable) → `project-config.md` (human decisions)
→ `docs/` (AI-generated detail) → this file (cross-cutting rules)

@docs/project.md              <!-- Tech stack, commands, routing, store list -->
@docs/architecture.md          <!-- Directory structure, test list, doc ownership -->
@docs/data-model.md            <!-- Schema definitions, field specs, validation -->
@docs/development-patterns.md  <!-- Code conventions, pitfalls, design system -->

> **Fallback**: If the above files don't exist (e.g., right after setup), refer to the
> corresponding sections in `project-config.md`. Same applies for stub state (under 5 lines).

## Phase-specific output styles

`.claude/output-styles/` ships 4 phase-specific output styles (switch via `/output-style phase-prd` etc.).

| Phase | Recommended style | Key traits |
| ----- | ----------------- | ---------- |
| Requirements | `phase-prd` | Question-driven, [Needs confirmation] markers, no code |
| Design | `phase-design` | Decision rationale, trade-offs, ADR candidates |
| Implementation | `phase-implementation` | TDD (Red-Green-Refactor), minimum diff |
| Review / QA | `phase-review` | Severity classification, evidence-based, fix proposals |

`statusLine` (`.claude/statusline.sh`) auto-displays the current style and phase.

## Workflow control

### 1. Plan first

- Start non-trivial tasks (3+ steps or involving architectural decisions) in plan mode
- If unexpected problems arise, immediately revise the plan — do not push through
- Include verification steps in the plan (design confirmation procedures, not just implementation)
- Write detailed specifications upfront to reduce ambiguity

### 2. Research first

- **Always investigate before implementing** — check existing code, patterns, and official docs first
- Existing implementation check: Use Glob/Grep to find similar features and utilities
- Official docs reference: Fetch latest info via WebFetch → Context7 priority order
- Prevent "reinventing the wheel" — reuse existing functions and components

### 3. Subagent strategy

@.claude/agents/README.md  <!-- Project default subagent definitions and selection guide -->

- Actively use subagents to avoid overloading the main context
- Delegate research, exploration, and parallel analysis to subagents
- 1 subagent = 1 task, focused-scope execution

@.claude/rules/workflow-advanced.md  <!-- Self-improvement, verification, elegance, autonomy, task management, core principles -->
