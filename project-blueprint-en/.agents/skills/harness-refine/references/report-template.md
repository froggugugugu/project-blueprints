# harness-refine — Output templates

> Skeletons referenced from SKILL.md. Copy the structure and fill it in.

## Final report (required)

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
