# Project Blueprints

[**English**](README-en.md) · [日本語] · [CHANGELOG](CHANGELOG.md) · [constitution](constitution.md)

> Claude Code 用の AI 協調開発ハーネス。**日英構造ミラー**と**self-SAST**(ハーネス自身の検査)が特徴。
> 要求メモから PRD・設計・実装・QA まで AI に委ねる。
> `project-config.md` の **§2(技術スタック)を 1 行書くだけ**で動く。

**前提**: [Claude Code](https://docs.claude.com/en/docs/claude-code) が `PATH` にインストール済みであること。

---

## 5 行で動かす

```bash
git clone https://github.com/froggugugugu/project-blueprints.git
bash project-blueprints/project-blueprint/setup.sh ./my-app
printf '\n## §2 技術スタック\n- TypeScript / Vite / Vitest\n' >> ./my-app/project-config.md
cd ./my-app && claude
# → Claude Code が起動したらプロンプトで:  /plan ログイン機能の設計
```

この時点で `/brainstorm`(要件曖昧時)→ `/prd` → `/plan` までの**設計フェーズ**が動きます。
`/implementing-features` 等の実装系 skill は §4(アーキテクチャ)を埋めてから — 詳細は下の「[段階的に使う](#段階的に使う)」を参照。

![5 行 quickstart デモ](.github/demo/quickstart.gif)

> 5 行を実行すると `git clone` → `setup.sh`(constitution.md・skills・hooks 配置)
> → `printf` で §2 追記 → `claude` 起動 → `/plan ログイン機能の設計` を Opus 5
> が受理 — までを **30 秒で確認**できます。

---

## なぜこれ?— 5 つの差別化要素

| | 強み | 概要 |
|---|---|---|
| 🌏 | **日英構造ミラー** | `project-blueprint/`(日本語)と `project-blueprint-en/`(英語)が完全同期。多言語対応の Claude Code ハーネスは現状ほぼ存在しない |
| 🛡️ | **Self-SAST**(`scan-harness.sh`) | ハーネス自身を SAST して secret 漏れ・constitution 改竄・deny 弱体化を検出 |
| 📜 | **Constitution-driven** | `constitution.md` の不変原則 7 つを sha256 hash で監視。AI が改竄しようとしたらフックがブロック |
| 🚦 | **5 品質ゲート** | PRD / 設計 / タスク / 実装 / 検証 の各段階で人間介入ポイント(任意) |
| 🧩 | **三層分離** | skill(作業)/ team(編成)/ agent(専門家)を混ぜない設計。layer 間の循環参照を禁止 |
| 🪶 | **Pro 契約フレンドリー** | **セッション開始時**のロードを ~7K tokens に圧縮(従来比 70% 減)。詳細(`pitfalls.md` / `guardrails.md` 等)は各 skill が起動時に必要なものを `@import` で取得する遅延読込設計。skill を使わないセッションでは context window を 17K 以上節約 |

---

## いま入っているもの

```text
17 skills    /brainstorm, /prd, /architecture, /plan, /implementing-features,
             /code-review, /security-scan, /legal-check, /performance,
             /refactoring, /e2e-testing, /ui-ux-design, /hig-compliance,
             /design-system-audit, /adr, /review-fix, /harness-refine
 6 teams     PJM (full lifecycle) / Feature / QA / Planning / Design / Refactor
 8 agents    explorer, planner, researcher, security-reviewer,
             performance-analyst, doc-synchronizer, doc-writer, test-writer
13 hooks     PreToolUse(Bash/Edit|Write|NotebookEdit/Skill) / PostToolUse / PostToolUseFailure /
             UserPromptSubmit / SessionStart / SessionEnd / SubagentStart / SubagentStop /
             PreCompact / PostCompact / Stop / Notification
 4 styles    phase-prd, phase-design, phase-implementation, phase-review
 4 rules     document-management, git-conventions, workflow-advanced (+ README)
 1 gate      scripts/validate-harness.sh — ハーネスの仕様乖離を CI で落とす静的検証
 3 CI        claude-review.yml（@claude 対話レビュー）/
             claude-skills-ci.yml（毎 PR に /code-review + /security-scan）/
             claude-scheduled-audit.yml（週次 /security-scan + /legal-check → Issue）
```

`.claude/` を編集したら、コミット前に検証ゲートを通す:

```bash
bash scripts/validate-harness.sh
```

frontmatter の enum 逸脱、参照されない権限ルール(`Write(path)` 等)、参照先の無い hook 登録、
解決しない `@import`、constitution hash、日英構成の一致を **LLM を使わず決定論的に**チェックする。
バリデータ自身の負のテストは `--test`、npm パッケージの実在確認は `--online`。

詳細仕様は [`project-blueprint/README.md`](project-blueprint/README.md) と [`CHANGELOG.md`](CHANGELOG.md) を参照。

---

## 2 つの導入方法

> **plugin は「一部の skill を手軽に使う」ための副経路**であり、
> 5 品質ゲートを含むフルライフサイクルを回すなら clone を使うこと。
> 下表のとおり plugin ではハーネスの一部が**そもそも配布されない**。

| | clone + `setup.sh`（**主経路**） | plugin（副経路） |
| --- | --- | --- |
| 導入 | `bash setup.sh <dir> --profile <p>` | `/plugin marketplace add froggugugugu/project-blueprints` → `/plugin install project-blueprint@project-blueprints` |
| 配置先 | プロジェクトに実ファイルをコピー | Claude Code のプラグインキャッシュ |
| 編集 | **プロジェクトごとに自由に改変できる** | 読み取り専用（更新で上書きされる） |
| 更新 | 再度 `setup.sh` を実行 | `/plugin update` |
| プロファイル | `minimal` / `standard` / `full` を選べる | フル構成のみ |
| skills（17） | ✅ `/prd` | ⚠️ `/project-blueprint:prd`（名前空間化される） |
| agents（8） | ✅ | ⚠️ `permissionMode` が無視される |
| hooks（13） | ✅ | ✅ |
| output-styles（4） | ✅ | ✅ |
| **`.claude/rules/`** | ✅ | ❌ **配布されない**（plugin にルール用のコンポーネント型が無い） |
| **`.claude/teams/`（6）** | ✅ | ❌ **配布されない**（同上） |
| `project-config.md`・`docs/`・`input/`・`output/` | ✅ | ❌ 配布されない（別途 clone が必要） |
| `constitution.md`・`guardrails.md`・`pitfalls.md` | ✅ | ❌ 配布されない |

### plugin 配布時の既知の制約

1. **`.claude/rules/` が読み込まれない** — プラグインマニフェストにルール用のフィールドが
   存在しない。全セッション常時 load される `git-conventions.md`（Conventional Commits 規約）も
   効かなくなる。`.claude/rules/` を参照する 4 skill と `CLAUDE.md` の `@import` も解決しない。
2. **`.claude/teams/` が配布されない** — `TEAM_PJM.md` 等のチームテンプレートは使えない。
3. **skill の相互参照が名前空間の影響を受ける** — skill 本文には他 skill への参照が
   75 箇所ある（`/implementing-features` 14 / `/prd` 12 / `/code-review` 11 ...）。
   plugin ではこれらが `/project-blueprint:implementing-features` になるため、本文中の
   bare な `/implementing-features` はそのままでは起動できない。
4. **subagent の `permissionMode` / `hooks` / `mcpServers` が無視される**（公式のセキュリティ制約）。
   本テンプレートでは `doc-synchronizer` / `doc-writer` の `permissionMode: acceptEdits` が効かず、
   `docs/` / `output/` への書き込みでも権限確認が出る。

clone 配布ではすべて意図どおり動く。検証ゲートが 1〜4 を毎回 WARN として報告する。

> プラグインマニフェスト（`.claude-plugin/`）は `scripts/gen_plugin_manifest.py` が
> `.claude/settings.json` から生成する。手編集せず再生成すること（ゲートが差分を検出する）。

---

---

## 段階的に使う

| ステップ | 記入セクション | 動くようになるもの |
| --- | --- | --- |
| **ミニマル** | §1 + §2 + §3 | `/brainstorm`, `/prd`, `/plan` で要件・設計 |
| **推奨** | + §4(アーキテクチャ) | `/implementing-features` で TDD 実装、全チーム利用 |
| **フル** | 全 13 セクション | `/security-scan`, `/legal-check`, モデル選定戦略まで |

> 「5 行で動かす」では `§2` だけ仮埋めしている。本格運用では `§1`(プロジェクト名)と `§3`(ビルド/テスト/lint コマンド)も埋めると、より多くの skill が機能する。

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
- [`project-blueprint/.claude/skills/`](project-blueprint/.claude/skills/) — 全 17 skill の SKILL.md
- [`CHANGELOG.md`](CHANGELOG.md) — リリースノート(SemVer + Keep a Changelog)

## Acknowledgments — インスパイア元への謝辞

本ブループリントは、以下の優れた Claude Code ハーネス OSS から**概念**を学び、
独立に実装したものです。各プロジェクトの作者と community に深く感謝します。

| プロジェクト | ライセンス | 借りた概念 | 本リポでの実装 |
|---|---|---|---|
| [spec-kit](https://github.com/github/spec-kit) | MIT | `constitution.md` による不変原則の分離思想 | 独自に再構成(7 原則 + sha256 hash 監視) |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | MIT | 「ハーネス自身を SAST する」発想(AgentShield) | `scan-harness.sh` は独自実装(検査項目・閾値も独自) |
| [superpowers](https://github.com/obra/superpowers) | MIT | `/prd` 前段に brainstorming フェーズを置く設計 | `/brainstorm` skill として独立に実装(Socratic テンプレも独自) |
| [BMAD-METHOD](https://github.com/bmadcode/BMAD-METHOD) | MIT | scale-adaptive な persona / チーム構造 | 将来枠として `pitfalls.md` の Out of Scope に記載 |
| [claude-flow](https://github.com/ruvnet/claude-flow) | MIT | topology メタデータ(hierarchical / mesh / star) | [`project-blueprint/.claude/teams/README.md`](project-blueprint/.claude/teams/README.md) に分類軸として導入 |

本リポジトリ内のすべての実装は独立に書かれており、各プロジェクトのコードを
直接流用・複製したものではありません。各プロジェクトのライセンス(全 MIT)と
本リポ(MIT)は完全互換です。

## ライセンス

MIT
