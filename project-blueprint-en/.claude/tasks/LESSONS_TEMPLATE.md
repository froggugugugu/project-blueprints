# Lessons Learned

> A file for accumulating lessons and fix patterns discovered by AI during development.
> Review at the start of each session to avoid repeating the same mistakes.
>
> **Usage**: Copy this template to the project root or `.claude/tasks/`,
> and append project-specific lessons as they arise.

---

## Record Format

Record each lesson in the following format:

### YYYY-MM-DD: Lesson Title

- **Situation**: What you were trying to do
- **Problem**: What happened / What went wrong
- **Cause**: Why it happened
- **Solution**: What to do going forward (specific rules)
- **Related Files**: Affected file paths (optional)

---

## Example Records

### 2025-01-15: Zustand Store Type Inference Not Working

- **Situation**: Trying to create a store with Zustand v5
- **Problem**: Type arguments for `create` were not inferred correctly, and action types became `any`
- **Cause**: Was not using the double-invocation pattern `create<State>()(...)`
- **Solution**: Always use the `create<State>()(impl)` pattern with Zustand v5. Added to `project-config.md` section 11
- **Related Files**: `src/stores/`

### 2025-01-20: act() Warning in Tests

- **Situation**: Writing unit tests for a React component
- **Problem**: Tests involving state updates produced numerous `act()` warnings
- **Cause**: Was using `@testing-library/react`'s `userEvent` without calling `setup()`
- **Solution**: Always call `const user = userEvent.setup()` before using `user.click()`, etc.
- **Related Files**: `src/**/*.test.tsx`

---

## Lessons Log

<!-- Append project-specific lessons here -->
