# Team Definition — Quality Assurance

## Overview

A team that comprehensively verifies the quality of implemented code. Integrates code review, security scanning, legal checks, E2E testing, and performance measurement.

## Usage

```text
.claude/teams/TEAM_QA.md <target-scope or QA instruction>
```

Arguments are optional. When omitted, the PL targets the scope of recent changes (git diff).

### Examples

```text
# Target directory specification
.claude/teams/TEAM_QA.md src/features/assignment/

# Instruction specification
.claude/teams/TEAM_QA.md Quality check the changes in the latest PR

# Specific perspectives only
.claude/teams/TEAM_QA.md Run security scan and legal check only

# No arguments
.claude/teams/TEAM_QA.md
```

## Team Composition

| Role | Agent Type | Model | Skills | Permissions |
| --- | --- | --- | --- | --- |
| **PL (Leader)** | general-purpose | Opus | — | delegate |
| **Reviewer** | general-purpose, mode: plan | Sonnet | `code-review` | plan required (PL approves), source code read-only |
| **Security Analyst** | general-purpose, mode: plan | Sonnet | `security-scan`, `legal-check` | plan required (PL approves), source code read-only |
| **Performance Engineer** | general-purpose | Sonnet | `performance` | plan required (PL approves) |
| **Tester** | general-purpose | Sonnet | `e2e-testing` | test files only |

## Role Responsibilities

### PL (Leader)

- Determine the scope of the quality check (changed files, feature scope)
- Decompose check items into task list with TaskCreate
- Aggregate results from each member and compile an overall quality report
- Make quality gate pass/fail decisions
- **Do not perform inspections yourself**

### Reviewer

- Conduct review of all code changes
- Skills used: `/code-review`
- Verify spec compliance, code quality, test quality, and architecture consistency
- Output reports with specific fix suggestions
- **Do not modify source code**

### Security Analyst

- Check both security vulnerabilities and legal compliance
- Skills used: `/security-scan` (vulnerability scanning), `/legal-check` (legal check)
- Perform dependency package vulnerability scanning, SAST, secret detection
- Verify OSS license compliance, data protection, intellectual property rights
- Output reports to `testreport/security/`
- **Do not modify source code**

### Performance Engineer

- Measure and identify performance bottlenecks
- Skills used: `/performance`
- Measure bundle size analysis, rendering performance, memory usage
- Present Before/After measurement results
- When improvement is needed, propose specific optimization approaches
- Implement optimizations after PL approval

### Tester

- Verify main user flow behavior with E2E tests
- Skills used: `/e2e-testing`
- Focus on regression testing (verify existing features are not broken)
- Output test reports to `testreport/e2e/`
- **Only create/modify test files**

## Workflow

```text
PL: Determine quality check scope → Create task list & assign
  |
  v (Parallelizable)
  +-- Reviewer: Code review with /code-review → Submit report
  +-- Security Analyst: /security-scan + /legal-check → Submit report
  +-- Tester: Run E2E tests with /e2e-testing → Submit report
  +-- Performance Engineer: Measure with /performance → Submit report
  |
  v
PL: Aggregate all reports → Create overall quality report
  |
  v (When issues found)
Performance Engineer: Create plan → PL approval → Implement optimizations
  |
  v
PL: Quality gate decision → Complete or send back
```

### Dependency Rules

| Prerequisite | Next Step |
| --- | --- |
| PL determines scope | Reviewer, Security Analyst, Tester, Performance Engineer start in parallel |
| All reports submitted | PL creates overall quality report |
| When optimization needed | Performance Engineer creates plan → PL approval → Execute |

## Quality Report Output Destinations

Raw tool data goes to `testreport/`, human-readable summaries to `output/reports/`.

| Report | Tool Output | Summary Output | Owner |
| --- | --- | --- | --- |
| Code Review | — | `output/reports/review/` | Reviewer |
| Security Scan | `testreport/security/` | `output/reports/security/` | Security Analyst |
| Legal Check | — | `output/reports/legal/` | Security Analyst |
| E2E Testing | `testreport/e2e/` | `output/reports/test/` | Tester |
| Performance Measurement | — | In-conversation report | Performance Engineer |

## Completion Criteria

- [ ] Reviewer: Code review complete, 0 MUST findings
- [ ] Security Analyst: Security scan complete, 0 CRITICAL/HIGH vulnerabilities
- [ ] Security Analyst: Legal check complete, 0 CRITICAL risks
- [ ] Tester: All E2E tests pass
- [ ] Performance Engineer: Performance measurement complete, no threshold exceeded
- [ ] PL: Overall quality report creation complete

## Tech Stack Reference

All team members must read `.claude/CLAUDE.md` and follow the project's tech stack and conventions.
