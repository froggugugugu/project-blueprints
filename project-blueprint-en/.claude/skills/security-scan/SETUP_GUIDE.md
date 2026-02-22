# Security Scan Tool Setup Guide

This file is a reference for security scanning tool installation procedures.
Referenced from the skill definition (`SKILL.md`).

## Minimum Setup (No Additional Tools)

The following can be run without additional installation on any Node.js project:

```bash
npm audit                                    # Dependency package vulnerabilities
```

Grep-based simple SAST can also be run without additional installation.

## Recommended Setup

| Tool | Category | Installation |
| ---- | -------- | ------------ |
| npm audit | SCA | Built-in |
| gitleaks | Secret Detection | `brew install gitleaks` or GitHub Releases |
| OWASP ZAP | DAST | `docker pull ghcr.io/zaproxy/zaproxy:stable` |
| semgrep | SAST | `pip install semgrep` or `brew install semgrep` |

## CI/CD Integration

```yaml
# GitHub Actions example
security-scan:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - run: npm audit --audit-level=high
    - uses: zaproxy/action-baseline@v0.14.0
      with:
        target: 'http://localhost:3000'
    - uses: gitleaks/gitleaks-action@v2
```
