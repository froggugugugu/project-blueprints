---
name: review-fix
description: >
  Automatically retrieves and analyzes CodeRabbit/Copilot review comments on GitHub PRs, then executes fix → test → commit & push in one go.
  Triggers: review-fix, fix review, fix review comments, CodeRabbit review fix, Copilot review fix, PR review fix, review comments fix.
  Use this skill whenever asked to "fix the review comments," "address the review," or "review-fix" after reviews have been posted on a PR.
  Takes optional argument: /review-fix <PR number>
---

# Review Fix

A skill that automatically retrieves CodeRabbit / GitHub Copilot review comments on a GitHub PR,
analyzes and classifies the feedback, then executes fix → test → commit & push in one go.

The goal is to eliminate the manual effort of reading review comments one by one and fixing them by hand.
It accurately understands the reviewer's intent and applies fixes following the project's quality standards (`CLAUDE.md`).

## Usage

```text
/review-fix          # Auto-detect PR from current branch
/review-fix 37       # Specify PR #37
```

## Prerequisites

| Requirement | Details |
| ----------- | ------- |
| `gh` CLI | GitHub CLI must be installed and authenticated |
| Branch | Must be checked out to the branch corresponding to the PR |
| Test commands | Test commands defined in `docs/project.md` must be available |

## Workflow

### Phase 1: Retrieve Review Comments

If the PR number is omitted, auto-detect from the current branch:

```bash
gh pr view --json number --jq '.number'
```

Retrieve all review comments using these two APIs:

```bash
# Inline comments (feedback on specific file lines)
gh api repos/{owner}/{repo}/pulls/{pr}/comments \
  --jq '.[] | .user.login + " | " + .path + ":" + (.line | tostring) + " | " + (.body | split("\n")[0])'

# Review summaries
gh api repos/{owner}/{repo}/pulls/{pr}/reviews \
  --jq '.[] | .user.login + " | " + .state + " | " + (.body | length | tostring)'
```

For long comment bodies, retrieve the full text for analysis:

```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments \
  --jq '.[] | select(.user.login == "coderabbitai[bot]" or .user.login == "copilot-pull-request-reviewer[bot]" or .user.login == "Copilot") | "📄 " + .path + ":" + (.line | tostring) + "\n" + .body + "\n---"'
```

### Phase 2: Filtering, Cross-Referencing & Classification

This Phase consists of 3 steps. Since CodeRabbit retains old comments even after fix pushes,
cross-referencing with current code is essential. Skipping this step would result in double-fixing already-resolved issues.

#### Step 1: Filter Duplicate & Resolved Comments

CodeRabbit appends "✅ Addressed in commit XXXXXXX" to resolved comments.
Comments containing this are automatically filtered out.

Also, when multiple review cycles run on the same PR, old and new comments coexist.
**Only target comments from the latest review cycle** (filter by `created_at`).

#### Step 2: Cross-Reference with Current Code

For each remaining comment, **read the current code of the referenced file**
and determine whether the issue has already been fixed.

Determination criteria:
- The code at the flagged location has already been changed according to the suggested fix → **Already fixed**
- The code at the flagged location remains as-is or has other issues → **Needs fix**

Comments determined as already fixed are counted as "Confirmed (no action needed)" and no fix is applied.

#### Step 3: Category Classification

Classify comments determined as needing fixes into the following categories.

| Category | Criteria | Action |
| -------- | -------- | ------ |
| **Major** | Bugs, security, data integrity, unhandled async, consistency breakage | Must fix |
| **Minor** | Insufficient error handling, NaN checks, unused code, stale closures | Fix |
| **Nitpick** | Coding style, naming, comment improvements | Fix |
| **Config** | Configuration file fixes (.coderabbit.yaml, etc.) | Fix |
| **Skip** | output/ only, docstring coverage, protected files (.env, etc.) | Skip |

Classification hints:
- Reference CodeRabbit labels (`_🟠 Major_`, `_🟡 Minor_`, `_🔵 Trivial_`)
- Judge importance from Copilot's feedback text
- Handle multiple comments on the same file together

### Phase 3: Present Fix Plan (Design Gate)

Before starting fixes, present the plan in the following format:

```
## Review Comment Fix Plan

Total N items: Needs fix N / Confirmed N / Skip N

### Major (N items)
| # | File:Line | Comment | Fix Plan |
|---|-----------|---------|----------|
| 1 | bikes.ts:189 | Save succeeds for non-existent bikeId | console.warn → throw new Error |

### Minor (N items)
| # | File:Line | Comment | Fix Plan |
|---|-----------|---------|----------|

### Confirmed (No Action Needed) (N items)
| # | File:Line | Comment | Confirmation Result |
|---|-----------|---------|---------------------|
| 1 | InspectionSection.tsx:60 | error state unused | Error display added in previous fix |

### Skip (N items)
| # | Comment | Skip Reason |
|---|---------|-------------|
```

This plan is presented to the user but fixes begin without waiting for approval (auto-fix mode).
The user can interrupt if they want to stop midway.

### Phase 4: Auto-Fix

Execute fixes following a workflow aligned with the `/implementing-features` skill.

1. **Read target files**: Read all files referenced in the comments
2. **Apply fixes**: Fix code based on the comment content
   - Fix/add related tests simultaneously
   - Fix multiple comments on the same file together
3. **Utilize subagents**: Delegate independent fixes to subagents in parallel

Fix principles:
- Accurately understand the reviewer's intent and fix accordingly
- Do not change areas not flagged in comments (maintain scope)
- Do not over-fix (minimum changes necessary to address the feedback)
- Do not break existing tests

### Phase 5: Verification

After fixes are complete, run the project's verification commands:

```bash
# Run tests (use commands from docs/project.md)
pnpm run test:run

# Run lint
pnpm run lint

# Dependency direction check (if configured)
pnpm run depcruise
```

Repeat fixes until all pass.

### Phase 6: Commit & Push

Once all verification passes, commit and push.

Commit message format:

```
fix: address CodeRabbit/Copilot review comments

- <one-line fix summary>
- <one-line fix summary>
- ...

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
```

Only commit modified source files. Do not include untracked files.

### Phase 7: Result Report

Report the following at the end:

```
## Fix Complete

### Fix Summary
| Category | Count | Action |
|----------|-------|--------|
| Major    | N     | N fixed, N confirmed |
| Minor    | N     | N fixed, N confirmed |
| Nitpick  | N     | N fixed, N confirmed |
| Config   | N     | N fixed, N skipped |
| Skip     | N     | Skipped |

### Test Results
- Tests: XXXX pass / 0 fail
- Lint: 0 errors
- Commit: <hash>

### Items Requiring Manual Action
- Add trailing newline to .env.example (skipped as protected file)
```

## Out of Scope (Not Auto-Fixed)

The following comments are excluded from auto-fix and prompt manual action:

- markdownlint comments on documents under `output/` (PLAN, PRD, etc.)
- docstring coverage warnings (CodeRabbit Pre-merge checks)
- Protected files like `.env`, `.env.example` (blocked by hooks)
- Changes with security risks (major changes to auth/authorization logic)
- Comments requiring architecture-level design changes

## Prohibited Actions

- Hook bypass with `--no-verify`
- `--force` push
- Changes to files not flagged in comments (except for ripple-effect fixes)
- Implicit deletion/overwriting of user data
