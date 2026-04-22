# Pitfalls — Common Failure Patterns in Claude Code Collaborative Development

Frequent failure cases and mitigations for AI-assisted development.
Project-specific pitfalls discovered during work should be added to `project-config.md` §11 or `docs/development-patterns.md`.
This file contains **universal, template-wide pitfalls** only.

## Operational pitfalls

### 1. CLAUDE.md bloat

| Field | Content |
| ----- | ------- |
| **Symptom** | As CLAUDE.md grows, Claude stops following earlier instructions |
| **Cause** | Above ~200 lines, important rules get buried in low-priority noise. Token cost also grows per session |
| **Mitigation** | Keep CLAUDE.md to cross-cutting rules only. Split details into skills, `docs/`, or `.claude/rules/`. Use `@path` imports |

### 2. Subagents don't inherit parent skills / rules

| Field | Content |
| ----- | ------- |
| **Symptom** | Calling a skill from a subagent doesn't apply the parent's CLAUDE.md or rules |
| **Cause** | Claude Code semantics: subagents spin up in isolated contexts and don't share parent memory |
| **Mitigation** | Restate required rules and prerequisites in the subagent `prompt`. Also document them in the agent file body |

### 3. `~/.claude/skills/` must be flat

| Field | Content |
| ----- | ------- |
| **Symptom** | `~/.claude/skills/category/my-skill/SKILL.md` isn't discovered |
| **Cause** | User-level skill scan is 1-level only; not recursive |
| **Mitigation** | Place as `~/.claude/skills/<skill-name>/SKILL.md` (flat). Project-level `.claude/skills/` allows nesting |

### 4. Token explosion from full-content injection

| Field | Content |
| ----- | ------- |
| **Symptom** | Skill / agent runs slow, cost is 10× expected |
| **Cause** | A skill body or agent prompt is reading huge files with `Read` in full |
| **Mitigation** | Narrow with Grep first, then Read. Use Read's `limit`/`offset`. Split large docs into `@docs/...` imports |

### 5. Hook exit code confusion (1 vs 2)

| Field | Content |
| ----- | ------- |
| **Symptom** | Dangerous commands slip through even though the hook "should" block |
| **Cause** | Hook returns `exit 1`, but Claude Code treats only `exit 2` as a block |
| **Mitigation** | Always `exit 2` for block hooks. Use `exit 0` + stderr for warnings. See `safety-check.sh` for a reference |

### 6. ANTHROPIC_API_KEY scope too broad — billing accident

| Field | Content |
| ----- | ------- |
| **Symptom** | Unintended large API consumption causing high charges ($100s-$1000s) |
| **Cause** | Unlimited API keys used in GitHub Actions / CI. Runaway PR creation or autonomous loops |
| **Mitigation** | Set monthly / daily spend limits on the API key. Configure `max_turns` / `timeout_minutes` for `claude-code-action`. Use dual exit gates for autonomous loops |

## Security / permission pitfalls

### 7. Misunderstanding the MCP trust model

| Field | Content |
| ----- | ------- |
| **Symptom** | Secrets leak through an MCP server that ran arbitrary commands |
| **Cause** | MCP servers have local arbitrary-command privileges. Adding a malicious one to `.mcp.json` is dangerous |
| **Mitigation** | Use only official / trusted sources. Inject credentials via env vars (`${VAR}`). `permissions.deny` unknown MCPs and `permissions.allow` the specific ones |

### 8. Accidentally sharing `.claude/settings.local.json`

| Field | Content |
| ----- | ------- |
| **Symptom** | A personal allow list gets shared with the team, unexpectedly permitting commands in other environments |
| **Cause** | `settings.local.json` isn't in `.gitignore`, or it was committed before being listed |
| **Mitigation** | Always include it in `.gitignore`. Team-shared rules go in `settings.json` instead |

### 9. Crossing `input/` ↔ `output/` boundaries

| Field | Content |
| ----- | ------- |
| **Symptom** | AI rewrites `input/requirements/REQ_*.md`, or a human edits `output/reports/` by hand |
| **Cause** | A session doesn't know the input/output separation rules |
| **Mitigation** | Carry CLAUDE.md's "Document Management Policy" in every agent prompt. Scope write permissions via the agent's `tools` field |

### 10. Committing `testreport/`

| Field | Content |
| ----- | ------- |
| **Symptom** | Repository bloats with coverage HTML or huge JSON files |
| **Cause** | `setup.sh` updates `.gitignore`, but the project committed outputs before the setup |
| **Mitigation** | Ensure `.gitignore` includes `testreport/`. If history has mixed outputs, use `git filter-repo` to prune |

## Skill / team operation pitfalls

### 11. Skill `description` too long → ambiguous invocation

| Field | Content |
| ----- | ------- |
| **Symptom** | Skills trigger at the wrong time or fail to trigger |
| **Cause** | `description` over ~500 chars degrades Claude's matching precision |
| **Mitigation** | Keep to 1-2 sentences, ~100 chars. Use "Use when ..." phrasing |

### 12. Shared-layer conflicts with parallel teams

| Field | Content |
| ----- | ------- |
| **Symptom** | `TEAM_PJM --parallel` runs multiple Bundles that collide on `src/shared/` |
| **Cause** | Shared-layer separation was skipped when identifying Feature Bundles |
| **Mitigation** | Follow the "Feature Bundle rules" in `TEAM_PJM.md`. Handle shared-layer changes sequentially in Phase 4b |

### 13. Duplicate updates to `project-config.md` §11 and `docs/development-patterns.md`

| Field | Content |
| ----- | ------- |
| **Symptom** | Pitfalls get written to two files; it's unclear which is authoritative |
| **Cause** | Ambiguous ownership. Multiple skills write the same information in different places |
| **Mitigation** | Follow CLAUDE.md's "Conflict Prevention" tables. Primary owner is `/implementing-features` |

### 14. `@` import path mistakes

| Field | Content |
| ----- | ------- |
| **Symptom** | `@.claude/pitfalls.md` can't be found; CLAUDE.md references break |
| **Cause** | `@` imports are resolved relative to the repository root (via Claude Code), not CLAUDE.md's own directory |
| **Mitigation** | Existing `@docs/*.md` / `@.claude/*.md` patterns are repo-root relative. When in doubt, verify with `ls` |

### 15. Temptation to bypass Git hooks

| Field | Content |
| ----- | ------- |
| **Symptom** | Hook fails, developer uses `--no-verify` to push through; bugs surface later |
| **Cause** | Bypassing feels faster than fixing the hook failure |
| **Mitigation** | `--no-verify` is blocked by `safety-check.sh`. When tempted, first investigate what the hook is protecting. See also CLAUDE.md §Git Operations Policy |

## Future expansion candidates (out of scope)

The following are not in the current template but under consideration:

- **Dedicated `/bug-fix` skill**: Pimzino-style Report → Analyze → Fix → Verify pipeline
- **EARS-format requirements**: Introduce gotalab/cc-sdd style Kiro spec-driven approach in `/prd`
- **`brief.md` artifact**: Add a Phase 0 scope summary for session resumption
- **Plugin packaging**: Add `.claude-plugin/marketplace.json` for marketplace distribution
- **English/Japanese sync**: Maintain parity between `project-blueprint/` and `project-blueprint-en/`

These are tracked as expansion items; currently noted only as "future candidates".
