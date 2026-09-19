# security-scan — Output templates

> Skeletons referenced from SKILL.md. Copy the structure and fill it in.

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
