# Project Blueprints

Claude Code向け AI協調開発環境のテンプレート集。

`project-config.md` の1ファイルに人間の決定事項を集約し、要求分析からPRD生成・設計・実装・テスト・レビューまでをAIが一貫して担う。

## 30秒でわかる Project Blueprints

```
あなたが書くもの          →  AIが生成するもの
───────────────────        ─────────────────────
要求メモ（数行のメモ）  →  PRD・設計書・タスク分解
project-config.md       →  TDD実装・テスト・コードレビュー
（技術スタック・品質基準）  品質レポート・技術ドキュメント
```

**1ファイル設定 + 15スキル + 6チーム + 5品質ゲート + 9フック + サブエージェント層** で、個人開発からチーム開発まで対応。

## はじめかた（5分）

```bash
# 1. コピー
git clone https://github.com/your-org/project-blueprints.git
cd project-blueprints
bash project-blueprint/setup.sh /path/to/your-project

# 2. project-config.md の §1〜§3 だけ記入（プロジェクト名・技術スタック・コマンド）

# 3. Claude Code で試す
/plan ログイン機能の設計
```

**これだけで動く。** 残り10セクションは空欄のまま段階的に追記すればよい。

### 段階的に広げる

| ステップ | 記入セクション | できるようになること |
| --- | --- | --- |
| **ミニマル** | §1 + §2 + §3 | `/prd`, `/plan` で設計・分析 |
| **推奨** | + §4（アーキテクチャ） | `/implementing-features`, 全チーム利用 |
| **フル** | 全13セクション | `/security-scan`, `/legal-check` 等の全スキル(§13でモデル選定戦略) |

> §6（品質基準）はTDD・カバレッジ目標の有効化に使用。スキルの前提条件ではないため空欄でも動作する。

### 開発開始

```text
# PJMチームでフルライフサイクル（推奨）
.claude/teams/TEAM_PJM.md input/requirements/REQ_001.md

# スキル単体で利用
/prd input/requirements/REQ_001.md
/plan ユーザー認証機能の設計
/implementing-features output/tasks/TASK_auth.md
```

> 記入例: [project-config.sample.md](project-blueprint/project-config.sample.md) / 詳細: [project-blueprint/README.md](project-blueprint/README.md)

## 特徴

- **設定1ファイル**: 技術スタック・品質基準・ポリシーを `project-config.md` に集約。段階的に記入可能
- **15スキル**: PRD生成 / アーキテクチャ設計 / タスク分解 / TDD実装 / UI/UX整備 / HIG準拠 / デザイントークン監査 / コードレビュー / E2Eテスト / パフォーマンス / リファクタリング / セキュリティスキャン / 法務チェック / ADR記録 / レビュー修正
- **6チームテンプレート**: フルライフサイクル（PJM）/ 機能開発 / 品質保証 / 設計 / デザイン / リファクタリング
- **6サブエージェント**: explorer / planner / security-reviewer / performance-analyst / doc-synchronizer / test-writer（`.claude/agents/`）
- **5品質ゲート**: 各フェーズで人間がレビュー・承認できるチェックポイント
- **9フック**: 多層防御（ブロック系5 + 観測系3 + 通知系1）。`--dangerously-skip-permissions` でも有効
- **Input/Output分離**: 人間の要求（`input/`）とAIの成果物（`output/`）を明確に分離
- **MCP / GitHub Actions テンプレート**: プロジェクト共有 MCP（`.mcp.json.template`）と @claude PR レビュー（`.github/workflows/`）

## スキルパイプライン

```
/prd → /architecture → /plan → /implementing-features → /code-review
                                                      → /security-scan
                                                      → /legal-check
                                                      → /e2e-testing
                                                      → /performance
                                                      → /refactoring

補助系: /ui-ux-design, /hig-compliance, /design-system-audit, /adr, /review-fix
```

各スキルは単体でも、チーム（マルチエージェント）としても、単発の subagent（`.claude/agents/`）にも委譲可能。

## チーム一覧

| テンプレート | 用途 | メンバー | スキル数 |
| --- | --- | --- | --- |
| **`TEAM_PJM.md`** | **フルライフサイクル管理（推奨）** | **6名** | **全スキル網羅** |
| `TEAM_FEATURE.md` | 機能開発・バグ修正 | 5名 | 5 |
| `TEAM_QA.md` | 品質保証・監査 | 5名 | 5 |
| `TEAM_PLANNING.md` | 設計フェーズ | 4名 | 3 |
| `TEAM_DESIGN.md` | デザインシステム整備 | 5名 | 4 |
| `TEAM_REFACTOR.md` | リファクタリング | 4名 | 5 |

## ファイル構成

```
project-blueprint/
├── README.md                      セットアップ手順・詳細ガイド
├── setup.sh                       1コマンドセットアップスクリプト
├── project-config.md              [人間+AI] 設定ファイル（13セクション）
├── project-config.sample.md       記入済みサンプル（タスク管理アプリ）
├── input/requirements/            [人間] 要求メモ
├── output/                        [AI生成] PRD・設計書・タスク・品質レポート
├── docs/                          [AI生成] 技術ドキュメント（自動メンテナンス）
├── testreport/                    [AI生成] ツール直接出力（.gitignore対象）
├── .mcp.json.template             プロジェクト共有MCP設定テンプレート
├── .github/workflows/             Claude Code PR レビューワークフロー
└── .claude/
    ├── CLAUDE.md                  開発ガイド（セットアップ時にルートへ移動）
    ├── skills/                    15スキル定義
    ├── teams/                     6チーム定義
    ├── agents/                    6サブエージェント定義
    ├── rules/                     言語別/パス別ルール拡張ポイント
    ├── hooks/                     9フックスクリプト
    ├── pitfalls.md                AI協調開発の落とし穴集
    └── tasks/                     タスク指示書テンプレート
```

## ライセンス

MIT
