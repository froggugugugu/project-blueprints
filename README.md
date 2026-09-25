# Project Blueprints

**Claude Code を「開発ハーネス」として立ち上げるためのテンプレート。**

要求メモ 1 枚から、PRD → 設計 → タスク分解 → 実装 → レビューまでを同じ型で回す。
指示書・スキル・サブエージェント・安全機構・検証ゲートをひとそろいにして、コピーした時点で動く。
対象は言語もフレームワークも問わない。

[サイト](https://froggugugugu.github.io/project-blueprints/) ·
[English](README-en.md) ·
[不変原則](constitution.md) ·
[変更履歴](CHANGELOG.md)

![5 行 quickstart デモ](.github/demo/quickstart.gif)

---

## これは何か

- **AI 協調開発の作業環境**を、プロジェクト開始時に 1 コマンドで用意するための scaffold
- 人間が決めること（技術選定・品質基準・ポリシー）は `project-config.md` の 13 セクションに集約する
- AI が作って維持するもの（`docs/` `output/` `testreport/`）は生成物として分離する
- 日本語版 `project-blueprint/` と英語版 `project-blueprint-en/` を**同じ構造で**同梱する

**これでないもの**: アプリケーションのひな形ではない。React も FastAPI も Rails も入っていない。
入っているのは Claude Code に渡す指示と仕組みだけで、対象プロジェクトの技術は何でもよい。
既存プロジェクトに後から足すこともできる。

---

## 5 行で動かす

```bash
git clone https://github.com/froggugugugu/project-blueprints.git
cd project-blueprints
bash project-blueprint/setup.sh /path/to/your-project   # 英語版は project-blueprint-en/setup.sh
cd /path/to/your-project
claude
```

| プロファイル | 入るもの | 向いている場面 |
| --- | --- | --- |
| `--profile minimal` | skills 5 / agents 2 / hooks 2 | まず触る。既存プロジェクトに最小で足す |
| `--profile standard` | skills・agents・hooks は全部、teams と workflows なし | 1 人で全工程を回す |
| `--profile full`（既定） | すべて | 複数エージェント編成まで使う |

### 最初に書くのは 3 項目だけ

```markdown
## §1. プロジェクト基本情報
プロジェクト名: MyApp
概要: 社内向けの在庫管理

## §2. 技術スタック
- Python 3.13 / FastAPI

## §3. コマンド
- test: pytest
- lint: ruff check .
```

残り 10 セクションは空欄のままで動く。必要になったときに足せばよい。

```text
/plan 在庫の棚卸し機能の設計
```

これだけで `project-config.md` を読み取り、構造化された設計ドキュメントが `output/` に出る。

---

## スキルの流れと品質ゲート

呼び出し順が決まっている。途中の 5 か所で人間が止めて直せる。全部使う必要はなく、1 スキルだけでも成立する。

| 順 | スキル | 役割 | ゲート |
| --- | --- | --- | --- |
| 1 | `/brainstorm` | 要求が曖昧なときに Socratic な質問で輪郭を出す（読取専用） | |
| 2 | `/prd` | 要求メモから PRD を生成。技術選定より先に仕様を固める | 🚏 PRD |
| 3 | `/architecture` | システム構成と依存方向を設計 | 🚏 設計 |
| 4 | `/plan` | 設計をタスクに分解し、着手順を決める | 🚏 タスク分解 |
| 5 | `/implementing-features` | TDD で実装。`docs/` と `project-config.md` の更新も引き受ける | 🚏 実装 |
| 6 | `/code-review` `/security-scan` `/legal-check` `/e2e-testing` `/performance` `/refactoring` | 別コンテキストで検証する | 🚏 検証 |

補助スキル: `/ui-ux-design` `/hig-compliance` `/design-system-audit` `/adr` `/review-fix` `/harness-refine`。
`/harness-refine` はハーネス自身を自己診断して補強するメタスキル。

---

## 入っているもの

```text
 2 guides    AGENTS.md(ツール共通ルール。Codex / Cursor なども読む)+ CLAUDE.md(Claude Code 固有。AGENTS.md を取り込む)
17 skills    企画・設計・実装・レビュー・セキュリティ・法務・性能・リファクタ
             長い詳細は references/(20 ファイル)に分離し、SKILL.md 本文は手順だけに保つ
 8 agents    explorer / researcher / planner / security-reviewer / performance-analyst /
             doc-synchronizer / doc-writer / test-writer
 6 teams     TEAM_PJM(フルライフサイクル・推奨) / FEATURE / QA / PLANNING / DESIGN / REFACTOR
17 hooks     PreToolUse / PostToolUse / SessionStart(compact 再注入)/ ConfigChange / PreCompact / Stop など
             危険コマンド遮断・保護ファイル・未検証終了の検知・書込範囲の強制・防御層を弱める設定変更の阻止
 4 styles    phase-prd / phase-design / phase-implementation / phase-review
 7 rules     常時 1(git 規約)+ パス限定 3(ドキュメント管理・ワークフロー詳細・ハーネス執筆規約)
             + 言語別サンプル 3(.example を外して有効化)
 2 workflows review-sweep(4 観点並列レビュー + 反証検証)/ skill-eval(evals を with・without で実行)
34 evals     全 17 skill に evals.json(典型 + 境界)、assertions 128 件
 1 gate      scripts/validate-harness.sh — ハーネスの仕様乖離を CI で落とす静的検証
 3 CI        claude-review.yml(@claude 対話レビュー)/
             claude-skills-ci.yml(毎 PR に /code-review + /security-scan)/
             claude-scheduled-audit.yml(週次 /security-scan + /legal-check → Issue)
 2 extras    REVIEW.md(Claude の Code Review 用の審査基準)/ .claude/loop.md(/loop の既定プロンプト)
```

---

## 設計の柱

- **人間と AI の責務を分ける** — 人間の決定は 1 ファイルに集約し、AI 管理領域と混ぜない
- **指示ではなく強制にする** — 「毎回必ず X」は文章ではなくフックにする。3 層防御（フック → deny/ask → allow）
- **止めどころを用意する** — 5 つの品質ゲートに加え、ソースを編集したまま検証せず終了するとフックが検知する
- **文脈を食い潰さない** — CLAUDE.md は取り込む AGENTS.md と合わせて 200 行以内。スキルは必要になった詳細だけを読む
- **Claude Code を主系に、他のエージェントとも共有できる** — ツール共通のルールは `AGENTS.md` に置き、Claude Code 固有の仕組みだけを `CLAUDE.md` に残す。Codex / Cursor / Copilot / Gemini CLI を併用するときの役割と書込範囲は `project-config.md` §13.7 で人間が決める
- **期待動作をテストで持つ** — スキルを変えたら `/skill-eval` で with・without の pass rate を比べる
- **壊れたら CI が落ちる** — ハーネス自身の静的検証があり、日英の構造ずれも検出する

不変原則 7 つは [`constitution.md`](constitution.md) にあり、ハッシュで改変を検知する。

---

## 検証

`.claude/` を編集したら、コミット前に検証ゲートを通す。

```bash
bash scripts/validate-harness.sh            # 両ミラー + 日英の構造一致
bash scripts/validate-harness.sh --test     # バリデータ自身の負のテスト
bash scripts/validate-harness.sh --hooks    # フックの機能テスト
bash scripts/validate-harness.sh --online   # .mcp.json の npm パッケージ実在確認
```

LLM を使わず決定論的に、次を検査する。

- frontmatter の enum 逸脱、参照されない権限ルール（`Write(path)` 等）
- 参照先の無い hook 登録、解決しない `@import`、`references/` の壊れたリンク
- skill 本文の長さ、description の文字数と人称、行頭の `@`（起動時に全文添付される書き方）
- `evals/evals.json` のスキーマ、workflow の `meta` 宣言と決定論を壊す関数
- `CLAUDE.md` の `@AGENTS.md` 取り込み、`AGENTS.md` の行頭 `@`、両ファイルが引く `project-config.md` の §番号の実在、2 ファイル合計の行数
- 書込可能な agent の `scope-guard.sh` 登録
- `constitution.md` のハッシュ、日英ミラーの構成一致

CI（`.github/workflows/validate-harness.yml`）が push と PR で同じものを走らせる。
`/harness-refine` は LLM 側の対になる仕組みで、このゲートが通ってから使う。

---

## 段階的に使う

| ステップ | 記入セクション | 動くようになるもの |
| --- | --- | --- |
| **ミニマル** | §1 + §2 + §3 | `/brainstorm` `/prd` `/plan` で要件・設計 |
| **推奨** | + §4（アーキテクチャ） | `/implementing-features` で TDD 実装、全チーム利用 |
| **フル** | 全 13 セクション | `/security-scan` `/legal-check`、モデル選定戦略まで |

```bash
# フルライフサイクル(推奨)
.claude/teams/TEAM_PJM.md input/requirements/REQ_001.md

# スキル単体
/prd        input/requirements/REQ_001.md   # PRD 生成
/plan       ユーザー認証機能の設計           # タスク分解
/implementing-features output/tasks/TASK_auth.md
/code-review src/features/auth/
```

MCP サーバーを足すときは `cp .mcp.json.template .mcp.json` に書いてコミットする（プロジェクト共有）。

---

## 導入は clone + `setup.sh` のみ

**plugin / marketplace 配布は採用していない。** 2026-04 に一度導入し、2026-06 に撤回、
2026-08 に再評価して再び撤回した。理由は好みではなく構造的なもの。

plugin が宣言できるのは `skills` / `agents` / `outputStyles` / `hooks` の 4 種だけで、
`project-config.md` / `docs/` / `input/` / `output/` / `.claude/rules/` / `.claude/teams/` は配布できない。
一方このハーネスは次の状態にある。

```text
17 / 17 skill が、plugin 配布では提供されないファイルを参照している

  docs/               16 / 17        project-config.md   14 / 17
  output/             15 / 17        pitfalls.md         12 / 17
  quality-gates.md    15 / 17        .claude/rules/       3 / 17
```

plugin 単体でインストールしても、**全 skill が前提を欠いた状態で動く**。
これは汎用ツール集ではなくプロジェクトの scaffold であり、
「skill だけ配って周辺ファイルは配らない」形式とは相性が合わない。

> 再検討するなら、上記の依存が解消されたという新しい根拠が必要。

---

## さらに知る

- [`project-blueprint/README.md`](project-blueprint/README.md) — セットアップの詳細手順
- [`project-blueprint/AGENTS.md`](project-blueprint/AGENTS.md) — ツール共通の開発ルール（どのコーディングエージェントも読む）
- [`project-blueprint/.claude/CLAUDE.md`](project-blueprint/.claude/CLAUDE.md) — Claude Code 固有の開発ガイド（AGENTS.md を取り込み、合計 200 行以内）
- [`project-blueprint/.claude/guardrails.md`](project-blueprint/.claude/guardrails.md) — 安全機構の全体像
- [`project-blueprint/.claude/pitfalls.md`](project-blueprint/.claude/pitfalls.md) — AI 協調開発の落とし穴
- [`project-blueprint/.claude/skills/`](project-blueprint/.claude/skills/) — 全 17 skill の SKILL.md
- [`constitution.md`](constitution.md) — 7 不変原則（変更プロトコル付き）
- [`CHANGELOG.md`](CHANGELOG.md) — リリースノート（SemVer + Keep a Changelog）

---

## Acknowledgments — インスパイア元への謝辞

本ブループリントは、以下の優れた Claude Code ハーネス OSS から**概念**を学び、
独立に実装したもの。各プロジェクトの作者と community に深く感謝する。

| プロジェクト | ライセンス | 借りた概念 | 本リポでの実装 |
|---|---|---|---|
| [spec-kit](https://github.com/github/spec-kit) | MIT | `constitution.md` による不変原則の分離思想 | 独自に再構成(7 原則 + sha256 hash 監視) |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | MIT | 「ハーネス自身を SAST する」発想(AgentShield) | `scan-harness.sh` は独自実装(検査項目・閾値も独自) |
| [superpowers](https://github.com/obra/superpowers) | MIT | `/prd` 前段に brainstorming フェーズを置く設計 | `/brainstorm` skill として独立に実装(Socratic テンプレも独自) |
| [BMAD-METHOD](https://github.com/bmadcode/BMAD-METHOD) | MIT | scale-adaptive な persona / チーム構造 | 将来枠として `pitfalls.md` の Out of Scope に記載 |
| [claude-flow](https://github.com/ruvnet/claude-flow) | MIT | topology メタデータ(hierarchical / mesh / star) | [`project-blueprint/.claude/teams/README.md`](project-blueprint/.claude/teams/README.md) に分類軸として導入 |

本リポジトリ内のすべての実装は独立に書かれており、各プロジェクトのコードを
直接流用・複製したものではない。各プロジェクトのライセンス（全 MIT）と本リポ（MIT）は完全互換。

## ライセンス

MIT
