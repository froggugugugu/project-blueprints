# plan — Output templates

> Skeletons referenced from SKILL.md. Copy the structure and fill it in.

## Output Format

```markdown
# Design Document: [Feature Name]

## Requirements Summary
- [Acceptance criteria in bullet points]

## Impact Analysis
| Category | File | Change Description |
| --- | --- | --- |
| Schema | src/shared/types/xxx.ts | Add fields |
| Store | src/stores/xxx-store.ts | Add actions |

## Task Breakdown

### Phase 1 (Parallelizable)
- [ ] T1 — [Description] (Changed files: ... | Depends on: none)
- [ ] T2 — [Description] (Changed files: ... | Depends on: none)

### Phase 2 (After Phase 1)
- [ ] T3 — [Description] (Changed files: ... | Depends on: T1)

### Phase 3 (Sequential)
- [ ] T4 — [Description] (Changed files: ... | Depends on: T2, T3)

## Dependency Graph
T1 ──┐
     ├──→ T3 ──→ T4
T2 ──┘

## Test Strategy
### Unit Tests
- [Targets and approach]

### E2E Tests
- [Target scenarios]

## Documentation Update Plan
### project-config.md
- [State impact if any (e.g., new technology → §2, new pitfall → §11)]

### docs/
- [State impact if any (e.g., new store → docs/project.md, new schema → docs/data-model.md)]

## Risks & Concerns
- [Notable items if any]
```
