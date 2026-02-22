---
name: legal-check
description: >
  Reviews code, documents, and configurations for IT legal compliance.
  Triggers: legal, license, compliance, privacy, GDPR, copyright, terms, contract, OSS license, intellectual property, data protection.
  Source-code read-only — never modifies source code or test files.
  Outputs legal check report to output/reports/legal/ (requires Write permission to output/reports/legal/).
  Takes optional argument: /legal-check <target-scope or instruction>
context: fork
---

# IT Legal Check

A skill that reviews code, documents, and configurations from an IT legal perspective.
Verifies OSS license compliance, data protection, intellectual property rights, and terms of service adherence using structured checklists.

**Disclaimer**: Reviews by this skill are AI-generated reference information, not legal advice. Always consult legal professionals for critical decisions.

## Prerequisites

No dependency on `docs/` files. References `project-config.md` §10 (Security Policy) when available.

## Core Principles

- **Never modify source code** (read-only)
- Base findings on specific laws, regulations, and license terms
- State risk levels clearly (CRITICAL / WARNING / INFO)
- For debatable items, present both perspectives and recommend consulting specialists
- Do not definitively state "no issues" based on guesses (state unknowns explicitly)

## Usage

```text
/legal-check <target-scope or check instruction>
```

Arguments are optional. When omitted, target the entire project.
When a file path or perspective is specified, limit the check to that scope.

### Examples

```text
/legal-check Full project legal check
/legal-check Check OSS licenses only
/legal-check src/shared/data/tech-tag-master.ts
```

### Output Destination

- Default: Present report in conversation
- File output: `output/reports/legal/LEGAL_<datetime>.md` (when `output/` directory exists)

### Integration with Other Skills

| Previous Step | This Skill | Next Step |
| ------------- | ---------- | --------- |
| `/implementing-features` | `/legal-check` | (Final step) |

## Review Perspectives

### 1. OSS License Compliance

#### Checklist

- [ ] Verified licenses of all dependency packages
- [ ] Checked for copyleft licenses (GPL, AGPL, LGPL, etc.)
- [ ] Verified license compatibility
- [ ] Required attribution notices are included
- [ ] License files (LICENSE, NOTICE) are properly placed

#### License Risk Classification

| Risk | Example Licenses | Impact |
| ---- | ---------------- | ------ |
| Low | MIT, ISC, BSD-2-Clause, BSD-3-Clause | Attribution only |
| Medium | Apache-2.0 | Attribution + change notice + patent clause |
| High | LGPL-2.1, LGPL-3.0 | Dynamic linking conditions, source provision obligation |
| Caution | GPL-2.0, GPL-3.0, AGPL-3.0 | Same license applies to derivatives, source disclosure obligation |

```bash
# List dependency package licenses
npx license-checker --summary
npx license-checker --csv --out licenses.csv
```

### 2. Data Protection & Privacy

#### Checklist

- [ ] Identified data fields qualifying as personal information
- [ ] Verified data storage locations and retention periods
- [ ] Checked data encryption status (at rest and in transit)
- [ ] Verified user consent acquisition flow is implemented
- [ ] Checked data deletion (right to be forgotten) support status
- [ ] Verified third-party provision and consent acquisition

#### Relevant Regulations

| Regulation | Jurisdiction | Key Requirements |
| ---------- | ------------ | ---------------- |
| PIPA (Personal Information Protection Act) | Japan | Purpose disclosure, safety management measures, third-party provision restrictions |
| GDPR | EU | Explicit consent, data portability, right to be forgotten |
| CCPA/CPRA | US California | Opt-out right, data sale disclosure |
| Telecommunications Business Act (External Transmission Rules) | Japan | Notification/consent for external transmission of user information |

### 3. Intellectual Property Rights

#### Checklist

- [ ] Verified usage permissions for third-party works (code, images, fonts, icons, etc.)
- [ ] Verified copyright ownership of AI-generated code/content
- [ ] Design system and external resource terms of use are complied with
- [ ] No unauthorized use of trademarks
- [ ] Verified font licenses

### 4. Attribution & Credits

#### Checklist

- [ ] OSS library attribution notices are appropriate
- [ ] External design system/guideline source citations are appropriate
- [ ] Icon/image/font credit requirements are met
- [ ] Third-party API terms of use display obligations are met

### 5. Terms of Service & Contracts

#### Checklist

- [ ] Terms of Service exist
- [ ] Privacy Policy exists and matches the implementation
- [ ] Disclaimers are appropriately documented
- [ ] External service (API, etc.) terms of use are complied with

### 6. Security Compliance

#### Checklist

- [ ] Secure storage of confidential information is ensured
- [ ] XSS, CSRF, and other vulnerability countermeasures are implemented
- [ ] Known vulnerabilities in dependency packages verified (`npm audit`)
- [ ] HTTPS enforcement is appropriately configured

## Review Workflow

1. **Scope Confirmation** — Confirm review target (entire codebase / specific feature / dependency packages / documents)
2. **Information Gathering** — Read target code, configuration files, package.json, license files
3. **Perspective-Based Check** — Verify against the 6 perspectives above
4. **Report Output** — Return structured feedback in the format below

## Output Contract

### Section Definitions

| Section | Required | Constraints |
| ------- | -------- | ----------- |
| Disclaimer | ✅ | Fixed text. Do not modify |
| Overview | ✅ | Target scope (enumeration value), finding counts |
| Findings | ✅ | In CRITICAL → WARNING → INFO order. Keep headings even when 0 items |
| License Summary | Conditional | When dependency packages are in scope |
| Data Protection Summary | Conditional | When data handling is in scope |
| Recommended Actions | ✅ | Numbered in priority order. Minimum 1 item |
| Items for Specialist Consultation | Conditional | When debatable items exist |

### Risk Level Definitions

| Level | Criteria | Response Timeline |
| ----- | -------- | ----------------- |
| **CRITICAL** | High likelihood of law/license violation | Immediate response |
| **WARNING** | Gray area under terms, or recommended action | Before next release |
| **INFO** | Reference information. Low current risk but should be aware | Optional |

### Vocabulary Constraints

| Term | Definition |
| ---- | ---------- |
| Attribution | Display obligation for copyright/license text required by the license |
| Copyleft | A clause requiring derivatives to apply the same license |
| Personal Information | Information that can identify a specific individual, as defined by applicable data protection laws |
| Needs Investigation | Items where AI judgment cannot be definitive and specialist confirmation is needed |

## Report Format

```markdown
# IT Legal Check Report: [Target Overview]

## Disclaimer
This report is AI-generated reference information and does not constitute legal advice.
Please consult legal professionals for critical decisions.

## Overview
- Target Scope: Entire codebase / Specific feature / Dependency packages / Documents
- Findings: CRITICAL X / WARNING Y / INFO Z

## Findings

### CRITICAL (Action Required)
- [ ] **[Target]** Finding description. **Basis**: Law/clause. **Recommended Action**: Action method.

### WARNING (Action Recommended)
- [ ] **[Target]** Finding description. **Basis**: Law/clause. **Recommended Action**: Action method.

### INFO (Reference)
- [ ] **[Target]** Finding description. **Notes**: Explanation.

## License Summary

| Package | License | Risk | Attribution | Notes |
| ------- | ------- | ---- | ----------- | ----- |

## Data Protection Summary
- Personal Information Fields: [List of applicable fields]
- Storage Method: [Storage method]
- Encryption: Yes / No / N/A

## Recommended Actions
1. [High-priority action items]

## Items for Specialist Consultation
- [Debatable items, high-risk items]
```

## Prohibited Actions

- Modifying source code (including test files)
- Providing legal advice (limit to reference-level findings)
- Definitively stating "no issues" without basis
- Underestimating risks (when uncertain, recommend consulting specialists)
