# Git Operations and Commit Conventions

> Imported by `CLAUDE.md` to prevent CLAUDE.md bloat.

## Git operations policy

- `--no-verify` is prohibited (do not bypass hooks)
- `--force` is prohibited in principle (state the reason and get confirmation when necessary)
- When hooks fail, fix the cause of the error (do not disable hooks)
- Git Hooks configuration is defined in `project-config.md` section 9

## Commit message convention (Conventional Commits)

**All commit messages must use Conventional Commits prefixes** for automatic version
management via Release Please.

| Prefix | Purpose | Version Change |
| ------ | ------- | -------------- |
| `feat:` | New feature | minor (0.x.0) |
| `fix:` | Bug fix | patch (0.0.x) |
| `docs:` | Documentation only | none |
| `style:` | Code style (no behavior change) | none |
| `refactor:` | Refactoring (no feature change) | none |
| `perf:` | Performance improvement | none |
| `test:` | Test additions/fixes | none |
| `chore:` | Build/config/CI etc. | none |
| `ci:` | CI configuration changes | none |
| `build:` | Build system and dependency changes | none |
| `revert:` | Revert a previous commit | none |
| `feat!:` or BREAKING CHANGE | Breaking change (no backward compat) | **major (x.0.0)** |

### Rules

- Format: `<type>: <concise description>` (e.g., `feat: add dashboard page`)
- Scope is optional: `feat(map): implement route rendering` is also valid
- Breaking changes: use `feat!:` or include `BREAKING CHANGE:` in the body
- One prefix per commit. Split commits when changes span multiple types
- PR titles follow the same convention
