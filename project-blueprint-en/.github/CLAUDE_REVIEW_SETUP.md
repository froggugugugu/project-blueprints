# Claude Code Automated PR Review — Setup

Setup guide for PR review automation using `anthropics/claude-code-action`.
**This is opt-in**; it does not affect your existing workflow unless enabled.

## Prerequisites

- GitHub repository owner or admin access
- Anthropic API key (from [console.anthropic.com](https://console.anthropic.com))
- Initial cost estimate: $0.05-$0.30 per medium-sized PR with Sonnet

## Setup (4 steps)

### 1. Enable the workflow

```bash
# Copy the template
cp .github/workflows/claude-review.yml.template .github/workflows/claude-review.yml
```

### 2. Register the API key as a GitHub Secret

1. Repository **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `ANTHROPIC_API_KEY`
4. Value: paste the API key from Anthropic Console
5. Click **Add secret**

### 3. Configure API key scope and limits (REQUIRED)

In the Anthropic Console:

1. Set **Rate limits** on the API key (e.g., 1,000 requests/day)
2. Set **Spend limit** (e.g., $50 per month)
3. Use a dedicated **Workspace** (don't mix with production keys)

**Skipping this invites billing incidents** (see `@.claude/pitfalls.md` #6).

### 4. Verify it works

1. Open a test PR
2. Post a PR comment: `@claude please review this PR`
3. A few minutes later, Claude posts a review comment

## Trigger conditions

The default `.yml.template` triggers on:

| Event | Condition |
| ----- | --------- |
| PR comment | Contains `@claude` mention |
| PR review comment | Contains `@claude` mention |
| PR open / update | Non-draft PR |

Disable unwanted triggers by editing the `on:` / `if:` blocks in the `.yml` file.

## Customization

### Model selection

Cost vs quality trade-off:

| Model | Use | Cost estimate |
| ----- | --- | ------------- |
| `claude-opus-5` | High-quality review, architecture audits | High ($0.30+/PR) |
| `claude-sonnet-5` | Standard review (recommended) | Medium ($0.10/PR) |
| `claude-haiku-4-5-20251001` | Lightweight review, quick checks | Low ($0.02/PR) |

### Customize review axes

Edit `direct_prompt` in `claude-review.yml`. Add project-specific perspectives:

```yaml
direct_prompt: |
  ...
  Additional axes:
  6. **Performance**: bundle size increase over 50 KB
  7. **A11y**: keyboard operation, screen reader support
```

### max_turns as runaway protection

Keep `max_turns` low to prevent infinite loops and excessive API consumption:

- 10 (default, sufficient for most PRs)
- 5 (quick checks only)
- 20 (complex PRs — use with caution)

## Security notes

- **Never hard-code API keys**. Always use Secrets
- Keep **Permissions** minimal (contents: read, pull-requests: write). Do not grant contents: write
- **Forked PRs** can't access secrets by default (GitHub policy).
  Using `pull_request_target` works but introduces risk — review carefully
  ([GitHub security warning](https://securitylab.github.com/research/github-actions-preventing-pwn-requests/))

## Cost management

- **Review usage monthly**: Anthropic Console → Usage
- **Alert thresholds**: set an alert at 80% of spend limit
- **Large PRs**: rather than increasing `max_turns`, **split the PR upstream** into smaller, topic-scoped PRs (improves review quality and cost efficiency)
- **Avoid wasted runs**: keep the Draft-PR filter in `if:`

## Troubleshooting

| Symptom | Cause | Fix |
| ------- | ----- | --- |
| Workflow doesn't run | `@claude` misspelled | Ensure lowercase `@claude` |
| API error | Spend limit reached | Raise limit in Anthropic Console or wait |
| Review is off-base | `direct_prompt` too vague | Make the prompt concrete; reference `project-config.md` |
| Doesn't run on forks | Secrets unavailable | GitHub policy; handle manually or via admin-triggered runs |

## Disabling

To disable temporarily:

```bash
# Rename rather than delete (safer)
mv .github/workflows/claude-review.yml .github/workflows/claude-review.yml.disabled
```

Delete the file if permanently removing.

## Choosing between the two workflows

This template ships two workflows. Enable either one or both.

| | `claude-review.yml` | `claude-skills-ci.yml` | `claude-scheduled-audit.yml` |
| --- | --- | --- | --- |
| Implementation | `anthropics/claude-code-action` | `claude -p` (headless CLI) | `claude -p` (headless CLI) |
| Trigger | `@claude` mention on a PR (human-initiated) | Automatic on every PR | Weekly cron + manual dispatch |
| What it runs | Free-form conversational review | Always runs `/code-review` and `/security-scan` | `/security-scan` and `/legal-check` |
| Output | PR comment | PR comment + artifact (`output/reports/`) | GitHub Issue + artifact |
| Uses the blueprint's skills | No | **Yes** | **Yes** |
| Good for | Ad-hoc "take a look at this" reviews | Mechanically enforcing the quality gates | Problems that grow with time (new CVEs, license changes) |

Why `claude-scheduled-audit.yml` runs on GitHub Actions: Claude Code's session-scoped
scheduling (`/loop`, `CronCreate`) fires **only while a session is running and idle**,
and recurring tasks expire after 7 days — unsuitable for unattended, durable schedules.
See "Choosing how to schedule work" in `@.claude/guardrails.md`.

Design points in `claude-skills-ci.yml`:

- **No `--bare`** — the project's `.claude/` (skills / settings / hooks) must load
- `--permission-mode dontAsk` auto-denies anything outside `--allowedTools`
- `BLUEPRINT_HOOK_PROFILE=minimal` passes hooks through, which stops
  `notify-claude.sh` from sending outbound notifications from CI
- Forked PRs are skipped because they receive no secrets
- Untrusted input (PR title, body) is never interpolated into `run:` —
  values are passed through `env:` to avoid command injection

## Related

- Official docs: [anthropics/claude-code-action](https://github.com/anthropics/claude-code-action)
- Headless mode: [docs.claude.com/en/docs/claude-code/headless](https://docs.claude.com/en/docs/claude-code/headless)
- Cost guardrail patterns: `@.claude/pitfalls.md` #6
- Project review conventions: `@.claude/skills/code-review/SKILL.md`
