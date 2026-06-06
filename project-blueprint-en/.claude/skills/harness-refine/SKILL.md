---
name: harness-refine
version: 1.0.0
description: >
  This skill should be used when the user asks to "refine the harness", "self-improve the blueprint",
  "restructure .claude/ to match best practices", "audit harness configuration",
  or mentions "harness refine", "best-practice alignment", "self-refine",
  "harness self-audit", "rework skill/agent/team layout".
  Scope is limited to harness scaffolding — `.claude/` (skills / agents / teams / rules / output-styles),
  CLAUDE.md, README.md and the input/output/docs/testreport directory skeleton — under
  `project-blueprint/` and `project-blueprint-en/`. Source code, `docs/` content,
  `output/` deliverables, and `testreport/` raw data are out of scope.
  `constitution.md` and `project-config.md` §1 / §4-§10 / §12 / §13 are immutable.
  Both JP and EN mirrors MUST stay in lockstep — completion requires structural parity.
  Runs self-score → self-improve → self-review for **2 fixed rounds**; escalates to a human
  if the round-2 reviewer does not approve.
  Outputs a refinement report to `output/reports/harness-refine/` (requires Write permission to that path).
  Takes optional argument: /harness-refine <target-dir or instruction>
argument-hint: "<target-directory or refinement instruction (optional)>"
allowed-tools: Read, Glob, Grep, Bash(ls *, find *, wc *, diff *, git *), Edit, Write, WebFetch, WebSearch, Agent, mcp__plugin_context7_context7__resolve-library-id, mcp__plugin_context7_context7__query-docs
context: main
---

# Harness Refine — Self-score / improve / review against best practices (2 fixed rounds)

A meta-skill that refines the harness scaffolding under `project-blueprint/` and
`project-blueprint-en/` by running **self-score → self-improve → self-review** for
**2 rounds**, using **Claude Code official best practices** and the
**7 inviolable principles of `constitution.md`** as the dual rubric.

Source code, `docs/` content, `output/` deliverables, and `testreport/` raw data are
out of scope. **Only template scaffolding** is touched.

## Prerequisites

| Reference | Purpose | Editable? |
| --------- | ------- | --------- |
| `constitution.md` (repo root) | 7 inviolable principles (rubric supremum) | ❌ Immutable |
| `project-config.md` §1 / §4-§10 / §12 / §13 | Human decision area | ❌ Immutable |
| `project-config.md` §2 / §3 / §11 | AI-mutable sections | ⚠️ Structure only (do not change values) |
| `.claude/CLAUDE.md` | Cross-cutting rules (principle ⑥: ≤200 lines target) | ✅ |
| `.claude/skills/*/SKILL.md` | Skill skeletons (frontmatter / pipeline) | ✅ |
| `.claude/agents/*.md` | Single-shot specialist definitions | ✅ |
| `.claude/teams/TEAM_*.md` | Orchestration | ✅ |
| `.claude/hooks/*.sh` | 3-layer defense — Layer 1 | ❌ Out of scope for this skill (debate in a separate PR) |
| `.claude/rules/*.md` | Path / language rule extensions | ✅ (preserve `.example` convention) |
| Official docs | Latest best practice | WebFetch / Context7 MCP |

## Principles (edit boundary — MUST hold)

| Area | Editable? | Notes |
| ---- | --------- | ----- |
| `constitution.md` | ❌ | Changes require a separate PR + `.constitution.sha256` update |
| `project-config.md` §1 / §4-§10 / §12 / §13 | ❌ | Human decision area |
| `project-config.md` §2 / §3 / §11 | ⚠️ | Structural tidying only; values untouched |
| `.claude/CLAUDE.md` | ✅ | Stay within 200-line target (220-line hard ceiling) |
| `.claude/{skills,agents,teams,rules,output-styles}/` | ✅ | No name clashes / cyclic references |
| `.claude/hooks/*.sh` | ❌ | Body edits forbidden here (principle ⑤) |
| `docs/`, `output/`, `testreport/` content | ❌ | Out of scope (only `output/reports/harness-refine/` is written) |
| `input/requirements/` | ❌ | Human input |

If any of the immutable boundaries would be crossed, **halt immediately and ask the human**.
`scan-harness.sh` may also block via hooks.

## Usage

```text
/harness-refine <target-dir or instruction>
```

When the argument is omitted, the entire `project-blueprint/` and `project-blueprint-en/` tree is targeted. Representative triggers:

- "Refine the harness"
- "Restructure to follow best practices"
- "Run a self-refine pass"
- "Audit the .claude/ layout"
- "Re-align skill / agent / team placement"
- "Bring `project-blueprint/` and `project-blueprint-en/` back in sync"

## Overall workflow (2 fixed rounds — no auto round 3)

```text
Round 1                                 Round 2
  ┌─────────────┐                         ┌─────────────┐
  │ 1-A Score    │                         │ 2-A Score   │
  │   (rubric)   │                         │   (delta)   │
  └─────┬────────┘                         └─────┬───────┘
        ▼                                        ▼
  ┌─────────────┐                         ┌─────────────┐
  │ 1-B Improve  │── JP/EN mirror sync ──→ │ 2-B Improve │── JP/EN mirror sync ──→
  └─────┬────────┘                         └─────┬───────┘
        ▼                                        ▼
  ┌─────────────┐                         ┌─────────────┐
  │ 1-C Review   │ (code-reviewer agent)   │ 2-C Review  │ (code-reviewer agent)
  └─────┬────────┘                         └─────┬───────┘
        └────────► Round 2 input ───────────────┘
                                                 ▼
                                          Final report
```

- Round 1 handles **broad corrections** (naming drift, misplacement, missing frontmatter, mirror divergence)
- Round 2 handles **round-1 residuals + second-order effects** (broken `@import`, CLAUDE.md catalog drift, 404 links)
- Each round's review is delegated to the `pr-review-toolkit:code-reviewer` agent for **independent judgement**
- If round 2 does not get an approval, **escalate to a human** — no automatic round 3

## Round 1 — broad corrections

### 1-A. Self-score (10 items × 0/1/2 points = 20 max)

| # | Item | 0 pts | 1 pt | 2 pts |
| - | ---- | ----- | ---- | ----- |
| 1 | Adherence to constitution 7 principles | Violation present | Formally compliant | + Tested by `scan-harness.sh` |
| 2 | CLAUDE.md ≤200 lines (principle ⑥) | >220 lines | 200-220 lines | ≤200 lines + `@import` organized |
| 3 | Skill frontmatter convention | Missing name / description | All present | + allowed-tools / context / argument-hint complete |
| 4 | 3-layer separation (skill ⇄ agent ⇄ team, principle ④) | Cycles / mixing | Linear | + Selection guide in `agents/README.md` |
| 5 | 3-layer defense preserved (principle ⑤) | Hooks removed | Count preserved | + Responsibility header comment on each hook |
| 6 | JP/EN mirror sync (principle ②) | File count / structure diff | File count matches | + Section headings also match |
| 7 | Rules opt-in pattern | `.example` missing or directly loaded | `.example` present | + Naming convention (`language-*`, `path-*`, `rule-*`) held |
| 8 | 5 quality gates (principle ③) | Reduced | All 5 present | + Each skill `@import`s `@.claude/quality-gates.md` |
| 9 | Pipeline links explicit | No upstream/downstream note | Partial | All skills have a "prev → this → next" table |
| 10 | Official best-practice compliance (SKILL.md / settings layout) | Outdated form | Partial | Latest form |

**Targets**: round 1 ≥ **16/20**, round 2 ≥ **19/20**.

Always cite **file path + line number** for every score (no "feels low" justifications).
Resolve best-practice rulings via WebFetch (anthropic.com) / Context7 MCP — do not rely on training data alone.

### 1-B. Self-improve (apply fixes)

Address every item scoring 0 / 1, in this priority order:

1. **Constitution violations**: halt → human confirmation (never auto-fix; report bullet-by-bullet)
2. **CLAUDE.md overflow**: extract into `@.claude/rules/<topic>.md` → replace with `@import`
3. **Missing frontmatter / naming drift**: complete and unify skill / agent files
4. **3-layer separation violations**: re-orient calls to one direction (skill → agent OK, agent → team forbidden)
5. **Mirror divergence**: copy to the missing side, translate prose to match `README-en.md` tone
6. **`.example` convention breach**: revert real files to `.example` or rename to follow convention

**Mirror application rules**:

- Whenever JP is changed, **apply the EN change in the same turn** (do not stop with one side updated)
- Structure must be bit-identical; only prose is translated. Section numbering, table columns, code blocks stay identical
- Preserve EN-only formatting (e.g., serial commas) where intentional

### 1-C. Self-review (independent judgement)

Invoke `pr-review-toolkit:code-reviewer` once via `Agent`.
Context passed in:

- The full `git diff` of round-1 Edit / Write actions
- An explicit request to verify the constitution 7 principles
- JP/EN diff (`diff -r project-blueprint/.claude/skills/ project-blueprint-en/.claude/skills/`)

Roll review findings (MUST / SHOULD / CONSIDER) into the round 2 input.

## Round 2 — residuals and second-order effects

### 2-A. Self-score (delta-focused)

Re-score every item that came in at **1 or 0** in round 1. Add the following new score targets:

- Side-effects of round-1 edits (broken `@import`, broken links, mismatched CLAUDE.md skill catalog)
- Changes the mirror failed to pick up
- The code-reviewer's findings (every MUST must be reflected in the score)

### 2-B. Self-improve (closing pass)

- Only nudge remaining items up to 2 points; no new large-scale changes
- Verify every `@import` target exists:

  ```bash
  grep -rh '^@\.claude' project-blueprint/ project-blueprint-en/ | sort -u | \
    while read line; do
      path="${line#@}"
      test -e "project-blueprint/$path" || echo "MISSING(JP): $path"
      test -e "project-blueprint-en/$path" || echo "MISSING(EN): $path"
    done
  ```

- Rebuild the `CLAUDE.md` skill catalog table (cross-check `.claude/skills/*/SKILL.md` `name:` fields)
- Drive the file-count delta to 0:

  ```bash
  diff <(cd project-blueprint && find .claude -type f | sort) \
       <(cd project-blueprint-en && find .claude -type f | sort)
  ```

### 2-C. Self-review (final)

Invoke `pr-review-toolkit:code-reviewer` again. Decision matrix:

| Reviewer verdict | Next action |
| ---------------- | ----------- |
| **Approved** | Emit final report → end the skill |
| **Conditional approval** | Check if remaining MUSTs are fixable; if yes, fix; otherwise escalate |
| **Requires rework** | **Halt and escalate to human** — auto round 3 is forbidden |

## Output contract

### Final report (required)

Write to `output/reports/harness-refine/REFINE_<YYYY-MM-DD>_<HHMM>.md`:

```markdown
# Harness Refinement Report — <date>

## Summary
- Round 1 score: NN/20 → Round 2 score: MM/20 (target ≥19)
- Files refined: JP X / EN Y (delta MUST be 0)
- Constitution violations: detected N / fixed N (auto-fix count is 0 — every fix went through human)
- code-reviewer verdict: Approved / Conditional / Requires rework

## Round 1
### Score (10 items)
[Each item: points + evidence file:line]
### Improvements
[Per-file change summary + WHY]
### Review outcome
[code-reviewer agent summary]

## Round 2
[same shape]

## Outstanding items
- (Bulleted; only items requiring human judgement)

## Mirror parity verification
- File-count diff: matches / N files differ
- Section-heading diff: none / N (enumerated)
- Broken `@import`: 0 / N (enumerated)
```

### Live commentary

- Announce each round explicitly ("Now running round N scoring")
- Score output is **one line per item** (bulleted)
- For improvements, always report **what / why / where** (no silent edits)
- Mirror application is reported as **JP → EN in the same turn**

## Pipeline links

| Upstream | This skill | Downstream |
| -------- | ---------- | ---------- |
| (none — meta-skill) | `/harness-refine` | `/code-review` (code side) / `/refactoring` (code side) |

`/refactoring` restructures source code; this skill restructures harness scaffolding. Do not conflate.

## Prohibitions

- Editing `constitution.md` (fully immutable)
- Editing `project-config.md` §1 / §4-§10 / §12 / §13
- Editing `.claude/hooks/*.sh` bodies (principle ⑤)
- Treating one-sided updates as complete (principle ②)
- Using `--no-verify` / `--force` in git operations
- **Running 3+ rounds automatically** (round-2 non-approval → human)
- Touching source code / `docs/` content / `output/` (outside this skill's report) / `testreport/`
- Presenting scores without per-item evidence

## See also (loaded on demand)

@.claude/guardrails.md
@.claude/quality-gates.md
@.claude/rules/workflow-advanced.md
@.claude/pitfalls.md
