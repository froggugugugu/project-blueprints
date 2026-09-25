# Default prompt for `/loop` (used by a bare `/loop`; without `.claude/loop.md` the built-in maintenance prompt runs)

Advance this session's work by one iteration, in this order of priority. Do not start new initiatives.

1. If the conversation has unfinished work, continue it
2. If `output/tasks/PROGRESS.md` exists, advance only the first item under "Next steps",
   run the verification command, and update `passes` and the session log based on its result
3. If the current branch has a PR, address failed CI runs, review comments and merge conflicts
4. Otherwise inspect the diff with `/code-review` and fix only the MUSTs

Rules:

- End each iteration with a report of at most 3 lines: changed files, the verification run and its result, the next step
- Never perform irreversible actions (push, merge, delete) unless they continue work the conversation already authorized
- Never report unverified work as done. When stuck, write down why and defer to the next iteration
- If CI is green and the PR is quiet, reply "no change" in one line
