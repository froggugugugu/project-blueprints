---
name: security-scan
description: >
  Runs security scanning tools and generates structured vulnerability reports.
  Triggers: security scan, vulnerability, OWASP, ZAP, npm audit, DAST, SAST, secret detection, dependency check, CVE.
  Source-code read-only — never modifies source code or test files.
  Outputs scan report to output/reports/security/ and raw data to testreport/security/ (requires Write permission to both).
  Takes optional argument: /security-scan <target-scope or instruction>
argument-hint: "<target-scope or instruction>"
allowed-tools: Read, Glob, Grep, Bash(git *), Write(output/**), Write(testreport/**), WebSearch, WebFetch, mcp__context7__resolve-library-id, mcp__context7__query-docs
context: fork
---

# Security Scan

A skill that runs security scanning tools and outputs structured vulnerability reports.
Integrates OWASP ZAP (DAST), dependency package vulnerability scanning, static analysis (SAST), and secret detection.
References `project-config.md` section 10 (Security Policy) for project-specific policy compliance.

**Disclaimer**: Scans by this skill are reference information based on automated tools and are not a substitute for penetration testing by security professionals. Always have critical systems reviewed by specialists.

## Prerequisites

No dependency on `docs/` files. References `project-config.md` §10 (Security Policy). When not filled in, uses OWASP Top 10 as the default baseline.

## Core Principles

- **Never modify source code** (read-only)
- Scan results must be reproducible (document tool, version, and settings)
- State severity for detected vulnerabilities (CRITICAL / HIGH / MEDIUM / LOW / INFO)
- Explicitly mark detections that may be false positives
- Clearly prioritize remediation actions

## Usage

```text
/security-scan <target-scope or scan instruction>
```

Arguments are optional. When omitted, scan the entire project.
When a file path or category is specified, limit the scan to that scope.

### Examples

```text
/security-scan Full project security scan
/security-scan src/features/assignment/
/security-scan Dependency packages only
```

### Output Destination

- Default: Present report in conversation
- File output: `output/reports/security/SECURITY_<datetime>.md` (when `output/` directory exists)
- Tool output: `testreport/security/`

### Integration with Other Skills

| Previous Step | This Skill | Next Step |
| ------------- | ---------- | --------- |
| `/implementing-features` | `/security-scan` | (Final step) |

## Scan Categories

Performs 5 categories (SCA / SAST / DAST / secret detection / security header analysis).
Execution commands, checklists, and judgment criteria for each are in `references/scan-categories.md`.

1. **Dependency Package Vulnerability Scan (SCA)** — Detects dependency packages with known vulnerabilities (CVEs)
2. **Static Application Security Testing (SAST)** — Statically detects source code issues based on OWASP Top 10
3. **Dynamic Application Security Testing (DAST)** — Scans the running application with OWASP ZAP
4. **Secret Detection** — Detects sensitive information in source code and Git history via gitleaks/trufflehog
5. **Security Header & Configuration Analysis** — Verifies required HTTP headers such as CSP

## Scan Workflow

1. **Scope Confirmation** — Confirm scan target (entire / specific category / specific file)
2. **Environment Check** — Verify installation status of required tools
3. **Tool Execution** — Run scan tools by category
4. **Results Analysis** — Analyze scan results and identify false positives
5. **🚏 Report Gate** — Output structured report

### Tool Availability Handling

When scan tools are not installed:

1. Present installation instructions (wait for user's decision)
2. Perform simplified scanning within the achievable scope without tools (Grep-based search, `npm audit`)
3. Document the limitations of the simplified scan

## Output Contract

### Section Definitions

| Section | Required | Constraints |
| ------- | -------- | ----------- |
| Disclaimer | ✅ | Fixed text. Do not modify |
| Scan Overview | ✅ | Must include target scope, tools used, scan date/time |
| Executive Summary | ✅ | Severity-based count of findings. Overview understandable by non-technical readers |
| Findings | ✅ | In CRITICAL → HIGH → MEDIUM → LOW → INFO order. Keep headings even when 0 items |
| Dependency Package Summary | Conditional | When SCA was performed |
| DAST Results Summary | Conditional | When DAST was performed |
| Recommended Actions | ✅ | Numbered in priority order. Include fix difficulty (Low/Medium/High) |
| Next Scan Recommendations | ✅ | Suggestions for additional tools and scan scope expansion |

### Severity Definitions

| Level | Criteria | Response Timeline | CVSS Equivalent |
| ----- | -------- | ----------------- | --------------- |
| **CRITICAL** | Immediately exploitable vulnerability. Auth bypass, RCE, public sensitive data exposure | Immediate response | 9.0–10.0 |
| **HIGH** | Requires some conditions to exploit, but can have severe impact | Within 1 week | 7.0–8.9 |
| **MEDIUM** | Exploitable under limited conditions, or moderate impact | Before next release | 4.0–6.9 |
| **LOW** | Difficult to exploit, or minor impact | Planned response | 0.1–3.9 |
| **INFO** | Deviation from security best practices. Not a direct vulnerability | Optional | - |

### Finding Description Format

```text
- [ ] **[Severity]** `Detection location` Vulnerability overview.
  **CVE/CWE**: Document when applicable.
  **Impact**: Specific impact if exploited.
  **Fix Suggestion**: Specific remediation method.
  **Fix Difficulty**: Low / Medium / High.
  **False Positive Possibility**: Yes / No (state rationale when Yes).
```

### Vocabulary Constraints

| Term | Definition |
| ---- | ---------- |
| SCA | Software Composition Analysis. Vulnerability scanning of dependency packages |
| SAST | Static Application Security Testing. Static analysis of source code |
| DAST | Dynamic Application Security Testing. Dynamic scanning of running applications |
| CVE | Common Vulnerabilities and Exposures. Identification numbers for disclosed vulnerabilities |
| CWE | Common Weakness Enumeration. Classification of software weaknesses |
| CVSS | Common Vulnerability Scoring System. Vulnerability severity score (0.0–10.0) |
| False Positive | A detection result that is not actually a vulnerability |
| Passive Scan | Only observing normal request/response (non-intrusive) |
| Active Scan | Intentionally sending attack patterns to verify vulnerabilities |

### Structural Constraints

- Include CVE/CWE numbers in findings wherever possible
- Fix suggestions must be specific code changes or commands
- State rationale for false positive determinations
- Always record the version of tools used for scanning

**PASS criteria**: every finding includes CVE/CWE (when applicable), impact, fix suggestion, fix difficulty, and false-positive determination / every CRITICAL/HIGH finding has a numbered recommended action / the scanning tool version is recorded.

## Report Format

```markdown
# Security Scan Report: [Target Overview]

## Disclaimer
This report is reference information based on automated tools and is not a substitute
for comprehensive security assessment. Security specialist review is recommended for critical systems.

## Scan Overview
- Scan Date: YYYY-MM-DD HH:MM
- Target: [Application name/URL/Repository]
- Scan Scope: SCA / SAST / DAST / Secret Detection / Header Analysis
- Tools Used:
  - [Tool name vX.X.X] (Target category)

## Executive Summary
- Findings: CRITICAL X / HIGH Y / MEDIUM Z / LOW W / INFO V
- Overall Risk Assessment: High / Medium / Low
- Items Requiring Immediate Response: X

## Findings

### CRITICAL (Immediate Response)
- [ ] **[CRITICAL]** `Detection location` Vulnerability overview.
  **CVE/CWE**: CVE-XXXX-XXXXX / CWE-XXX.
  **Impact**: Impact description.
  **Fix Suggestion**: Remediation method.
  **Fix Difficulty**: Low / Medium / High.

### HIGH (Within 1 Week)
(Same format as above)

### MEDIUM (Before Next Release)
(Same format as above)

### LOW (Planned Response)
(Same format as above)

### INFO (Reference)
(Same format as above)

## Dependency Package Summary

| Package | Current Version | Vulnerability | Severity | Fix Version | Production Impact |
| ------- | --------------- | ------------- | -------- | ----------- | ----------------- |
| [Name] | [ver] | CVE-XXXX | HIGH | [ver] | Yes / No |

## DAST Results Summary

| Alert | Risk | Count | CWE | Example URL |
| ----- | ---- | ----- | --- | ----------- |
| [Alert name] | High/Medium/Low | X | CWE-XXX | /path |

## Recommended Actions
1. **[Severity]** [Action description] (Fix Difficulty: Low/Medium/High)
2. ...

## Next Scan Recommendations
- [Suggestions for additional tools and scan scope]
- Recommended Scan Frequency: [Daily / Weekly / Pre-release]
```

## Tool Installation Guide

Minimum setup: `npm audit` (no additional installation required).
Recommended setup: gitleaks + OWASP ZAP + semgrep.

```bash
# gitleaks (Secret Detection)
# https://github.com/gitleaks/gitleaks#installing
brew install gitleaks  # macOS
# Or download binary from GitHub Releases

# OWASP ZAP (DAST)
# Use via Docker (no installation needed)
# docker run --rm ghcr.io/zaproxy/zaproxy:stable zap-baseline.py -t <URL>

# semgrep (SAST)
# https://semgrep.dev/docs/getting-started/
pip install semgrep
# Or brew install semgrep
```

## Prohibited Actions

- Modifying source code (including test files)
- Running active scans against production environments (development/staging only)
- Installing scan tools without user confirmation
- Underestimating vulnerability information (when uncertain, rate higher)
- Transcribing detected sensitive information into the report (mask it)
- Definitively stating "no issues" (use "no detections within scan scope")

## Related references (loaded on demand by Claude)

@.claude/guardrails.md
@.claude/permissions-guide.md
@.claude/quality-gates.md
@.claude/pitfalls.md
