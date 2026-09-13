export const meta = {
  name: 'review-sweep',
  description: 'Reviews the diff in parallel from 4 angles, adversarially verifies each MUST finding with 3 votes, then writes a single report',
  whenToUse: 'Before opening a PR, before the implementation or verification gate, or when a large diff needs a multi-angle review free of self-grading bias',
  phases: [
    { title: 'Scope', detail: 'Pin down the diff and the files to review' },
    { title: 'Review', detail: 'Parallel review: spec & quality / security / performance / tests' },
    { title: 'Verify', detail: '3 skeptics try to refute each MUST finding' },
    { title: 'Report', detail: 'Write the surviving findings to output/reports/review/' },
  ],
}

// ────────────────────────────────────────────────────────────────────────────
// review-sweep — saved workflow automating TEAM_QA's review step (team layer)
//
// Usage:  /review-sweep                        … review the diff against origin/main
//         /review-sweep base=develop maxVerify=10
// args:   { base?: string, maxVerify?: number }
//
// Design:
//   - Independent agents without the implementer's context do the review (counters self-preferential bias)
//   - The 4 angles meet at a barrier for dedup; only MUST findings are adversarially verified
//   - A finding is confirmed only when at least 2 of 3 skeptics uphold it
//   - MUST findings beyond the verification cap are kept in the report as "unverified", never dropped
// Cost estimate: 1 + 4 + 3 × min(MUST count, maxVerify) + 1 agents
// ────────────────────────────────────────────────────────────────────────────

const BASE = (args && args.base) || 'origin/main'
const MAX_VERIFY = (args && Number(args.maxVerify)) || 6

const SCOPE_SCHEMA = {
  type: 'object',
  required: ['base', 'files', 'summary'],
  properties: {
    base: { type: 'string' },
    files: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
  },
}

const FINDINGS_SCHEMA = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['severity', 'file', 'line', 'title', 'evidence', 'fix'],
        properties: {
          severity: { type: 'string', enum: ['MUST', 'SHOULD', 'CONSIDER'] },
          file: { type: 'string' },
          line: { type: 'integer' },
          title: { type: 'string' },
          evidence: { type: 'string' },
          fix: { type: 'string' },
        },
      },
    },
  },
}

const VERDICT_SCHEMA = {
  type: 'object',
  required: ['refuted', 'reason'],
  properties: {
    refuted: { type: 'boolean' },
    reason: { type: 'string' },
  },
}

const REPORT_SCHEMA = {
  type: 'object',
  required: ['path', 'verdict'],
  properties: {
    path: { type: 'string' },
    verdict: { type: 'string', enum: ['Approved', 'Conditionally Approved (After MUST Fixes)', 'Needs Revision'] },
  },
}

const READ_ONLY = 'Do not modify any file. Cite evidence as file path and line number; never report on speculation.'

phase('Scope')
const scope = await agent(
  `Using git diff ${BASE}...HEAD and git status, return the list of changed files to review (excluding deleted files) and a summary of the change. ${READ_ONLY}`,
  { label: 'scope', phase: 'Scope', schema: SCOPE_SCHEMA, effort: 'low' },
)

if (!scope || scope.files.length === 0) {
  log(`No diff against ${BASE}; ending the review`)
  return { report: null, confirmed: 0, refuted: 0, unverified: 0 }
}
log(`${scope.files.length} files in scope: ${scope.summary}`)

const FILES = scope.files.join('\n')
const DIMENSIONS = [
  {
    key: 'spec-quality',
    prompt: `Following review perspectives 1-3, 8, and 9 and the severity definitions in .claude/skills/code-review/SKILL.md, review the changes since ${BASE} in these files for spec compliance, code quality, architecture, backward compatibility, and doc sync.\n${FILES}\n${READ_ONLY}`,
  },
  {
    key: 'security',
    agentType: 'security-reviewer',
    prompt: `Review the changes since ${BASE} in these files against OWASP Top 10 / CWE. Return CRITICAL and HIGH as severity=MUST, MEDIUM as SHOULD, LOW and INFO as CONSIDER. Never copy secret values.\n${FILES}\n${READ_ONLY}`,
  },
  {
    key: 'performance',
    agentType: 'performance-analyst',
    prompt: `Review the changes since ${BASE} in these files for performance regressions that are evident from the diff without measurement (N+1 queries, unbounded loops, needless re-renders, synchronous I/O). Do not run measurement commands. Report concerns that need measurement as CONSIDER.\n${FILES}\n${READ_ONLY}`,
  },
  {
    key: 'tests',
    prompt: `Following review perspective 7 in .claude/skills/code-review/SKILL.md, check whether the tests for these changes verify behavior and whether boundary and error cases are missing.\n${FILES}\n${READ_ONLY}`,
  },
]

phase('Review')
const reviews = await parallel(
  DIMENSIONS.map((d) => () =>
    agent(d.prompt, { label: `review:${d.key}`, phase: 'Review', schema: FINDINGS_SCHEMA, agentType: d.agentType }),
  ),
)
DIMENSIONS.forEach((d, i) => {
  if (!reviews[i]) log(`Review angle ${d.key} failed (it will be listed in the report)`)
})

// Dedup across angles by file:line and title (needs every angle's result, hence the barrier)
const seen = new Set()
const findings = []
reviews.forEach((r, i) => {
  if (!r) return
  for (const f of r.findings) {
    const key = `${f.file}:${f.line}:${f.title.toLowerCase().slice(0, 40)}`
    if (seen.has(key)) continue
    seen.add(key)
    findings.push({ ...f, dimension: DIMENSIONS[i].key })
  }
})

const musts = findings.filter((f) => f.severity === 'MUST')
const toVerify = musts.slice(0, MAX_VERIFY)
const unverified = musts.slice(MAX_VERIFY)
if (unverified.length > 0) {
  log(`${unverified.length} of ${musts.length} MUST findings exceed the verification cap (maxVerify=${MAX_VERIFY}) and stay unverified`)
}

phase('Verify')
const verified = await parallel(
  toVerify.map((f, i) => () =>
    parallel(
      [0, 1, 2].map((v) => () =>
        agent(
          `Try to refute the following finding. Read the code; if the finding is wrong, overstated, or already handled, set refuted=true. If you are not confident, also set refuted=true.\nFinding: [${f.dimension}] ${f.file}:${f.line} ${f.title}\nEvidence: ${f.evidence}\n${READ_ONLY}`,
          { label: `verify:${i + 1}-${v + 1}`, phase: 'Verify', schema: VERDICT_SCHEMA },
        ),
      ),
    ).then((votes) => {
      const valid = votes.filter(Boolean)
      const upheld = valid.filter((x) => !x.refuted).length
      return { ...f, upheld, votes: valid.length, survives: upheld >= 2 }
    }),
  ),
)

const confirmed = verified.filter((f) => f && f.survives)
const refuted = verified.filter((f) => f && !f.survives)
log(`MUST verification: confirmed ${confirmed.length} / refuted ${refuted.length} / unverified ${unverified.length}`)

const others = findings.filter((f) => f.severity !== 'MUST')
const failedDimensions = DIMENSIONS.filter((d, i) => !reviews[i]).map((d) => d.key)

phase('Report')
const report = await agent(
  `Write a review report from the JSON below. Run \`date +%Y%m%d-%H%M\` and name the file output/reports/review/SWEEP_<timestamp>.md; write nowhere outside output/reports/review/.
Follow the "Report Format" in .claude/skills/code-review/SKILL.md and always include:
- Overview: the diff base (${BASE}), file count, failed angles
- Findings: MUST (confirmed only) → SHOULD → CONSIDER. Each with angle, file:line, reason, and fix
- Separate sections listing refuted MUST findings and unverified MUST findings (mark unverified ones for human review)
- Overall verdict: "Approved" when there are 0 confirmed MUST findings, "Conditionally Approved (After MUST Fixes)" when there is at least 1, "Needs Revision" when the design must be revisited
Return the created file path and the overall verdict.

${JSON.stringify({ base: BASE, files: scope.files, failedDimensions, confirmed, refuted, unverified, others })}`,
  { label: 'report', phase: 'Report', schema: REPORT_SCHEMA },
)

return {
  report: report ? report.path : null,
  verdict: report ? report.verdict : null,
  confirmed: confirmed.length,
  refuted: refuted.length,
  unverified: unverified.length,
  others: others.length,
}
