---
name: harness-refine
description: >
  This skill should be used when the user asks to "refine the harness", "self-improve the blueprint",
  "restructure .claude/ to match best practices", "audit harness configuration",
  or mentions "harness refine", "best-practice alignment", "self-refine",
  "harness self-audit", "rework skill/agent/team layout".
  Self-scores and refines the `.claude/` harness scaffolding (skills / agents / teams / rules)
  under `project-blueprint/` and `project-blueprint-en/` against refreshed official best practices,
  in lockstep across both language mirrors. Source code and `docs/`/`output/` content are out of scope.
  Runs a non-mutating Round 0 best-practice refresh, then self-score → self-improve → self-review
  for 2 fixed rounds, escalating to a human if not approved.
  Takes optional argument: /harness-refine <target-dir or instruction>
argument-hint: "<target-directory or refinement instruction (optional)>"
allowed-tools: Read, Glob, Grep, Bash(ls *, find *, wc *, diff *, grep *, git *), Edit, Write, WebFetch, WebSearch, Agent, mcp__context7__resolve-library-id, mcp__context7__query-docs, mcp__plugin_context7_context7__resolve-library-id, mcp__plugin_context7_context7__query-docs
effort: high
---

# Harness Refine — Self-strengthening best-practice refinement (Round 0 refresh + 2 fixed rounds)

A meta-skill that refines the harness scaffolding under `project-blueprint/` and
`project-blueprint-en/` by running **self-score → self-improve → self-review** for
**2 rounds**, using **Claude Code official best practices** (re-fetched each run in Round 0)
and the **7 inviolable principles of `constitution.md`** as the dual rubric.

Source code, `docs/` content, `output/` deliverables, and `testreport/` raw data are
out of scope. **Only template scaffolding** is touched.

## Self-strengthening mechanism (the core of this skill)

This skill does not freeze its rubric; it gets stronger autonomously on every run, via three mechanisms:

1. **Round 0 refresh** (non-mutating): re-fetch the official primary sources (see "Best-practice
   reference sources" below) via WebFetch / Context7, and fold the delta against the latest guidance
   into the **provisional scoring criteria for this run**. Never judge from training data alone.
2. **Adaptive loop**: read prior reports (`output/reports/harness-refine/`), extract **unresolved
   findings** and **issues that recurred 2+ times**, and promote them to top-priority fixes
   (turning failure into learning rather than a loop).
3. **Rubric self-evolution**: if Round 0 discovers a new official best practice, **propose a new
   scoring item**. Any change touching `constitution.md` is never auto-adopted — it requires human approval.

## Prerequisites

| Reference | Purpose | Editable? |
| --------- | ------- | --------- |
| `constitution.md` (repo root) | 7 inviolable principles (rubric supremum) | ❌ Immutable |
| `project-config.md` §1 / §4-§10 / §12 / §13 | Human decision area | ❌ Immutable |
| `project-config.md` §2 / §3 / §11 | AI-mutable sections | ⚠️ Structure only (do not change values) |
| `project-config.md` §13 | Opus/Sonnet/Haiku tier strategy (referenced by item 11) | ❌ Immutable (reference only) |
| `.claude/CLAUDE.md` | Cross-cutting rules (principle ⑥: ≤200 lines target) | ✅ |
| `.claude/skills/*/SKILL.md` | Skill skeletons (frontmatter / pipeline / description) | ✅ |
| `.claude/agents/*.md` | Single-shot specialist definitions (least privilege / single responsibility) | ✅ |
| `.claude/teams/TEAM_*.md` | Orchestration | ✅ |
| `.claude/hooks/*.sh` | 3-layer defense — Layer 1 | ❌ Out of scope for this skill (debate in a separate PR) |
| `.claude/rules/*.md` | Path / language rule extensions | ✅ (preserve `.example` convention) |
| Prior reports (`output/reports/harness-refine/`) | Learning input for the adaptive loop | Read-only |
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

## Overall workflow (Round 0 + 2 fixed rounds — no auto round 3)

```text
Round 0 (non-mutating / self-strengthening)   Round 1                       Round 2
  ┌─────────────────┐                          ┌─────────────┐               ┌─────────────┐
  │ Re-fetch BP      │                          │ 1-A Score    │               │ 2-A Score   │
  │ Learn from past  │ ─── rubric delta ──────→ │   (rubric)   │               │   (delta)   │
  │ Rubric delta     │     injected             └─────┬────────┘               └─────┬───────┘
  └─────────────────┘                                 ▼                              ▼
                                                ┌─────────────┐               ┌─────────────┐
                                                │ 1-B Improve  │─JP/EN sync──→ │ 2-B Improve │─sync→
                                                └─────┬────────┘               └─────┬───────┘
                                                      ▼                              ▼
                                                ┌─────────────┐               ┌─────────────┐
                                                │ 1-C Review   │(code-reviewer)│ 2-C Review  │(code-reviewer)
                                                └─────┬────────┘               └─────┬───────┘
                                                      └──────► Round 2 input ──────┘
                                                                                     ▼
                                                                              Final report
```

- **Round 0** does **best-practice re-fetch + learning from past reports** (edits no files at all)
- Round 1 handles **broad corrections** (naming drift, misplacement, missing frontmatter, mirror divergence)
- Round 2 handles **round-1 residuals + second-order effects** (broken `@import`, CLAUDE.md catalog drift, 404 links)
- Each round's review is delegated to the `pr-review-toolkit:code-reviewer` agent for **independent judgement**
- If round 2 does not get an approval, **escalate to a human** — no automatic round 3

## Round 0 — best-practice refresh (self-strengthening preflight / non-mutating)

Edits **no files**. Research and delta generation only. Steps:

1. **Fetch the latest official guidance**: WebFetch the URLs in "Best-practice reference sources"
   below; use Context7 for library-style docs. On fetch failure, continue in **degraded mode** using
   training data + prior reports, and state this explicitly in conversation and the report
   (never silently regress to training data).
2. **Learn from past reports**: read `output/reports/harness-refine/REFINE_*.md` (the latest 2-3, if any)
   and extract (a) **unresolved findings** (b) **issues that recurred 2+ times**.
3. **Generate the live rubric delta**: compare the fetched guidance against the 15-item rubric below, and
   - if an item's criteria are stale, update them as the **provisional criteria for this run**
   - if there is a strong new official recommendation, record it as a **candidate new scoring item**
   - promote recurring findings to **top-priority fixes**
4. **Human approval gate**: proposing a new scoring item, or any change that ripples into
   `constitution.md`, must be **presented to the human for approval before adoption** (no auto-edits).

Round 0 output (recorded in conversation + final report): "fetched sources and success/degraded status",
"list of recurring findings", "rubric delta applied this run".

## Round 1 — broad corrections

### 1-A. Self-score (15 items × 0/1/2 points = 30 max)

Score as an **acceptance checklist** (spec-kit style): judge YES/NO whether each item's 2-point
condition holds, with evidence attached.

**Group A — constitution / structural invariants**

| # | Item | 0 pts | 1 pt | 2 pts |
| - | ---- | ----- | ---- | ----- |
| 1 | Adherence to constitution 7 principles | Violation present | Formally compliant | + Tested by `scan-harness.sh` |
| 2 | CLAUDE.md ≤200 lines (principle ⑥) | >220 lines | 200-220 lines | ≤200 lines + true reduction via path-scoped `rules/` (understand `@import` does not cut context) |
| 3 | Skill frontmatter convention | Missing name / description | All present | + allowed-tools (least privilege) / context / argument-hint complete |
| 4 | 3-layer separation (skill ⇄ agent ⇄ team, principle ④) | Cycles / mixing | Linear | + Selection guide in `agents/README.md` |
| 5 | 3-layer defense preserved (principle ⑤) | Hooks removed | Count preserved | + Responsibility header comment on each hook |
| 6 | JP/EN mirror sync (principle ②) | File count / structure diff | File count matches | + Headings & line counts match (mechanical diff = 0) |
| 7 | Rules opt-in pattern | `.example` missing or directly loaded | `.example` present | + Naming convention (`language-*`, `path-*`, `rule-*`) held |
| 8 | 5 quality gates (principle ③) | Reduced | All 5 present | + Each skill `@import`s `@.claude/quality-gates.md` |

**Group B — Anthropic official best practices + GitHub TOP5 essence**

| # | Item | 0 pts | 1 pt | 2 pts |
| - | ---- | ----- | ---- | ----- |
| 9 | Pipeline links & discoverability (superpowers style) | No upstream/downstream note / dead skills | Partial | "prev → this → next" table on all skills + no skill orphaned from every entry path |
| 10 | Official best-practice compliance | Outdated form | Partial | Conforms to the latest form fetched in Round 0 |
| 11 | Skill description quality (third person / explicit triggers) | First/second person or vague | Third person | + ≤1024 chars / concrete triggers / no duplicate triggers |
| 12 | Progressive disclosure | SKILL.md bloated (>500 lines) / verbose background | ≤500 lines | + Mutually-exclusive detail split into 3rd tier (reference files) |
| 13 | Agent least privilege & single responsibility | Read-only agent has Write/Edit / multi-responsibility | tools allowlist present | + Read-only agents lack Write / 1 agent = 1 task / "returns summary only" contract stated |
| 14 | Model tier placement (§13 / BMAD style) | No tier note | Tier noted | + Sound placement: planning = high tier / mechanical work = low tier |
| 15 | Eval-first / acceptance checklist (spec-kit style) | No verification angle | Output contract present | + Representative scenarios + PASS conditions stated in SKILL.md |

**Targets** (expressed as % so future item additions don't break them): round 1 ≥ **80% (≥24/30)**, round 2 ≥ **95% (≥28/30)**.

Always cite **file path + line number** for every score (no "feels low" justifications).
Judge items 10 / 11 / 12 against the latest official guidance fetched in Round 0.

### 1-B. Self-improve (apply fixes)

Address every item scoring 0 / 1, in this priority order (recurring findings promoted in Round 0 come first):

1. **Constitution violations**: halt → human confirmation (never auto-fix; report bullet-by-bullet)
2. **CLAUDE.md overflow**: extract a topic into `@.claude/rules/<topic>.md` → path-scope it to truly cut context
3. **Missing frontmatter / naming drift / description quality**: unify to third person, explicit triggers, least-privilege allowlist
4. **3-layer separation violations**: re-orient calls to one direction (skill → agent OK, agent → team forbidden)
5. **Mirror divergence**: copy to the missing side, translate prose to match `README-en.md` tone
6. **`.example` convention breach**: revert real files to `.example` or rename to follow convention

**Mirror application rules**:

- Whenever JP is changed, **apply the EN change in the same turn** (do not stop with one side updated)
- Structure must be bit-identical; only prose is translated. Section numbering, table columns, code blocks stay identical
- Preserve EN-only formatting (e.g., serial commas) where intentional

### 1-C. Self-review (independent judgement)

Invoke `pr-review-toolkit:code-reviewer` once via `Agent`. Context passed in:

- The full `git diff` of round-1 Edit / Write actions
- An explicit request to verify the constitution 7 principles
- JP/EN diff (`diff -r project-blueprint/.claude/skills/ project-blueprint-en/.claude/skills/`)

Roll review findings (MUST / SHOULD / CONSIDER) into the round 2 input.

## Round 2 — residuals and second-order effects (adaptive)

### 2-A. Self-score (delta-focused + resolution rate)

Re-score every item that came in at **1 or 0** in round 1. Add the following new score targets:

- Side-effects of round-1 edits (broken `@import`, broken links, mismatched CLAUDE.md skill catalog)
- Changes the mirror failed to pick up
- The code-reviewer's findings (every MUST must be reflected in the score)
- **Resolution-rate tracking**: were the recurring findings extracted in Round 0 resolved this run?
  (a 3rd-or-more recurrence is a human-escalation candidate)

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

## Output Contract

### Final report (required)

Write to `output/reports/harness-refine/REFINE_<YYYY-MM-DD>_<HHMM>.md`:

```markdown
# Harness Refinement Report — <date>

## Summary
- Round 1 score: NN/30 (N%) → Round 2 score: MM/30 (M%) (target ≥95%)
- Files refined: JP X / EN Y (delta MUST be 0)
- Constitution violations: detected N / fixed N (auto-fix count is 0 — every fix went through human)
- code-reviewer verdict: Approved / Conditional / Requires rework

## Round 0 — best-practice refresh
- Fetched sources: [per URL: success / degraded]
- Recurring findings (from prior reports): [bulleted / resolution rate]
- Rubric delta applied this run: [updated criteria / new-item proposals (pending human approval)]

## Round 1
### Score (15 items)
[Each item: points + evidence file:line]
### Improvements
[Per-file change summary + WHY]
### Review outcome
[code-reviewer agent summary]

## Round 2
[same shape + resolution rate]

## Outstanding items
- (Bulleted; only items requiring human judgement)

## Mirror parity verification
- File-count diff: matches / N files differ
- Section-heading diff: none / N (enumerated)
- Broken `@import`: 0 / N (enumerated)
```

### Live commentary

- At Round 0 start, state "the official sources to fetch and the prior-report learning result"
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
- Editing files during Round 0 (Round 0 is non-mutating / research only)
- **Auto-adopting** new scoring items or constitution-rippling changes without human approval
- Touching source code / `docs/` content / `output/` (outside this skill's report) / `testreport/`
- Presenting scores without per-item evidence / silently regressing to training data on a Round 0 fetch failure

## Best-practice reference sources (re-fetched in Round 0 — official primary sources preferred)

| Source | Purpose | Rubric items |
| ------ | ------- | ------------ |
| platform.claude.com/docs `agent-skills/best-practices` | SKILL.md / frontmatter / progressive disclosure / eval-first | 3, 11, 12, 15 |
| docs.claude.com `claude-code/sub-agents` | subagent least privilege / single responsibility / summary return | 13 |
| docs.claude.com `claude-code/memory` | CLAUDE.md line count / `@import` doesn't cut context / path-scoped rules | 2 |
| anthropic.com/engineering `writing-tools-for-agents` | tool-definition clarity / token efficiency | 10, 11 |
| anthropic.com/engineering `effective-context-engineering-for-ai-agents` | context curation / sub-agent isolation | 12, 13 |
| anthropic.com/engineering `effective-harnesses-for-long-running-agents` | startup orientation / verification loop | 9, 15 |
| GitHub: spec-kit / BMAD-METHOD / SuperClaude / agent-os / superpowers | acceptance checklist / model tier / standards consolidation / discoverability | 9, 14, 15 |

> Flag any source that fails to fetch as degraded; score the corresponding rubric items provisionally against the prior criteria.

## See also (loaded on demand)

@.claude/guardrails.md
@.claude/quality-gates.md
@.claude/rules/workflow-advanced.md
@.claude/pitfalls.md
