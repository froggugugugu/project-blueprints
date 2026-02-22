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

## はじめかた

```
新規プロジェクト？ ─── Yes ──→ setup.sh で1コマンドセットアップ
       │
       No（既存プロジェクト）
       │
       ▼
  setup.sh で導入（既存 .claude/ は自動バックアップ）
       │
       ▼
  project-config.md を記入（§1〜§3, §6 の4セクション）
       │
       ▼
  Claude Code で /plan を実行して動作確認
       │
       ▼
  開発開始！（/prd → /architecture → /implementing-features）
```

### 1コマンドセットアップ

```bash
git clone https://github.com/your-org/project-blueprints.git
cd project-blueprints
bash project-blueprint/setup.sh /path/to/your-project
```

### 手動セットアップ

```bash
cp -r project-blueprint/.claude /path/to/new-project/.claude
cp -r project-blueprint/docs /path/to/new-project/docs
cp -r project-blueprint/input /path/to/new-project/input
cp -r project-blueprint/output /path/to/new-project/output
cp -r project-blueprint/testreport /path/to/new-project/testreport
cp project-blueprint/project-config.md /path/to/new-project/project-config.md

# CLAUDE.md をプロジェクトルートに移動
mv /path/to/new-project/.claude/CLAUDE.md /path/to/new-project/CLAUDE.md
```

### project-config.md を記入（最低4セクション）

| セクション | 内容 |
| --- | --- |
| §1 プロジェクト基本情報 | 名前・概要・言語 |
| §2 技術スタック | フレームワーク・ライブラリ |
| §3 コマンド | dev / build / test / lint |
| §6 品質基準 | カバレッジ目標・TDD有無 |

> 記入例: [project-config.sample.md](project-blueprint/project-config.sample.md)（タスク管理アプリを題材にした全セクション記入済みサンプル）

### 開発開始

```text
# PJMチームでフルライフサイクル（推奨）
.claude/teams/TEAM_PJM.md input/requirements/REQ_001.md

# スキル単体で利用
/prd input/requirements/REQ_001.md
/plan ユーザー認証機能の設計
/implementing-features output/tasks/TASK_auth.md
```

詳細なセットアップ手順・段階的記入ガイド・既存プロジェクトへの導入方法は [project-blueprint/README.md](project-blueprint/README.md) を参照。

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
