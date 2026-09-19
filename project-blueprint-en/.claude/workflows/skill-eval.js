export const meta = {
  name: 'skill-eval',
  description: "Runs a skill's evals/evals.json with and without the skill, then has an independent grader judge the assertions and compares pass rates",
  whenToUse: 'After changing a skill description or body, to check with numbers that triggering and output quality did not regress',
  phases: [
    { title: 'Cases', detail: 'Read evals/evals.json and settle the cases to run' },
    { title: 'Run', detail: 'Run each case in two arms: with and without the skill' },
    { title: 'Grade', detail: 'An independent grader judges each assertion PASS / FAIL' },
    { title: 'Report', detail: 'Write pass rates and the delta to testreport/evals/' },
  ],
}

// ────────────────────────────────────────────────────────────────────────────
// skill-eval — saved workflow that runs the eval-first loop (team layer)
//
// Usage:  /skill-eval skill=prd
//         /skill-eval skill=prd iteration=2 cases=1
// args:   { skill: string, iteration?: number, cases?: number[] | string }
//
// Design:
//   - The same prompt runs with and without the skill; the delta measures the skill's contribution
//     (the official with / without method)
//   - Grading is done by an agent that did not produce the output (counters self-grading bias)
//   - Artifacts are written under testreport/evals/<skill>/iteration-<N>/ (gitignored)
//   - An assertion without solid evidence is graded FAIL
// Cost estimate: 1 + cases × 3 + 1 agents. Narrow with cases= when the suite is large
// ────────────────────────────────────────────────────────────────────────────

const SKILL = args && (args.skill || args.name)
const ITER = (args && Number(args.iteration)) || 1
const ONLY = args && args.cases
  ? (Array.isArray(args.cases) ? args.cases : String(args.cases).split(',')).map((x) => Number(x))
  : null

const CASES_SCHEMA = {
  type: 'object',
  required: ['skill_name', 'cases'],
  properties: {
    skill_name: { type: 'string' },
    cases: {
      type: 'array',
      items: {
        type: 'object',
        required: ['id', 'prompt', 'assertions'],
        properties: {
          id: { type: 'integer' },
          prompt: { type: 'string' },
          expected_output: { type: 'string' },
          assertions: { type: 'array', items: { type: 'string' } },
        },
      },
    },
  },
}

const ARM_SCHEMA = {
  type: 'object',
  required: ['files', 'summary'],
  properties: {
    files: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
    used_skill: { type: 'boolean' },
  },
}

const GRADE_SCHEMA = {
  type: 'object',
  required: ['results'],
  properties: {
    results: {
      type: 'array',
      items: {
        type: 'object',
        required: ['assertion', 'with_pass', 'without_pass', 'evidence'],
        properties: {
          assertion: { type: 'string' },
          with_pass: { type: 'boolean' },
          without_pass: { type: 'boolean' },
          evidence: { type: 'string' },
        },
      },
    },
  },
}

const REPORT_SCHEMA = {
  type: 'object',
  required: ['path', 'verdict'],
  properties: {
    path: { type: 'string' },
    verdict: { type: 'string', enum: ['skill helps', 'little difference', 'skill hurts'] },
  },
}

if (!SKILL) {
  log('A skill name is required. Example: /skill-eval skill=prd')
  return { error: 'no skill given' }
}
const WS = `testreport/evals/${SKILL}/iteration-${ITER}`

phase('Cases')
const suite = await agent(
  `Read .claude/skills/${SKILL}/evals/evals.json and return skill_name and cases (id / prompt / expected_output / assertions). If the file does not exist, return an empty cases array. Do not modify files.`,
  { label: `cases:${SKILL}`, phase: 'Cases', schema: CASES_SCHEMA, effort: 'low' },
)
if (!suite || suite.cases.length === 0) {
  log(`.claude/skills/${SKILL}/evals/evals.json is missing or has no cases`)
  return { skill: SKILL, cases: 0 }
}
const cases = ONLY ? suite.cases.filter((c) => ONLY.includes(c.id)) : suite.cases
log(`Running ${cases.length} cases (3 agents per case, output under ${WS}/)`)

const WRITE_RULE = (arm) =>
  `Write artifacts under ${WS}/${arm}/, reproducing the path they would normally take (for example output/prd/PRD_auth.md becomes ${WS}/${arm}/output/prd/PRD_auth.md). ` +
  `You may read files elsewhere but must not modify them. Finish by returning the list of files you created and the key points of your answer.`

phase('Run')
const graded = await pipeline(
  cases,
  (c) =>
    parallel([
      () =>
        agent(
          `Act as a session in this project and answer the following request. You may use any skill you judge relevant.\nRequest: ${c.prompt}\n\n${WRITE_RULE('with')}\nSet used_skill to whether you used a skill.`,
          { label: `with:${c.id}`, phase: 'Run', schema: ARM_SCHEMA },
        ),
      () =>
        agent(
          `Answer the following request without using any skill (never call the Skill tool). Rely on your default knowledge.\nRequest: ${c.prompt}\n\n${WRITE_RULE('without')}\nSet used_skill to false.`,
          { label: `without:${c.id}`, phase: 'Run', schema: ARM_SCHEMA },
        ),
    ]),
  (arms, c) => {
    const [w, wo] = arms
    if (!w && !wo) return null
    return agent(
      `Compare the two arms and judge each assertion one by one. ` +
        `Treat ${WS}/with/ as the project root of the with arm and ${WS}/without/ as the project root of the without arm, and read the actual files to check. ` +
        `Grade an assertion FAIL when you cannot find solid evidence. Do not modify files.\n` +
        `Request: ${c.prompt}\nExpected: ${c.expected_output || '(not stated)'}\n` +
        `Assertions:\n${c.assertions.map((a, i) => `${i + 1}. ${a}`).join('\n')}\n` +
        `With-arm report: ${w ? JSON.stringify(w) : '(run failed)'}\n` +
        `Without-arm report: ${wo ? JSON.stringify(wo) : '(run failed)'}`,
      { label: `grade:${c.id}`, phase: 'Grade', schema: GRADE_SCHEMA },
    ).then((g) => (g ? { id: c.id, prompt: c.prompt, used_skill: w ? w.used_skill : null, results: g.results } : null))
  },
)

const rows = graded.filter(Boolean)
const flat = rows.flatMap((r) => r.results)
const pct = (n) => (flat.length ? Math.round((n / flat.length) * 1000) / 10 : 0)
const withRate = pct(flat.filter((r) => r.with_pass).length)
const withoutRate = pct(flat.filter((r) => r.without_pass).length)
const notTriggered = rows.filter((r) => r.used_skill === false).map((r) => r.id)
log(`${flat.length} assertions: with ${withRate}% / without ${withoutRate}% (delta ${Math.round((withRate - withoutRate) * 10) / 10} points)`)
if (notTriggered.length > 0) {
  log(`Cases where the skill did not trigger in the with arm: ${notTriggered.join(', ')} — revisit the trigger words in the description`)
}
if (rows.length < cases.length) {
  log(`${cases.length - rows.length} cases could not be graded (the run or the grading failed)`)
}

phase('Report')
const report = await agent(
  `Write an eval report from the JSON below. Save the JSON as is to ${WS}/benchmark.json and write a human-readable summary to ${WS}/SUMMARY.md. Write nowhere outside ${WS}/.
SUMMARY.md must include:
- the skill, iteration, case count, and assertion count
- the with / without pass rates and the delta in points
- per-case assertion verdicts (PASS / FAIL with evidence)
- assertions that failed even with the skill (input for improving the skill)
- assertions that passed in both arms (the skill adds nothing there; candidates to replace in the next iteration)
- cases where the skill did not trigger, if any (the description needs work)
Return the created file path and a verdict: "skill helps" when the delta is at least 10 points, "little difference" between -5 and 10, "skill hurts" below -5.

${JSON.stringify({ skill: SKILL, iteration: ITER, assertions: flat.length, with_pass_rate: withRate, without_pass_rate: withoutRate, not_triggered: notTriggered, cases: rows })}`,
  { label: 'report', phase: 'Report', schema: REPORT_SCHEMA },
)

return {
  skill: SKILL,
  iteration: ITER,
  cases: rows.length,
  assertions: flat.length,
  with_pass_rate: withRate,
  without_pass_rate: withoutRate,
  verdict: report ? report.verdict : null,
  report: report ? report.path : null,
}
