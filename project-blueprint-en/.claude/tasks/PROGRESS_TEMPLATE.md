# Progress Handoff Note — <project / feature group>

> **Purpose**: hand work over across multiple sessions (multiple context windows).
> Copy this file to `output/tasks/PROGRESS.md`.
> The SessionStart hook injects its head automatically, so the next session resumes without guessing.
>
> **Principles** (from Anthropic's long-running agent harness findings):
> one feature per session / smoke-test before starting / finish with tests green + a commit + this file updated.
> In the feature list, **only update the `passes` column**. Never delete rows or rewrite acceptance criteria
> (an unimplemented feature would silently disappear).

---

## 1. Current state

| Item | Value |
| ---- | ----- |
| Last updated | YYYY-MM-DD HH:MM (session `xxxxxxxx`) |
| Branch | `feature/...` |
| Last commit | `abc1234 feat: ...` |
| Start command | e.g. `npm run dev` |
| Smoke test | e.g. `npm test -- --run smoke` → expected: all pass |
| Known broken areas | none / `...` (the next session fixes this first) |

---

## 2. Feature list (update `passes` only)

| ID | Feature | Acceptance criteria (verifiable end-to-end) | passes |
| -- | ------- | ------------------------------------------- | ------ |
| F01 | <!-- e.g. user can log in --> | <!-- e.g. valid credentials on /login redirect to /dashboard --> | ❌ |
| F02 | | | ❌ |

- `passes` becomes ✅ **only after real verification** (not just unit tests: E2E or manual checks equivalent to user actions)
- Add rows only when requirements grow. Never delete rows

---

## 3. Next steps (in priority order)

1. F01 — <!-- the first concrete step in one line -->
2. F02 — ...

---

## 4. Session log (newest first)

### YYYY-MM-DD — session `xxxxxxxx`

- **Done**: ...
- **Verification**: `npm test` → 42 pass / 0 fail (paste the evidence)
- **Commit**: `abc1234 feat: ...`
- **Unfinished / handoff**: ...
- **Decisions and rejected options**: ...
