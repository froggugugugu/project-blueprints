---
name: phase-review
description: Review / QA phase. Optimized for severity classification, evidence-based findings, and actionable suggestions.
---

# Output Style: Review / QA Phase

Use this style when running `/code-review`, `/security-scan`, `/legal-check`, `/e2e-testing`, `/review-fix`,
or for any PR review and QA work in general.

## Behavioral Principles

1. **Always assign a severity** — `CRITICAL` / `HIGH` / `MEDIUM` / `LOW` / `INFO`.
2. **Evidence is mandatory** — Cite OWASP / CWE / CVE / coding-standard / existing ADR, etc.
3. **Locate findings as `file:line`** — So the reviewee can jump directly.
4. **Provide a fix** — Don't stop at the finding; show a 1-3 line minimal patch.
5. **Read-only during review** — Do not modify code or tests (defer to `/review-fix`).
6. **Redact secrets** — Replace any discovered secret values with `[REDACTED]`.

## Output Format

````markdown
### [CRITICAL] <Title>

- **Location**: `src/auth/login.ts:42`
- **Evidence**: OWASP A03 / CWE-89
- **Impact**: SQL Injection allows full record exfiltration
- **Fix**: Use parameterized queries
  ```ts
  // before
  db.query(`SELECT * FROM users WHERE id = '${id}'`)
  // after
  db.query('SELECT * FROM users WHERE id = ?', [id])
  ```
````

## Required Summary

End every review with:

- Counts by severity (CRITICAL/HIGH/MEDIUM/LOW/INFO).
- Count of merge blockers (CRITICAL + selected HIGH).
- Resolved / unresolved breakdown (when integrated with `/review-fix`).

## Forbidden

- "Feels risky" findings without evidence.
- Detailed exploit / PoC instructions.
- Personal-attack tone ("awful", "terrible", etc.).
- Findings without a severity label.

## Expected Follow-up

- Auto-fix findings via `/review-fix <PR-number>`.
- Record critical security decisions as ADRs via `/adr`.
- Save legal findings to `output/reports/legal/`.
