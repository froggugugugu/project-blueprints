# Scan Category Detail

Execution commands, checklists, and judgment criteria for the 5 categories `security-scan` performs.

## 1. Dependency Package Vulnerability Scan (SCA)

Detect dependency packages with known vulnerabilities (CVEs).

```bash
# npm standard
npm audit --json > testreport/security/npm-audit.json
npm audit

# More detailed analysis (when installed in the project)
# npx snyk test
# trivy fs --scanners vuln .
```

### Checklist

- [ ] Verified vulnerabilities in direct dependencies
- [ ] Verified vulnerabilities in transitive dependencies (including devDependencies)
- [ ] Checked if CRITICAL/HIGH vulnerabilities have patches available
- [ ] Verified if vulnerable packages are included in the production build

### Judgment Criteria

| Condition | Verdict |
| --------- | ------- |
| 0 CRITICAL/HIGH issues | PASS |
| CRITICAL/HIGH exists but not in production build (devDependencies only) | WARNING |
| CRITICAL/HIGH included in production build | FAIL |

## 2. Static Application Security Testing (SAST)

Statically detect security issues within source code.

### Detection Targets (OWASP Top 10 Based)

| Vulnerability Category | CWE | OWASP Top 10 |
| ---------------------- | --- | ------------ |
| Cross-Site Scripting (XSS) | CWE-79 | A03:2021 |
| Injection | CWE-89, CWE-78 | A03:2021 |
| Sensitive Information Exposure (Hardcoded Credentials) | CWE-798 | A02:2021 |
| Insecure Code Execution (Dynamic Code Evaluation) | CWE-95 | A08:2021 |
| Input Validation Deficiency | CWE-20 | A03:2021 |
| Cryptographic Failures | CWE-327 | A02:2021 |

### Grep-Based Simple Detection

When tools are not installed, search source code for patterns matching OWASP CWE patterns:

- **CWE-79 (XSS)**: Unsafe HTML injection APIs (innerHTML, framework-specific raw HTML insertion, etc.)
- **CWE-798 (Hardcoded Credentials)**: password, secret, api_key, token literals in source code
- **CWE-95 (Dynamic Code Evaluation)**: Functions that dynamically generate/execute code from strings

```bash
# When security tools are installed
# npx semgrep --config auto src/
```

### Checklist

- [ ] Scanned for CWE-79 (XSS) patterns
- [ ] Scanned for CWE-798 (Hardcoded Credentials)
- [ ] Scanned for CWE-95 (Dynamic Code Evaluation) patterns
- [ ] Verified user input validation status
- [ ] Covered major OWASP Top 10 categories

## 3. Dynamic Application Security Testing (DAST)

Perform security scans against a running application.

### OWASP ZAP

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

### Prerequisites

- Docker must be installed
- Target application must be running (dev server or built preview)
- Network access must be available

### Scan Mode Selection

| Mode | Command | Duration | Use Case |
| ---- | ------- | -------- | -------- |
| Baseline | `zap-baseline.py` | 1–2 min | CI/daily check (passive scan only) |
| Full | `zap-full-scan.py` | 10–30 min | Detailed scan before release |
| API | `zap-api-scan.py` | 5–15 min | API spec-based scan |

### Checklist

- [ ] Executed scan against the target URL
- [ ] Verified security header configuration
- [ ] Verified CSP (Content Security Policy) configuration
- [ ] Verified cookie attributes (Secure, HttpOnly, SameSite)

## 4. Secret Detection

Detect sensitive information in source code or Git history.

```bash
# gitleaks (scan including Git history)
gitleaks detect --source . --report-path testreport/security/gitleaks.json --report-format json

# gitleaks (staged files only)
gitleaks protect --staged --report-path testreport/security/gitleaks-staged.json

# trufflehog (Git history scan)
trufflehog git file://. --json > testreport/security/trufflehog.json
```

### Detection Targets

- API keys and access tokens
- Passwords and credentials
- Private keys (SSH, PGP)
- Database connection strings
- Cloud provider credentials (AWS, GCP, Azure)
- Committed `.env` files

## 5. Security Header & Configuration Analysis

Verify security of HTTP response headers and application configuration.

### Required Headers

| Header | Recommended Value | Purpose |
| ------ | ----------------- | ------- |
| `Content-Security-Policy` | Appropriate directives | XSS and data injection prevention |
| `X-Content-Type-Options` | `nosniff` | MIME sniffing prevention |
| `X-Frame-Options` | `DENY` or `SAMEORIGIN` | Clickjacking prevention |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | HTTPS enforcement |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Referrer information leak prevention |
| `Permissions-Policy` | Allow only necessary APIs | Browser feature restriction |
