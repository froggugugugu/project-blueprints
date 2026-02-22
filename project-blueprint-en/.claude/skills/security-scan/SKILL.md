---
name: security-scan
description: >
  Runs security scanning tools and generates structured vulnerability reports.
  Triggers: security scan, vulnerability, OWASP, ZAP, npm audit, DAST, SAST, secret detection, dependency check, CVE.
  Source-code read-only — never modifies source code or test files.
  Outputs scan report to output/reports/security/ and raw data to testreport/security/ (requires Write permission to both).
  Takes optional argument: /security-scan <target-scope or instruction>
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

### 1. Dependency Package Vulnerability Scan (SCA)

Detect dependency packages with known vulnerabilities (CVEs).

```bash
# npm standard
npm audit --json > testreport/security/npm-audit.json
npm audit

# More detailed analysis (when installed in the project)
# npx snyk test
# trivy fs --scanners vuln .
```

#### Checklist

- [ ] Verified vulnerabilities in direct dependencies
- [ ] Verified vulnerabilities in transitive dependencies (including devDependencies)
- [ ] Checked if CRITICAL/HIGH vulnerabilities have patches available
- [ ] Verified if vulnerable packages are included in the production build

#### Judgment Criteria

| Condition | Verdict |
| --------- | ------- |
| 0 CRITICAL/HIGH issues | PASS |
| CRITICAL/HIGH exists but not in production build (devDependencies only) | WARNING |
| CRITICAL/HIGH included in production build | FAIL |

### 2. Static Application Security Testing (SAST)

Statically detect security issues within source code.

#### Detection Targets (OWASP Top 10 Based)

| Vulnerability Category | CWE | OWASP Top 10 |
| ---------------------- | --- | ------------ |
| Cross-Site Scripting (XSS) | CWE-79 | A03:2021 |
| Injection | CWE-89, CWE-78 | A03:2021 |
| Sensitive Information Exposure (Hardcoded Credentials) | CWE-798 | A02:2021 |
| Insecure Code Execution (Dynamic Code Evaluation) | CWE-95 | A08:2021 |
| Input Validation Deficiency | CWE-20 | A03:2021 |
| Cryptographic Failures | CWE-327 | A02:2021 |

#### Grep-Based Simple Detection

When tools are not installed, search source code for patterns matching OWASP CWE patterns:

- **CWE-79 (XSS)**: Unsafe HTML injection APIs (innerHTML, framework-specific raw HTML insertion, etc.)
- **CWE-798 (Hardcoded Credentials)**: password, secret, api_key, token literals in source code
- **CWE-95 (Dynamic Code Evaluation)**: Functions that dynamically generate/execute code from strings

```bash
# When security tools are installed
# npx semgrep --config auto src/
```

#### Checklist

- [ ] Scanned for CWE-79 (XSS) patterns
- [ ] Scanned for CWE-798 (Hardcoded Credentials)
- [ ] Scanned for CWE-95 (Dynamic Code Evaluation) patterns
- [ ] Verified user input validation status
- [ ] Covered major OWASP Top 10 categories

### 3. Dynamic Application Security Testing (DAST)

Perform security scans against a running application.

#### OWASP ZAP

```bash
# OWASP ZAP Docker (Baseline Scan: passive scan, fast)
docker run --rm -t ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
  -t <TARGET_URL> \
  -J zap-report.json \
  -r zap-report.html

# OWASP ZAP Docker (Full Scan: active scan, detailed)
docker run --rm -t ghcr.io/zaproxy/zaproxy:stable zap-full-scan.py \
  -t <TARGET_URL> \
  -J zap-report.json \
  -r zap-report.html

# API Scan (when OpenAPI/Swagger spec exists)
docker run --rm -t ghcr.io/zaproxy/zaproxy:stable zap-api-scan.py \
  -t <OPENAPI_SPEC_URL> \
  -f openapi \
  -J zap-api-report.json
```

#### Prerequisites

- Docker must be installed
- Target application must be running (dev server or built preview)
- Network access must be available

#### Scan Mode Selection

| Mode | Command | Duration | Use Case |
| ---- | ------- | -------- | -------- |
| Baseline | `zap-baseline.py` | 1–2 min | CI/daily check (passive scan only) |
| Full | `zap-full-scan.py` | 10–30 min | Detailed scan before release |
| API | `zap-api-scan.py` | 5–15 min | API spec-based scan |

#### Checklist

- [ ] Executed scan against the target URL
- [ ] Verified security header configuration
- [ ] Verified CSP (Content Security Policy) configuration
- [ ] Verified cookie attributes (Secure, HttpOnly, SameSite)

### 4. Secret Detection

Detect sensitive information in source code or Git history.

```bash
# gitleaks (scan including Git history)
gitleaks detect --source . --report-path testreport/security/gitleaks.json --report-format json

# gitleaks (staged files only)
gitleaks protect --staged --report-path testreport/security/gitleaks-staged.json

# trufflehog (Git history scan)
trufflehog git file://. --json > testreport/security/trufflehog.json
```

#### Detection Targets

- API keys and access tokens
- Passwords and credentials
- Private keys (SSH, PGP)
- Database connection strings
- Cloud provider credentials (AWS, GCP, Azure)
- Committed `.env` files

### 5. Security Header & Configuration Analysis

Verify security of HTTP response headers and application configuration.

#### Required Headers

| Header | Recommended Value | Purpose |
| ------ | ----------------- | ------- |
| `Content-Security-Policy` | Appropriate directives | XSS and data injection prevention |
| `X-Content-Type-Options` | `nosniff` | MIME sniffing prevention |
| `X-Frame-Options` | `DENY` or `SAMEORIGIN` | Clickjacking prevention |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | HTTPS enforcement |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Referrer information leak prevention |
| `Permissions-Policy` | Allow only necessary APIs | Browser feature restriction |

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
