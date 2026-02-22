# Project Blueprint

Claude Codeプロジェクトの AI協調開発環境テンプレート。

プロジェクト固有の「人間の決定事項」を **`project-config.md`の1ファイルに集約**し、
ルーティング・ストア一覧・データモデル等の設計成果物はAIが自動生成・メンテナンスする。

---

## セットアップ手順

### 方法A: setup.sh で1コマンドセットアップ（推奨）

```bash
bash setup.sh /path/to/your-project
```

これだけで以下がすべて完了する:
- `.claude/`、`docs/`、`input/`、`output/`、`testreport/`、`project-config.md` のコピー
- `CLAUDE.md` のプロジェクトルートへの配置
- `.gitignore` への `testreport/` 追記
- 既存 `.claude/` がある場合は `.claude.bak/` に自動バックアップ

### 方法B: 手動コピー

```bash
cp -r project-blueprint/.claude /path/to/new-project/.claude
cp -r project-blueprint/docs /path/to/new-project/docs
cp -r project-blueprint/input /path/to/new-project/input
cp -r project-blueprint/output /path/to/new-project/output
cp -r project-blueprint/testreport /path/to/new-project/testreport
cp project-blueprint/project-config.md /path/to/new-project/project-config.md

# CLAUDE.md をプロジェクトルートに移動（.claude/ 内の重複を除去）
mv /path/to/new-project/.claude/CLAUDE.md /path/to/new-project/CLAUDE.md
```

### 2. project-config.mdを記入

> 記入例として [project-config.sample.md](project-config.sample.md) を参照（タスク管理アプリを題材にした全セクション記入済みサンプル）。

**必須セクション**（最低限これだけ埋めれば動作する）:

| セクション | 内容 |
| --- | --- |
| 1. プロジェクト基本情報 | 名前・概要・言語 |
| 2. 技術スタック | 使用するフレームワーク・ライブラリ |
| 3. コマンド | 開発・テスト・ビルドコマンド |
| 6. 品質基準 | カバレッジ目標・TDD有無 |

**推奨セクション**（記入すると品質が向上する）:

| セクション | 内容 |
| --- | --- |
| 4. アーキテクチャ | パターン・依存ルール |
| 7. デザインシステム | 参照するデザインガイド |
| 11. 注意事項 | フレームワーク固有の落とし穴（AIも追記） |

#### 段階的記入ガイド

すべてのセクションを一度に埋める必要はない。目的に応じて段階的に記入する:

| ステップ | 記入セクション | 利用可能になるスキル |
| -------- | -------------- | -------------------- |
| 最小構成 | §1 + §2 + §3 | `/prd`, `/plan` |
| 推奨構成 | + §4 | `/architecture`, `/implementing-features`, 全チーム |
| フル構成 | 全セクション | 全スキル（`/security-scan`, `/legal-check` 等） |

§6（品質基準）はスキルの前提条件ではないが、TDD・カバレッジ目標・品質ゲートの有効化に使用する。
未記入のオプションセクションはスキル実行時にスキップされる。

### 3. .gitignore に追記

> `setup.sh` を使った場合はこの手順は不要（自動で追記される）。

`testreport/` はツール直接出力（HTML/JSON/LCOV等）であり、リポジトリには含めない:

```gitignore
# ツール直接出力（AI生成の生データ）
testreport/
```

### 4. 権限設定をカスタマイズ

```bash
cp .claude/settings.local.json.template .claude/settings.local.json
```

### 5. 動作確認（ハローワールド）

セットアップが正しく完了したか、以下の最小手順で確認する:

```text
# スキル単体で動作確認（project-config.md の§1〜§3 が記入済みであること）
/plan プロジェクトの初期セットアップ状況を確認

# 正常に動作すれば、project-config.md と docs/ の参照が解決できている
```

期待される動作:

- AIが `project-config.md` と `docs/` を読み取り、現状のプロジェクト構成を分析する
- 出力として影響調査・タスク分解が提示される
- エラーが出る場合はファイルのコピー漏れや `project-config.md` の未記入セクションを確認する

### 6. docs/ の初回生成（任意）

セットアップ直後、`docs/` 配下はスタブ（空テンプレート）状態。
以下のスキル実行時に自動生成される:

| ファイル | 生成トリガー | 必要な project-config.md |
| -------- | ------------ | ----------------------- |
| `docs/architecture.md` | `/architecture` | §1〜§4 |
| `docs/project.md` | `/architecture` or `/implementing-features` | §1〜§3（最小）、§5,§7,§11〜§12も参照 |
| `docs/data-model.md` | `/implementing-features`（初回実装時） | §2, §5 |
| `docs/development-patterns.md` | `/implementing-features`（初回実装時） | §2, §7, §11 |

> **スタブのままでもスキルは動作する。** 各スキルは `docs/` がスタブの場合、
> `project-config.md` を直接参照してフォールバックする。
> PJMチームを使う場合は Phase 2〜4 で自動的に生成される。

---

## クイックスタート（セットアップ後）

セットアップ完了後、以下の手順で開発を開始する。

### PJMチーム（フルライフサイクル）

```text
1. input/requirements/ に要求メモを配置（例: input/requirements/REQ_001.md）
2. Claude Codeで以下を実行:

   .claude/teams/TEAM_PJM.md input/requirements/REQ_001.md

   # 自律モード（ゲート承認をPJMに委任、最終報告のみ人間に提示）
   .claude/teams/TEAM_PJM.md input/requirements/REQ_001.md --auto

3. output/ に生成された成果物をレビュー・承認
```

### 個別スキル（チームなし）

スキル単体でも利用可能。引数は省略可能:

```text
/prd input/requirements/REQ_001.md
/plan ユーザー認証機能の設計
/implementing-features output/tasks/TASK_auth.md
/code-review src/features/assignment/
```

### 専門チーム

特定フェーズに特化したチームも利用可能。引数は省略可能:

```text
.claude/teams/TEAM_FEATURE.md output/tasks/TASK_auth.md
.claude/teams/TEAM_PLANNING.md input/requirements/REQ_001.md
.claude/teams/TEAM_QA.md src/features/assignment/
.claude/teams/TEAM_REFACTOR.md src/features/assignment/
```

---

## コンセプト

```text
┌─────────────────────────────────────────────────────────┐
│  人間のインプット                                         │
│                                                         │
│  input/requirements/ .... 要求メモ・要件メモ             │
│  project-config.md ...... 技術選定・品質基準・ポリシー    │
│                                                         │
└────────────────────────────┬────────────────────────────┘
                             │ AI が処理（PJMチーム）
                             ▼
┌─────────────────────────────────────────────────────────┐
│  AIのアウトプット（人間がレビュー）                        │
│                                                         │
│  output/prd/ ............ PRD（要求仕様書）               │
│  output/design/ ......... アーキテクチャ設計書            │
│  output/tasks/ .......... タスク分解・実装指示書          │
│  output/reports/ ........ 品質レポート                    │
│    review/ .............. コードレビュー                  │
│    test/ ................ テスト結果                      │
│    security/ ............ セキュリティスキャン            │
│    legal/ ............... 法務チェック                    │
│                                                         │
│  testreport/ ............ ツール直接出力（.gitignore対象）│
│    coverage/ ............ ユニットテストカバレッジ        │
│    e2e/ ................. E2Eテストレポート               │
│    security/ ............ セキュリティスキャン生データ    │
│                                                         │
│  docs/ .................. 技術ドキュメント（自動生成）    │
│                                                         │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  汎用（そのまま再利用）                                   │
│                                                         │
│  .claude/CLAUDE.md ............ 開発ガイド（横断）       │
│  .claude/skills/ .............. 11個のスキル定義         │
│  .claude/teams/ ............... 5チーム定義              │
│  .claude/tasks/ ............... タスク指示書テンプレート  │
│  .claude/settings.json ........ プラグイン設定           │
│  .claude/settings.local.json .. 権限設定テンプレート     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## ファイル構成

```text
project-blueprint/
│
├── README.md                              ← このファイル
├── setup.sh                               ← 1コマンドセットアップスクリプト
├── project-config.md                      ← [人間+AI] 設定ファイル（12セクション）
├── project-config.sample.md               ← 記入済みサンプル（タスク管理アプリ）
│
├── input/                                 ← [人間] インプット
│   ├── README.md                            使い方ガイド
│   └── requirements/                        要求メモ置き場
│
├── output/                                ← [AI生成] アウトプット（人間がレビュー）
│   ├── README.md                            成果物の説明
│   ├── prd/                                 PRD
│   ├── design/                              アーキテクチャ設計書
│   ├── tasks/                               タスク分解
│   └── reports/                             品質レポート
│       ├── review/                            コードレビュー
│       ├── test/                              テスト結果
│       ├── security/                          セキュリティスキャン
│       └── legal/                             法務チェック
│
├── testreport/                            ← [AI生成] ツール直接出力（.gitignore対象）
│   ├── coverage/                            ユニットテストカバレッジ（HTML/LCOV）
│   ├── e2e/                                 E2Eテストレポート・トレース
│   └── security/                            セキュリティスキャン生データ
│
├── .claude/
│   ├── CLAUDE.md                          ← [汎用] 開発ガイド
│   ├── settings.json                      ← [汎用] プラグイン設定
│   ├── settings.local.json.template       ← [カスタマイズ] 権限設定テンプレート
│   │
│   ├── skills/                            ← [汎用] 11スキル定義
│   │   ├── plan/SKILL.md                    設計・計画
│   │   ├── implementing-features/SKILL.md   TDD実装
│   │   ├── ui-ux-design/SKILL.md            UI/UX設計
│   │   ├── e2e-testing/SKILL.md             E2Eテスト
│   │   ├── code-review/SKILL.md             コードレビュー
│   │   ├── performance/SKILL.md             パフォーマンス最適化
│   │   ├── refactoring/SKILL.md             リファクタリング
│   │   ├── legal-check/SKILL.md             IT法務チェック
│   │   ├── security-scan/                   セキュリティスキャン
│   │   │   ├── SKILL.md
│   │   │   └── SETUP_GUIDE.md                 ツール導入ガイド
│   │   ├── prd/SKILL.md                     PRD生成
│   │   └── architecture/SKILL.md            アーキテクチャ設計
│   │
│   ├── teams/                             ← [汎用] 5チーム定義
│   │   ├── README.md                        チーム利用ガイド
│   │   ├── TEAM_PJM.md                      フルライフサイクル管理
│   │   ├── TEAM_FEATURE.md                  機能開発
│   │   ├── TEAM_QA.md                       品質保証
│   │   ├── TEAM_PLANNING.md                 設計フェーズ
│   │   └── TEAM_REFACTOR.md                 リファクタリング
│   │
│   └── tasks/                             ← [汎用] タスクテンプレート
│       ├── TASK_TEMPLATE.md                 機能開発指示書
│       ├── TASK_REVIEW_TEMPLATE.md          レビュー指示書
│       └── LESSONS_TEMPLATE.md              学びの記録テンプレート
│
└── docs/                                  ← [AI生成] 技術ドキュメント
    ├── project.md                           ルーティング・ストア・コマンド
    ├── architecture.md                      ディレクトリ構成・テスト
    ├── data-model.md                        スキーマ・バリデーション
    └── development-patterns.md              コード規約・落とし穴
```

### 人間 vs AIの責任分担

| 領域 | 人間が作成 | AIが生成 |
| ---- | ---------- | --------- |
| 要求・要件 | `input/requirements/` に配置 | `output/prd/` にPRD生成 |
| 技術選定・ポリシー | `project-config.md` に記入 | バージョン変更時に自動更新 |
| アーキテクチャ設計 | — | `output/design/` に生成 |
| タスク分解 | — | `output/tasks/` に生成 |
| 実装 | — | ソースコードを直接変更 |
| 品質レポート | — | `output/reports/` に生成 |
| ツール直接出力 | — | `testreport/` に出力（.gitignore対象） |
| 技術ドキュメント | — | `docs/` に自動生成 |

---

## チームとスキル

### チーム一覧

| テンプレート | 用途 | メンバー | スキル数 |
| --- | --- | --- | --- |
| **`TEAM_PJM.md`** | **フルライフサイクル管理（推奨）** | **6名** | **11/11** |
| `TEAM_FEATURE.md` | 機能開発・バグ修正 | 5名 | 5 |
| `TEAM_QA.md` | 品質保証・監査 | 5名 | 5 |
| `TEAM_PLANNING.md` | 設計フェーズ | 4名 | 3 |
| `TEAM_REFACTOR.md` | リファクタリング | 4名 | 5 |

チーム選定ガイド・ワークフロー詳細・起動パターン・スキルカバレッジは `.claude/teams/README.md` を参照。

### スキル一覧（全11スキル）

全スキルは引数を省略可能。省略時はユーザーに対話的に確認する。
読み取り専用スキルは `context: fork`（会話コンテキストのコピーで実行）。

| スキル | コマンド | モード | project-config.md更新 |
| ------ | -------- | ------ | ---------------------- |
| PRD | `/prd <ファイルパス>` | 読み取り専用 | — |
| Architecture | `/architecture <ファイルパス>` | 読み取り専用 | — |
| Plan | `/plan <説明 or ファイルパス>` | 読み取り専用 | §11を更新可 |
| Implementing Features | `/implementing-features <タスクファイル or 指示>` | 読み書き | §2, §3, §11を更新 |
| UI/UX Design | `/ui-ux-design <対象ファイル or 指示>` | レビュー/実装 | — |
| Code Review | `/code-review <対象ファイル or 指示>` | 読み取り専用 | — |
| E2E Testing | `/e2e-testing <対象機能 or 指示>` | 読み書き | — |
| Performance | `/performance <対象 or 指示>` | 読み書き | §11を更新 |
| Refactoring | `/refactoring <対象ディレクトリ or 指示>` | 読み書き | — |
| Security Scan | `/security-scan <対象範囲 or 指示>` | 読み取り専用 | — |
| Legal Check | `/legal-check <対象範囲 or 指示>` | 読み取り専用 | — |

スキルパイプライン: `/prd` → `/architecture` → `/plan` → `/implementing-features` → `/code-review` + `/security-scan` + `/e2e-testing` + `/performance`

---

## 品質ゲート

| ゲート | タイミング | 提示内容 |
| --- | --- | --- |
| ゲート1 | PRD生成後 | 要件の網羅性・曖昧さの解消 |
| ゲート2 | 設計完了後 | 技術選定・構成の妥当性 |
| ゲート3 | タスク分解後 | 粒度・依存関係の正確性 |
| ゲート4 | 実装完了後 | テスト結果・カバレッジ・静的解析 |
| ゲート5 | 検証完了後 | 全品質レポートの集約 |

通過基準: テスト全パス + カバレッジ目標以上 + 静的解析エラー0件

---

## 設計思想

### 人間は「何を作るか」を決め、AIは「どう作るか」を担う

- **人間が決定**: 要求、技術スタック、品質基準、ポリシー
- **AIが管理**: PRD、設計、実装、テスト、レビュー、ドキュメント同期
- **双方向同期**: AIは開発中に`project-config.md`も更新する

### インプットとアウトプットを明確に分離する

- `input/` は人間が書く場所（AIは読み取り専用）
- `output/` はAIが生成する場所（人間がレビュー）
- 各ゲートポイントで人間が確認・承認できる

### プロジェクト固有 vs 汎用を分離する

- `.claude/` 配下は**汎用**（プロジェクトを問わず再利用可能）
- `docs/` 配下は**プロジェクト固有**（AIが生成・メンテナンス）
- `input/` `output/` は**プロジェクト固有**（実行ごとの成果物）

---

## 既存プロジェクトへの導入

すでにソースコードがあるプロジェクトにブループリントを導入する手順。

### 1. ファイルをコピー

`setup.sh` を使えば既存 `.claude/` の自動バックアップ込みで1コマンドで完了する:

```bash
bash setup.sh /path/to/existing-project
```

手動の場合は以下（既存の `.claude/` があれば事前にバックアップ）:

```bash
# 既存の .claude/ があればバックアップ
[ -d /path/to/project/.claude ] && mv /path/to/project/.claude /path/to/project/.claude.bak

cp -r project-blueprint/.claude /path/to/project/.claude
cp -r project-blueprint/docs /path/to/project/docs
cp -r project-blueprint/input /path/to/project/input
cp -r project-blueprint/output /path/to/project/output
cp -r project-blueprint/testreport /path/to/project/testreport
cp project-blueprint/project-config.md /path/to/project/project-config.md

mv /path/to/project/.claude/CLAUDE.md /path/to/project/CLAUDE.md
```

### 2. project-config.md を既存プロジェクトから記入

既存プロジェクトの `package.json`・設定ファイルを参考にセクションを記入する:

| セクション | 記入元 |
| --- | --- |
| §1 基本情報 | `package.json` の name / description |
| §2 技術スタック | `package.json` の dependencies / devDependencies |
| §3 コマンド | `package.json` の scripts |
| §4 アーキテクチャ | `src/` のディレクトリ構成を確認 |
| §6 品質基準 | 既存のテスト設定・CI設定から |
| §9 Gitポリシー | `.husky/` や `lint-staged` の設定から |

### 3. docs/ を自動生成

`project-config.md` の記入後、以下のいずれかで `docs/` を初期生成する:

```text
# 方法A: アーキテクチャスキルで一括生成（推奨）
/architecture 既存プロジェクトのアーキテクチャをドキュメント化

# 方法B: 実装スキルで段階的に生成
/implementing-features docs/ の初期生成
```

### 4. 既存の .claude/ からの移行

バックアップした `.claude.bak/` に固有設定がある場合:

- `settings.local.json` → 新テンプレートにマージ
- カスタムスキル → `.claude/skills/` にコピー
- memory/ → `.claude/` 外のユーザーレベル設定のため影響なし
