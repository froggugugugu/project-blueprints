---
name: limit-resume
description: >
  Prepares, launches and monitors a runner that works through a task queue unattended and, when a subscription usage limit (5-hour or weekly) is hit, waits until the reset time and continues.
  Use when asked to keep going after the limit resets, run overnight, run unattended, or wait out the limit. Manual invocation only.
argument-hint: "[setup | status | stop] (default: setup)"
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(python3 .agents/skills/limit-resume/scripts/limit_resume.py *), Bash(claude --version), Bash(codex --version), Bash(codex login status), Bash(touch testreport/limit-resume/STOP), Bash(tail *)
disable-model-invocation: true
---

# Limit Resume — wait out usage limits and keep running unattended

Treat a usage-limit stop as a wait, not a failure: once the limit resets, the same queue resumes where it left off.
This keeps long work inside the subscription instead of paying per use.

**Do not launch the runner inside this session.** It is a long-running process that waits hours to days, and its lifetime does not match a session's (exit, compaction).
Prepare the queue and the launch command; the user starts it in a separate terminal (`tmux`, `nohup`, etc.).

## Layout

| Item | Location |
| ---- | -------- |
| Runner | `.agents/skills/limit-resume/scripts/limit_resume.py` (standard library only, Python 3.9+) |
| Queue | `output/tasks/limit-resume-queue.md` (default location; change with `--queue`) |
| State | `testreport/limit-resume/state.json` (per task: `pending` / `done` / `failed` and the session ID used to resume) |
| Log | `testreport/limit-resume/runs.jsonl` (runs, waits, resumes; with Claude Code also the API-equivalent cost per task, with Codex the token counts) |
| Stop | Creating `testreport/limit-resume/STOP` stops the runner while waiting or before the next task |

What the runner does:

1. Passes the queue's tasks one at a time to `claude -p --output-format json --permission-mode dontAsk` (`codex exec --json` for Codex)
2. On a usage-limit message, reads the reset time from it and sleeps until reset + 120 seconds. If it cannot read one, it waits 15 minutes, doubling up to 2 hours
3. On resume, the interrupted session continues (Claude Code: `--resume <session_id>`; Codex: `codex exec resume <thread_id>`)
4. Limit stops do not count as attempts. Other failures are tried twice, then the task is marked `failed` and the runner moves on
5. State is saved after every step, so the same command resumes after a stop (`done` tasks are skipped)

## Arguments

| Argument | What to do |
| -------- | ---------- |
| `setup` (default) | Go through "Preparation" below and hand over the launch command |
| `status` | Read the `--status` summary and the tail of `runs.jsonl`; report progress, whether it is waiting, and failed tasks |
| `stop` | Run `touch testreport/limit-resume/STOP`, and tell the user that deleting it and rerunning the same command resumes |

## Preparation (setup)

Go in this order.

1. **Billing check**: confirm these two points with the user. The runner cannot read billing settings, so this is the place to stop if needed
   - Usage credits (pay-per-use beyond the limit) are disabled, or a spend limit is set. Left enabled, the runner may keep going on credits instead of waiting
   - No API key is used. When one is, runs bill the API instead of the subscription. For Claude Code that is `ANTHROPIC_API_KEY`;
     for Codex, `CODEX_API_KEY` / `OPENAI_API_KEY`, and `codex login status` must show a ChatGPT login (on any of these the runner refuses to start without `--allow-api-key`)
2. **CLI check**: `claude --version` (or `codex --version`) works
3. **Write the queue**: split the request into tasks and write them to `output/tasks/limit-resume-queue.md` in the format below. Each task must
   - Make sense on its own (no conversation carries over from the previous task). State target files, done criteria and the verification command in the body
   - Be safe to run twice (idempotent), because resumes and reruns happen
   - Contain no irreversible operation (push, merge, delete, deploy). If one is needed, copy the user's explicit instruction into the task
4. **Permission check**: under `dontAsk`, anything not in the allow list is denied. Check that the commands the tasks need (tests, lint, `git commit`, ...)
   are allowed in `.claude/settings.json` or `.claude/settings.local.json`; if not, propose the additions (edit only after the user agrees)
5. **Dry run**: run `python3 .agents/skills/limit-resume/scripts/limit_resume.py --queue output/tasks/limit-resume-queue.md --dry-run` and confirm
   the target tasks, the assembled commands, and that there are no `NG:` lines (failed preflight checks)
6. **Hand over the launch command**: show the user "Launch" below and finish

### Queue format

```markdown
# limit-resume queue
<!-- One task per `## <id>` heading. Ids are alphanumerics and hyphens. HTML comments are ignored -->

## fix-lint
Fix the lint errors in `src/`. Done when `npm run lint` reports 0 errors. End with the output of `npm run lint`.

## add-tests-parser
Add tests covering every branch of `src/parser.ts` to `tests/parser.test.ts`.
Done when `npm test -- parser` passes with coverage of 80% or more. Make one commit (do not push).
```

## Launch

```bash
# Example with tmux (keeps running after the terminal closes)
tmux new -s limit-resume \
  'python3 .agents/skills/limit-resume/scripts/limit_resume.py --queue output/tasks/limit-resume-queue.md'

# Progress
python3 .agents/skills/limit-resume/scripts/limit_resume.py --queue output/tasks/limit-resume-queue.md --status
tail -f testreport/limit-resume/runs.jsonl

# Stop (works while waiting too). Delete the file and rerun the same command to resume
touch testreport/limit-resume/STOP
```

Common options:

| Option | Default | Use |
| ------ | ------- | --- |
| `--agent claude\|codex` | `claude` | Agent to run |
| `--permission-mode` | `dontAsk` | Claude Code permission mode. `bypassPermissions` is refused |
| `--max-wait-hours` | `170` | Exit instead of waiting when the reset is further away (keep the default to wait out the weekly limit) |
| `--notify-cmd "<cmd>"` | none | Runs `<cmd> <message>` on every wait, completion and failure (e.g. `terminal-notifier -message`) |
| `--stop-on-failure` | off | Stop the queue at the first `failed` task |
| `--retry-failed` | off | Rerun tasks marked `failed` last time |
| `--max-turns` / `--model` | none | Passed through to `claude -p` |

## Report (status)

```markdown
## limit-resume status
- Queue: done N / pending N / failed N
- Now: <running task id | waiting until <time> (reason) | stopped | finished>
- Failed tasks: <id and the gist of the runs.jsonl tail> (or "none")
- API-equivalent cost total: $X (an estimate of the same usage on the API, not the subscription bill)
- Next step: <handle failed / add to the queue / nothing>
```

## With Codex

- `--agent codex` uses `codex exec`. Permissions follow `.codex/config.toml` (the runner passes no dangerous flags)
- After a limit stop the runner continues the same thread with `codex exec resume --json <thread_id>`. After any other failure it starts over, so write tasks to be idempotent
- Whether a stop is a usage limit is decided from the `turn.failed` / `error` event messages only (never from the model's answer)
- Codex's limit message wording has not been verified on the real CLI. When no reset time can be read, the runner falls back to the exponential backoff above

## Rules

- Do not recommend usage credits to shorten the wait. If the work cannot wait, let the user choose between waiting and paying
- Keep secrets out of task bodies (`runs.jsonl` keeps the tail of the output)
- Do not silently drop `failed` tasks. Report the cause and let the user decide whether to fix or remove them
