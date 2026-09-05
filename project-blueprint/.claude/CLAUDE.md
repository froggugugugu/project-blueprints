# 開発ガイド

プロジェクト横断で適用する開発ルール・品質基準・ワークフロー。
全ロール(PM / PdM / 開発 / レビュー / テスト)共通で参照する。

> **本ファイルは "core" として軽量化されている**(Pro 契約 friendly)。
> 詳細は各 skill / team / agent が必要時に `@import` で個別に取得する。
> プロジェクト固有のパラメータは `project-config.md` に集約。
> 各行は「消すと Claude が間違えるか?」で判定して残す(公式ガイド)。

## 全般

- 必ず日本語で応対する
- 調査やデバッグにはサブエージェントを活用してコンテキストを節約する
- 重要な決定事項は定期的にマークダウンファイルに記録する
- CLAUDE.md は横断ルールのみ記載し、詳細な手順はスキルに委譲する
- **完了報告には証拠を添える**(テスト出力・実行コマンドと結果・スクリーンショット)。証拠のない「完了」は禁止

## スキル一覧(全引数省略可)

| スキル | 用途・トリガー |
| ------ | -------------- |
| `/brainstorm <要求メモ>` | `/prd` 前段の Socratic 質問駆動(読取専用) |
| `/prd <ファイル>` | 要求メモから PRD 生成(読取専用) |
| `/architecture <ファイル>` | 要求メモからシステムアーキテクチャ設計(読取専用) |
| `/plan <説明 or ファイル>` | 設計ドキュメント生成(読取専用) |
| `/adr <判断タイトル>` | 設計判断の経緯・根拠を ADR に記録 |
| `/implementing-features <タスク>` | TDD による機能実装・バグ修正 |
| `/ui-ux-design <対象>` | デザインシステム準拠の UI/UX 設計・レビュー・実装 |
| `/hig-compliance <対象>` | Apple HIG 準拠のシステム横断 UI 一貫性チェック |
| `/design-system-audit <対象>` | デザイントークン整合性監査・標準化 |
| `/e2e-testing <対象機能>` | Playwright E2E テスト作成 |
| `/code-review <対象>` | コードレビュー(読取専用)。同梱の bundled 版は `/review` |
| `/security-scan <対象>` | 脆弱性スキャン・OWASP / CVE 監査(読取専用) |
| `/legal-check <対象>` | OSS ライセンス・プライバシー・知財チェック(読取専用) |
| `/performance <対象>` | 計測ファーストのパフォーマンス最適化 |
| `/refactoring <対象>` | 大規模コード再構成・責務移動 |
| `/review-fix <PR番号>` | CodeRabbit/Copilot レビュー指摘の自動修正(手動起動のみ) |
| `/harness-refine <対象 or 指示>` | ハーネス骨格の自己採点 → 強化 → セルフレビュー(手動起動のみ / 日英ミラー同期必須) |

各 skill は起動時に必要な詳細(`pitfalls.md`、`guardrails.md` 等)を個別に `@import` する。同梱の bundled skill も併用する:
`/verify`(実アプリで動作確認)/ `/btw`(文脈を汚さない脇質問)/ `/goal <完了条件>`(条件を満たすまで継続)/ `/batch`(大量ファイル並列変更)。

## チームテンプレート

`.claude/teams/` 配下の `TEAM_*.md` を起動すると multi-agent 編成で動く:

- フルライフサイクル: `TEAM_PJM.md`(推奨)
- 機能開発: `TEAM_FEATURE.md` / 品質保証: `TEAM_QA.md`
- 設計: `TEAM_PLANNING.md` / デザイン: `TEAM_DESIGN.md` / リファクタ: `TEAM_REFACTOR.md`

team 起動時に `.claude/teams/README.md` と `.claude/agents/README.md` が自動 load される。
`.claude/teams/` は `full` プロファイル(`setup.sh` の既定)でのみ同梱。`minimal` / `standard` では個別 skill のみ使える。

## 開発原則

- 仕様が曖昧な場合は推測で進めず、選択肢を 1〜2 つ提示して確認する
- ユーザーデータの削除・上書きは仕様で明示要求された場合のみ
- 保存値と表示値が区別されるならデータモデルと UI で分離する
- 決定論的であること(丸めモード・フォーマット・集計スコープを明確に)
- 過剰設計を避ける — 現要件に必要な最小限の複雑さで実装
- コードから読み取れる情報をドキュメントに重複させない

## ドキュメント管理(短縮版)

- **人間管理**: `project-config.md`(13 セクション) / `input/requirements/` / `constitution.md`(repo ルート)
- **AI 管理**: `docs/*.md`(プロジェクト派生情報) / `output/`(成果物) / `testreport/`(ツール生データ)
- **AI が更新可能なセクション**: `project-config.md` §2(技術スタック)/ §3(コマンド)/ §11(既知の落とし穴)のみ。§1 / §4-§10 / §12 / §13 は人間決定領域(改変不可)
- **一次更新責務**: `docs/*.md` と `project-config.md` §2/§3 は `/implementing-features` skill が集約。他 skill は発見事項を報告
- **詳細**(競合防止表 / docs 更新の細則):`/implementing-features` が起動時に `@.claude/rules/document-management.md` を load

## ルール階層(`.claude/rules/`)

- `paths:` なし = 全セッション常時 load(`git-conventions.md` のみ)
- `paths:` あり = 該当ファイルを触ったときだけ load(`document-management.md` / `workflow-advanced.md`)
- 言語別・レイヤー別ルールは `.example` をコピーし `paths:` を編集して有効化する
- タスク固有の手順は rules ではなく skill に置く。「毎回必ず X」は指示ではなくフックにする

## アーキテクチャガバナンス

- レイヤー間の依存方向制限。詳細は `project-config.md` §4.4
- 依存方向違反は検出コマンド(`project-config.md` 記載)で確認
- 循環依存は禁止

## 品質基準・ゲート

- TDD(`project-config.md` §6 で有効化時)、ユニット + E2E
- カバレッジ目標は `project-config.md` §6
- **5 つの品質ゲート**: PRD / 設計 / タスク分解 / 実装 / 検証(各 phase で人間介入可)
- 各 phase skill が起動時に `@.claude/quality-gates.md` を load し、ゲート基準を参照する
- **検証手段を先に用意する**: 着手前に pass/fail を返すチェック(テスト / ビルド / lint / スクリーンショット比較)を決め、完了時にその結果を貼る
- `verify-gate.sh` がソース編集後の未検証終了(Stop)と完了マーク(TaskCompleted)を検知する(standard=警告 / strict=差し止め)

## 並行開発

- 同一ファイルの同時編集は禁止
- 共有レイヤー変更は逐次
- Agent Teams は `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` で有効化(既定は無効)
- `teammateMode` は teammate の**表示先**(`in-process` / `auto` / `tmux` / `iterm2`)。
  リポジトリを分離したいときは subagent の `isolation: worktree` を使う
- PJM チームは `input/` を読み `output/` に成果物生成、PL がタスク分解・割り当て

## 実装ワークフロー

要件確認 → 影響調査 → テスト設計 → **🚏 設計ゲート** → 実装 → リファクター → **🚏 実装ゲート** → セルフレビュー → **🚏 最終ゲート**

## 実装チェックリスト(提出前)

- [ ] データモデル/スキーマ変更を明記、UI 動作(編集 vs 読取)を定義
- [ ] コアアルゴリズム(丸め・書式・集計)を明確化
- [ ] 受け入れ基準との対応 / 既存テスト破壊なし / エッジケース考慮
- [ ] 実装変更に伴い `docs/` 更新、依存方向違反なし、`--no-verify` 不使用
- [ ] 検証コマンドの実行結果(pass/fail 件数・エラー数)を報告に添付

## コミュニケーション規約

- 技術的判断には根拠を添える / 仕様変更は影響範囲を提示してから着手
- レビュー指摘は修正内容と理由をセットで回答 / 不確実な仮定は「【仮定】」と明示

## ツール利用方針

- ドキュメント参照: 1) `docs/` → 2) WebFetch 公式 → 3) Context7 MCP → 4) WebSearch
- Playwright MCP: E2E デバッグ・ビジュアル確認 / draw.io MCP: 図表
- 外部サービスは CLI(`gh` / `aws` / `gcloud` 等)を優先する(最もコンテキスト効率が良い)

## セキュリティ

- ユーザー入力は必ずバリデート / 依存 CVE を定期確認
- **多層防御**: sandbox(Layer 0・任意) → フック(Layer 1) → deny/ask(Layer 2) → allow(Layer 3)
- `.env` / 秘密鍵 / `*.pem` は `Read()` deny で読み取り自体を遮断
- 外向き・不可逆操作(push / merge / publish / apply)は `ask` で毎回確認
- auto mode(Pro/Max/Team の既定モード)でも `ask` は必ず確認され、`deny` は分類器より前に効く。分類器は本ファイルも読む
- フックは `--dangerously-skip-permissions` でも有効
- SessionStart フックが起動時に `project-config.md` / `docs/` / `settings.local.json` をチェックし、`output/tasks/PROGRESS.md` があれば冒頭を注入する
- 詳細(deny ルール一覧、保護ファイル、permissions ガイド)は `/security-scan` 等のセキュリティ系 skill 起動時に load
- `project-config.md` §10 にプロジェクト固有ポリシーを定義

> **不変原則** (`constitution.md` で全文管理 / `scan-harness.sh` が改変を検知):
> ①人間↔AI 責務分離 / ②日英 2 言語ミラー / ③5 品質ゲート維持 / ④三層分離(skill/team/agent) /
> ⑤3 層防御維持 / ⑥CLAUDE.md ≤200 行 / ⑦シークレット禁止

## Git 操作

- `--no-verify` 禁止 / `--force` 原則禁止 / フック失敗時はフックを無効化せず原因修正
- Conventional Commits 必須(詳細は `/review-fix` / `/implementing-features` skill が `@.claude/rules/git-conventions.md` を load)

## フェーズ別出力スタイル

`.claude/output-styles/` に 4 種同梱(`/output-style phase-prd` 等で切替。いずれも `keep-coding-instructions: true`):

- 要件定義: `phase-prd` / 設計: `phase-design` / 実装: `phase-implementation` / レビュー: `phase-review`

`statusLine`(`.claude/statusline.sh`)が現在のスタイルとフェーズを自動表示。

## ワークフロー制御

### 1. 計画ファースト

非自明タスク(3+ ステップ or アーキテクチャ判断)は計画モードで開始。差分を 1 文で説明できる作業は計画を省く。検証ステップも計画に含める。

### 2. 調査ファースト

実装前に既存コード・パターン・公式ドキュメントを確認。Glob/Grep → WebFetch → Context7 の優先順位。

### 3. サブエージェント戦略

@.claude/agents/README.md  <!-- 既定 subagent 定義集と使い分けガイド -->

メインコンテキストを圧迫しないよう subagent を積極活用。1 subagent = 1 task。subagent は既定でバックグラウンド実行され要約だけが戻る。
実装後は fresh context のレビュー subagent(`/code-review`)に「正確性・要件に影響する gap のみ」を報告させる。

### 4. コンテキスト保全

`/rewind` でファイル・会話をチェックポイントから復元できる(`fileCheckpointingEnabled`)。無関係なタスクの前に `/clear`。
同じ修正を 2 回繰り返したら `/clear` して指示を書き直す。コンパクト時は PreCompact でバックアップし、
PostCompact が置いたマーカーを次プロンプトで回収して中核ルールを再注入する(詳細は `@.claude/guardrails.md`)。

### 5. 長期タスクの引き継ぎ

複数セッションにまたがる作業は `output/tasks/PROGRESS.md`(雛形 `.claude/tasks/PROGRESS_TEMPLATE.md`)で引き継ぐ。
1 セッション 1 機能、着手前にスモークテスト、終了時はテスト緑 + コミット + PROGRESS 更新。

### 6. 詳細手順(必要時のみ load)

自己改善ループ / 完了前検証 / 自律バグ修正 / タスク管理 / 長期タスクの詳細は `.claude/rules/workflow-advanced.md` を必要 skill が load する。

## コンパクト時の指示(Compact instructions)

コンパクト(要約)では次を必ず保持する: 変更したファイル一覧 / 実行した検証コマンドと結果 /
未完了タスクと次の一手 / 採用・却下した設計判断 / 出力先(`output/`)の規約。ツール出力の生データは捨ててよい。

## プロジェクト固有情報(常時 load)

@docs/project.md              <!-- 技術スタック・コマンド・ルーティング -->
@docs/architecture.md          <!-- ディレクトリ構成・テスト一覧 -->
@docs/data-model.md            <!-- スキーマ・バリデーション -->
@docs/development-patterns.md  <!-- コード規約・パターン -->

> **フォールバック**: 上記ファイルが存在しない or stub 状態(5 行未満)なら `project-config.md` の該当セクションを直接参照する。
