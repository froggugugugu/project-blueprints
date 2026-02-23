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

**1ファイル設定 + 11スキル + 5チーム + 5品質ゲート** で、個人開発からチーム開発まで対応。

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

**これだけで動く。** 残り9セクションは空欄のまま段階的に追記すればよい。

### 段階的に広げる

| ステップ | 記入セクション | できるようになること |
| --- | --- | --- |
| **ミニマル** | §1 + §2 + §3 | `/prd`, `/plan` で設計・分析 |
| **推奨** | + §4（アーキテクチャ） | `/implementing-features`, 全チーム利用 |
| **フル** | 全12セクション | `/security-scan`, `/legal-check` 等の全スキル |

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
- **11スキル**: PRD生成、アーキテクチャ設計、TDD実装、コードレビュー、E2Eテスト、セキュリティスキャン等
- **5チームテンプレート**: フルライフサイクル管理から機能開発・品質保証・リファクタリングまで
- **5品質ゲート**: 各フェーズで人間がレビュー・承認できるチェックポイント
- **Input/Output分離**: 人間の要求（`input/`）とAIの成果物（`output/`）を明確に分離

## スキルパイプライン

```
/prd → /architecture → /plan → /implementing-features → /code-review
                                                      → /security-scan
                                                      → /e2e-testing
                                                      → /performance
```

各スキルは単体でも、チーム（マルチエージェント）としても使用可能。

## チーム一覧

| テンプレート | 用途 | メンバー | スキル数 |
| --- | --- | --- | --- |
| **`TEAM_PJM.md`** | **フルライフサイクル管理（推奨）** | **6名** | **11/11** |
| `TEAM_FEATURE.md` | 機能開発・バグ修正 | 5名 | 5 |
| `TEAM_QA.md` | 品質保証・監査 | 5名 | 5 |
| `TEAM_PLANNING.md` | 設計フェーズ | 4名 | 3 |
| `TEAM_REFACTOR.md` | リファクタリング | 4名 | 5 |

## ファイル構成

```
project-blueprint/
├── README.md                      セットアップ手順・詳細ガイド
├── setup.sh                       1コマンドセットアップスクリプト
├── project-config.md              [人間+AI] 設定ファイル（12セクション）
├── project-config.sample.md       記入済みサンプル（タスク管理アプリ）
├── input/requirements/            [人間] 要求メモ
├── output/                        [AI生成] PRD・設計書・タスク・品質レポート
├── docs/                          [AI生成] 技術ドキュメント（自動メンテナンス）
├── testreport/                    [AI生成] ツール直接出力（.gitignore対象）
└── .claude/
    ├── CLAUDE.md                  開発ガイド（セットアップ時にルートへ移動）
    ├── skills/                    11スキル定義
    ├── teams/                     5チーム定義
    └── tasks/                     タスク指示書テンプレート
```

## ライセンス

MIT
