# 開発ガイド

プロジェクト横断で適用する開発ルール・品質基準・ワークフロー。
全ロール（PM / PdM / 開発 / レビュー / テスト）共通で参照する。

> **プロジェクト固有のパラメータ**: `project-config.md` に集約。
> 技術スタック・ルーティング・データモデル等の詳細は `docs/` 配下を参照。

## 全般

- 必ず日本語で応対する
- 調査やデバッグにはサブエージェントを活用してコンテキストを節約する
- 重要な決定事項は定期的にマークダウンファイルに記録する
- CLAUDE.md は横断ルールのみ記載し、詳細な手順はスキルに委譲する
- 利用可能なスキル（全スキル引数は省略可能。省略時は対話的に確認する）:
  - `/plan <説明 or ファイルパス>` — 設計ドキュメント生成（読み取り専用、実装不可）
  - `/implementing-features <タスクファイル or 指示>` — TDDによる機能実装・バグ修正
  - `/ui-ux-design <対象ファイル or 指示>` — デザインシステム準拠のUI/UX設計・レビュー・実装
  - `/e2e-testing <対象機能 or 指示>` — Playwright E2Eテスト作成
  - `/code-review <対象ファイル or 指示>` — コードレビュー（読み取り専用）
  - `/performance <対象 or 指示>` — 計測ファーストのパフォーマンス最適化
  - `/refactoring <対象ディレクトリ or 指示>` — 安全な段階的リファクタリング
  - `/legal-check <対象範囲 or 指示>` — IT法務観点のコンプライアンスチェック（読み取り専用）
  - `/security-scan <対象範囲 or 指示>` — セキュリティスキャン・脆弱性レポート（読み取り専用）
  - `/prd <ファイルパス>` — 要求メモからPRD生成（読み取り専用）
  - `/architecture <ファイルパス>` — 要求メモからアーキテクチャ設計（読み取り専用）
- スキル選定の判断基準:
  - 新機能実装 → `/implementing-features <タスクファイル>`
  - UI調整・ダークモード・a11y → `/ui-ux-design <対象ファイル>`
  - 大きな変更の事前設計 → `/plan <説明>`
  - PR前の品質確認 → `/code-review <対象ファイル>`
  - ユーザーフローの自動テスト → `/e2e-testing <対象機能>`
  - パフォーマンス改善・バンドル最適化 → `/performance <対象>`
  - 大規模コード再構成・責務移動 → `/refactoring <対象ディレクトリ>`
  - OSSライセンス・プライバシー・知的財産の法務チェック → `/legal-check <対象範囲>`
  - 脆弱性スキャン・OWASP ZAP・依存パッケージ監査 → `/security-scan <対象範囲>`
  - 要求メモ・要件メモからPRD作成 → `/prd <ファイルパス>`
  - 要求メモからシステムアーキテクチャ設計 → `/architecture <ファイルパス>`

## ドキュメント管理方針

### 人間が管理するファイル

- `project-config.md` — 技術選定・品質基準・ポリシー等、人間が決定すべきパラメータ

### AI が管理するファイル

以下のファイルはAIが生成・メンテナンスする。実装変更に伴い自動的に更新する:

- `docs/project.md` — ルーティング・ストア一覧・コマンド・技術スタック
- `docs/architecture.md` — ディレクトリ構成・テスト一覧
- `docs/data-model.md` — スキーマ定義・バリデーションルール
- `docs/development-patterns.md` — コード規約・落とし穴・デザインシステム

### project-config.md の AI メンテナンス

各スキルは設計・実装の進行に伴い、`project-config.md` の以下セクションを更新する:

| 更新トリガー                           | 対象セクション                    |
| -------------------------------------- | --------------------------------- |
| 新しい落とし穴・アンチパターンの発見   | §11（既知の落とし穴）            |
| 依存パッケージの追加・バージョン変更   | §2（技術スタック）               |
| コマンドの追加・変更                   | §3（コマンド）                   |

`project-config.md` と `docs/` の整合性を常に保つこと。

### project-config.md 更新の競合防止

| セクション | 一次更新責務 | ルール |
| ---------- | ------------ | ------ |
| §2（技術スタック） | `/implementing-features` | 他スキルは発見事項を報告し、一次更新者が集約 |
| §3（コマンド） | `/implementing-features` | 同上 |
| §4（アーキテクチャ） | `/implementing-features` | `/architecture` は `output/design/` に出力。採用後に反映 |
| §11（既知の落とし穴） | 全スキル（追記可） | 追記前に既存エントリの重複を確認すること |

### docs/ 更新の競合防止

| ファイル | 一次更新責務 | ルール |
| -------- | ------------ | ------ |
| `docs/project.md` | `/implementing-features` | ルーティング・ストア・コマンド変更時に更新 |
| `docs/architecture.md` | `/implementing-features` | ディレクトリ構成・テスト配置の変更時に更新。`/architecture` は `output/design/` に出力し、採用後に反映 |
| `docs/data-model.md` | `/implementing-features` | スキーマ追加・変更時に更新 |
| `docs/development-patterns.md` | `/implementing-features` | コード規約・落とし穴・デザインシステムの変更時に更新。他スキル（`/performance`, `/refactoring` 等）は発見事項をPLまたは会話内で報告し、一次更新者が集約 |

チームコンテキストでは、PLが `project-config.md` および `docs/` の更新を一元管理する。メンバーは発見事項をPLにメッセージで報告し、PLが更新する。§11への追記のみメンバーが直接実施可能（重複チェック必須）。

## 開発原則

- 仕様が曖昧な場合は推測で進めず、具体的な選択肢を1〜2つ提示して確認する
- 仕様に選択肢があればそれに従い、なければもっとも単純な選択肢を選び仮定であることを明示する
- ユーザーデータの削除・上書きは仕様で明示的に要求された場合のみ
- 保存値と表示値が区別される場合はデータモデルとUIで分離する
- 決定論的であること。丸めモード、フォーマット、集計スコープを明確に定義する
- 過剰設計を避ける。現在の要件に必要な最小限の複雑さで実装する
- コードから読み取れる情報をドキュメントに重複させない

## アーキテクチャガバナンス

レイヤー間の依存方向を制限する。ルールの詳細は `project-config.md` セクション4.4 に定義。

- 依存方向違反は検出コマンド（`project-config.md` に記載）で確認する
- 循環依存は禁止

## 品質基準

- テストファースト（TDD）で段階的に実装する（`project-config.md` セクション6 で有効化時）
- 重要なビジネスロジックにはユニットテストを用意する
- 主要ユーザーフローはE2Eテストでカバーする
- テストカバレッジ目標は `project-config.md` セクション6 に定義

## 品質レポートとゲート

- 各工程の完了時に品質の証跡を人間が判読可能な形式で提示する。
- 品質ゲートは人間が介在できるポイントとして設けるが、介在は任意とする。
- レポートは用途に応じて2つのディレクトリに分離する（`project-config.md` セクション6.1 参照）
- ゲートには2種類ある:
  - **スキルゲート（3つ）**: 各スキル実行中の設計/実装/最終チェックポイント
  - **フェーズゲート（5つ）**: PJMチームのフェーズ間承認ポイント（`.claude/teams/TEAM_PJM.md` 参照）

### レポート出力先

レポートは **ツール直接出力**（機械向け）と **人間向けサマリー**（レビュー用）に分離する:

| 種別 | 出力先 | 内容 | 例 |
| ---- | ------ | ---- | -- |
| ツール直接出力 | `testreport/` | ツールが生成する生データ（HTML/JSON/LCOV等） | カバレッジHTML、ZAPレポート、gitleaks JSON |
| 人間向けサマリー | `output/reports/` | 人間がレビューするMarkdownレポート | コードレビュー結果、法務チェック結果 |

#### ツール直接出力（`testreport/`）

| カテゴリ | 出力先 | 生成スキル |
| -------- | ------ | ---------- |
| ユニットテストカバレッジ | `testreport/coverage/` | `/implementing-features` |
| E2Eテストレポート | `testreport/e2e/` | `/e2e-testing` |
| セキュリティスキャン | `testreport/security/` | `/security-scan` |

#### 人間向けサマリー（`output/reports/`）

| カテゴリ | 出力先 | 生成スキル |
| -------- | ------ | ---------- |
| コードレビュー | `output/reports/review/` | `/code-review` |
| テスト結果サマリー | `output/reports/test/` | `/e2e-testing` |
| セキュリティサマリー | `output/reports/security/` | `/security-scan` |
| 法務チェック | `output/reports/legal/` | `/legal-check` |

### レポート内容

工程の完了時に以下をサマリーとして報告する:

- テスト結果（pass / fail件数、失敗テストの原因）
- カバレッジ（行・分岐の変動、閾値との差分）
- 静的解析（lint / 型チェックの警告・エラー数）
- 変更の影響範囲（変更ファイル数、影響を受けるテスト数）

### ゲートポイント

以下のタイミングで結果を提示し、人間が確認・判断できる状態にする:

1. **設計完了時**: 要件の解釈・テスト設計方針を提示。承認後に実装へ進む
2. **実装完了時**: テスト結果・カバレッジ・静的解析のサマリーを提示
3. **最終確認**: 全チェックリスト項目の充足状況を一覧で提示

ゲートの通過基準:

- テストが全件パスしていること
- カバレッジが目標値を下回っていないこと
- 静的解析のエラーが0件であること
- 上記を満たせば自動通過。満たさない場合は人間の判断を仰ぐ

## 並行開発の原則

- 変更はファイル単位で衝突を回避する。同一ファイルの同時編集は行わない
- 共有レイヤーの変更は逐次で行う
- 大きな機能追加は `/plan` スキルで事前にタスク分解し、並行可能な単位を特定する
- 並行タスク間の依存関係を明示し、ブロッキングを最小化する
- Agent Teams使用時は`.claude/teams/`配下のチームテンプレートに従う（全チーム引数は省略可能。省略時はPLが対話的に確認する）
  - フルライフサイクル → `TEAM_PJM.md <要求メモファイル or 指示>`（全11スキル、推奨）
  - 機能開発 → `TEAM_FEATURE.md <タスクファイル or 実装指示>`
  - 品質保証 → `TEAM_QA.md <対象範囲 or QA指示>`
  - 設計フェーズ → `TEAM_PLANNING.md <要求メモファイル or 設計指示>`
  - リファクタリング → `TEAM_REFACTOR.md <対象ディレクトリ or リファクタリング指示>`
- PJMチームは`input/`のメモを読み、`output/`に成果物を生成する
- PLがタスク分解・依存関係設定・割り当てを行い、メンバーは割り当てタスクのみ実装する
- 共有レイヤーの変更はPLが逐次割り当てし、並行編集を回避する

## 実装ワークフロー

1. 要件確認: 曖昧さがあれば選択肢を提示して解消する
2. 影響調査: 既存コード・テスト・依存関係を確認する
3. テスト設計: 受け入れ基準からテストケースを導出する
4. **🚏 設計ゲート**: 要件解釈とテスト方針を提示し、確認を待つ
5. 実装: テストを通す最小限のコードを書く
6. リファクター: 重複排除・可読性改善（テストグリーンを維持）
7. **🚏 実装ゲート**: テスト結果・カバレッジ・静的解析のサマリーを提示
8. セルフレビュー: 下記チェックリストで検証する
9. **🚏 最終ゲート**: チェックリスト充足状況を一覧で提示

## 実装チェックリスト

設計・コードの提出前に確認すること:

- [ ] データモデル/スキーマの変更点を明記した
- [ ] UIの動作（編集可能vs読み取り専用）を定義した
- [ ] コアアルゴリズム（丸め、書式設定、集計）を明確にした
- [ ] 受け入れ基準との対応を示した
- [ ] 既存テストが壊れていないことを確認した
- [ ] エッジケース（空配列、境界値、null）を考慮した
- [ ] 実装変更に伴い `docs/` 配下のドキュメントを更新した
- [ ] 依存方向ルールに違反していないことを確認した
- [ ] `--no-verify` を使用していないことを確認した

## コミュニケーション規約

- 技術的判断には根拠を必ず添える
- 仕様変更が必要な場合は影響範囲を提示してから着手する
- レビュー指摘には修正内容と理由をセットで回答する
- 不確実な仮定は「【仮定】」と明示する

## ツール利用方針

- ドキュメント参照の優先順位:
  1. プロジェクト内の `docs/` ファイル
  2. `WebFetch` で公式サイトを直接参照
  3. Context7 MCP（公式サイトで不十分な場合のみ）
  4. `WebSearch`（最新情報が必要な場合のみ）
- Playwright MCP: E2Eテストのデバッグ・ビジュアル確認に使用
- draw.io MCP: アーキテクチャ図・フロー図の作成に使用

## セキュリティ強化

セキュリティポリシーの詳細は `project-config.md` セクション10 に定義。
以下は全プロジェクト共通:

- ユーザー入力は必ずバリデーションする
- 依存パッケージの脆弱性を定期確認する

## Git操作ポリシー

- `--no-verify` は禁止（フックを迂回しない）
- `--force` は原則禁止（必要な場合は理由を明示し確認を取る）
- フック失敗時はエラーの原因を修正する（フックを無効化しない）
- Git Hooks の構成は `project-config.md` セクション9 に定義

## プロジェクト固有情報

推奨読み込み順: `project-config.md`（人間の決定事項）→ `docs/`（AI生成の詳細仕様）→ 本ファイル（横断ルール）

@docs/project.md              <!-- 技術スタック・コマンド・ルーティング・ストア一覧 -->
@docs/architecture.md          <!-- ディレクトリ構成・テスト一覧・ドキュメント責務 -->
@docs/data-model.md            <!-- スキーマ定義・フィールド仕様・バリデーション -->
@docs/development-patterns.md  <!-- コード規約・落とし穴・デザインシステム -->

## Workflow Orchestration

### 1. Plan Node Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately – don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes – don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests – then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Task Management

1. **Plan First**: Write plan to `tasks/todo.md` with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to `tasks/todo.md`
6. **Capture Lessons**: Update `tasks/lessons.md` after corrections

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.