# Project Blueprints

[**English**](README-en.md) · [日本語] · [CHANGELOG](CHANGELOG.md) · [constitution](constitution.md)

> **Claude Code 用の唯一の日英バイリンガル開発ハーネス**。
> 要求メモから PRD・設計・実装・QA まで一貫して AI に任せる。
> `project-config.md` の **3 行**だけ書けば動く。

---

## 5 行で動かす

```bash
git clone https://github.com/froggugugugu/project-blueprints.git
bash project-blueprints/project-blueprint/setup.sh ./my-app
echo -e "\n## §2 技術スタック\n- TypeScript / Vite / Vitest" >> ./my-app/project-config.md
cd ./my-app && claude
# → Claude Code 内で:  /plan ログイン機能の設計
```

5 行目で初回起動すれば、もう PRD 生成から TDD 実装、コードレビューまで使えます。

> **デモ**(30 秒): `/prd` → `/architecture` → `/plan` → `/implementing-features` の流れ
> *(GIF 準備中)*

---

## なぜこれ?— 5 つの差別化要素

| | 強み | 競合との違い |
|---|---|---|
| 🌏 | **日英構造ミラー** | 競合(superpowers / ECC / spec-kit / BMAD / claude-flow)は全て英語単一 |
| 🛡️ | **Self-SAST**(`scan-harness.sh`) | ハーネス自身を SAST して secret 漏れ・憲法改竄・deny 弱体化を検出 |
| 📜 | **Constitution-driven** | `constitution.md` の不変原則 7 つを sha256 hash で監視 |
| 🚦 | **5 品質ゲート** | PRD / 設計 / タスク / 実装 / 検証 の各段階で人間介入ポイント |
| 🧩 | **三層分離** | skill(作業)/ team(編成)/ agent(専門家)を混ぜない設計 |

「なぜ自分で作らなかったか」が明確に答えられるように、**コンセプト 7 原則**を [`constitution.md`](constitution.md) に明文化(変更時はハッシュ付き PR が必須)。

---

## いま入っているもの

```text
16 skills    /brainstorm, /prd, /architecture, /plan, /implementing-features,
             /code-review, /security-scan, /legal-check, /performance,
             /refactoring, /e2e-testing, /ui-ux-design, /hig-compliance,
             /design-system-audit, /adr, /review-fix
 6 teams     PJM (full lifecycle) / Feature / QA / Planning / Design / Refactor
 6 agents    explorer, planner, security-reviewer, performance-analyst,
             doc-synchronizer, test-writer
12 hooks     PreToolUse(Bash/Edit/Write/Skill) / PostToolUse / UserPromptSubmit /
             SessionStart / SessionEnd / SubagentStop / PreCompact / Stop / Notification
 4 styles    phase-prd, phase-design, phase-implementation, phase-review
 4 rules     document-management, git-conventions, workflow-advanced (+ README)
 1 plugin    .claude-plugin/marketplace.json (Anthropic marketplace 配布対応)
```

詳細仕様は [`project-blueprint/README.md`](project-blueprint/README.md) と [`CHANGELOG.md`](CHANGELOG.md) を参照。

---

## 段階的に使う

| ステップ | 記入セクション | できること |
| --- | --- | --- |
| **ミニマル** | §1 + §2 + §3 | `/brainstorm`, `/prd`, `/plan` で要件・設計 |
| **推奨** | + §4(アーキテクチャ) | `/implementing-features` で TDD 実装、全チーム利用 |
| **フル** | 全 13 セクション | `/security-scan`, `/legal-check`, モデル選定戦略まで |

---

## 主な使い方

```bash
# フルライフサイクル(推奨)
.claude/teams/TEAM_PJM.md input/requirements/REQ_001.md

# スキル単体
/brainstorm input/requirements/REQ_001.md   # 要求が曖昧なとき
/prd        input/requirements/REQ_001.md   # PRD 生成
/plan       ユーザー認証機能の設計           # タスク分解
/implementing-features output/tasks/TASK_auth.md
```

---

## 📚 さらに知る

- [`project-blueprint/README.md`](project-blueprint/README.md) — セットアップの詳細手順
- [`constitution.md`](constitution.md) — 7 不変原則(変更プロトコル付き)
- [`project-blueprint/.claude/CLAUDE.md`](project-blueprint/.claude/CLAUDE.md) — 開発ガイド(横断ルール、200 行以内)
- [`project-blueprint/.claude/pitfalls.md`](project-blueprint/.claude/pitfalls.md) — AI 協調開発の落とし穴 20 件
- [`project-blueprint/.claude/skills/`](project-blueprint/.claude/skills/) — 全 16 skill の SKILL.md
- [`CHANGELOG.md`](CHANGELOG.md) — リリースノート(SemVer + Keep a Changelog)

## ライセンス

MIT
