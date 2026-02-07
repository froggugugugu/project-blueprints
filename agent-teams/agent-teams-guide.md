# Claude Code Agent Teams 業務導入ガイド

> **対象**: エンジニアリングマネージャ / 開発者（Ubuntu + VS Code + Claude Code 環境）  
> **ステータス**: まず自分で検証 → チーム展開判断  
> **作成日**: 2026-02-07

---

## 1. Agent Teams とは

Agent Teams は、複数の Claude Code インスタンスを**チームとして協調動作**させる機能です。

通常の Claude Code セッション（1つのエージェントが逐次処理）とは異なり、以下の構造で並行作業を実現します。

| 役割 | 説明 |
|---|---|
| **Team Lead** | メインセッション。タスクの作成・割り振り・結果の統合を担当 |
| **Teammates** | 個別の Claude Code インスタンス。独自のコンテキストウィンドウで独立して作業 |
| **Shared Task List** | 全エージェントが参照する共有タスクリスト（pending → in progress → completed） |

サブエージェント（subagent）との最大の違いは、**チームメイト同士が直接メッセージをやり取りできる**点です。サブエージェントはメインエージェントへの報告のみですが、Agent Teams ではチームメイト間で発見を共有し、互いの結論を検証できます。

---

## 2. セットアップ手順

### 2.1 前提条件の確認

```bash
# Claude Code を最新版にアップデート
claude update

# バージョン確認（Agent Teams 対応版であること）
claude --version

# tmux のインストール（分割ペイン表示に必要）
sudo apt install tmux
```

> **注意**: 分割ペイン表示は tmux または iTerm2 が必要です。VS Code の統合ターミナルでは分割ペイン表示はサポートされていません。ただし、インプロセスモード（分割ペインなし）は VS Code 内でも動作します。

### 2.2 Agent Teams の有効化

以下のいずれかの方法で有効化します。

**方法A: settings.json に追記（推奨）**

`~/.claude/settings.json` を編集：

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**方法B: 環境変数で設定**

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

`.bashrc` や `.zshrc` に追記しておくと毎回設定する手間が省けます。

### 2.3 動作確認

```bash
# tmux セッションを起動してから Claude Code を開始
tmux
claude
```

プロンプトで以下の **📎 Claudeへの指示** を入力して、チームが生成されれば成功です。

> **📎 Claudeへの指示**
> ```
> Create a small agent team with 2 teammates to list the files in this project 
> and summarize the directory structure. One teammate lists files, 
> the other summarizes.
> ```
>
> **📎 和訳**
> ```
> 2人のチームメイトで小さなエージェントチームを作成してください。
> このプロジェクトのファイル一覧を取得し、ディレクトリ構成を要約してください。
> 1人がファイル一覧を担当し、もう1人が要約を担当します。
> ```

---

## 3. 業務ユースケース別ガイド

### 3.1 新機能・モジュールの並行開発

**狙い**: 機能を構成要素ごとに分割し、各チームメイトが担当領域を並行して実装する。

> **📎 Claudeへの指示**
> ```
> Create an agent team to implement the new user notification feature.
> Spawn 3 teammates:
> - API layer: Implement REST endpoints for notification CRUD 
>   in src/api/notifications/
> - Service layer: Implement business logic and event handling 
>   in src/services/notification/
> - Frontend: Implement notification UI components 
>   in src/components/notification/
> 
> Rules:
> - Each teammate owns ONLY their designated directory
> - Do NOT modify files outside your assigned directory
> - Use the shared interfaces defined in src/types/notification.ts
> - Write unit tests alongside implementation
> ```
>
> **📎 和訳**
> ```
> ユーザー通知機能を新規実装するエージェントチームを作成してください。
> 3人のチームメイトを生成してください：
> - API層: src/api/notifications/ に通知CRUDのRESTエンドポイントを実装
> - サービス層: src/services/notification/ にビジネスロジックとイベント処理を実装
> - フロントエンド: src/components/notification/ に通知UIコンポーネントを実装
> 
> ルール：
> - 各チームメイトは自分の担当ディレクトリのみを所有すること
> - 担当ディレクトリ外のファイルを変更しないこと
> - src/types/notification.ts に定義された共有インターフェースを使用すること
> - 実装と同時にユニットテストも作成すること
> ```

**ポイント**:

- **ディレクトリ単位で担当を明確に分離**する。複数のチームメイトが同一ファイルを編集すると衝突の原因になります
- 共有インターフェース（型定義、API仕様）は事前に用意しておく
- `CLAUDE.md` に共通のコーディング規約を書いておくと、全チームメイトが自動で読み込みます

### 3.2 テストコードの並行作成

**狙い**: テスト対象をモジュール別に分割し、並行してテストコードを生成する。

> **📎 Claudeへの指示**
> ```
> Create an agent team to write tests for the payment module.
> Spawn 3 teammates:
> - Unit tests: Write unit tests for src/services/payment/*.ts
>   Focus on edge cases, boundary values, and error handling.
>   Output to tests/unit/payment/
> - Integration tests: Write integration tests for 
>   src/api/payment/ endpoints. Test request/response flows 
>   and database interactions. Output to tests/integration/payment/
> - Mock/fixture setup: Create shared test fixtures, mock data, 
>   and test helpers in tests/helpers/payment/
> 
> Each teammate should:
> - Follow our existing test patterns in tests/unit/user/ as reference
> - Use vitest as the test framework
> - Aim for edge case coverage, not just happy path
> ```
>
> **📎 和訳**
> ```
> 決済モジュールのテストを作成するエージェントチームを作成してください。
> 3人のチームメイトを生成してください：
> - 単体テスト: src/services/payment/*.ts の単体テストを作成。
>   エッジケース、境界値、エラーハンドリングに重点を置くこと。
>   出力先は tests/unit/payment/
> - 結合テスト: src/api/payment/ エンドポイントの結合テストを作成。
>   リクエスト/レスポンスのフローとDB連携をテストすること。
>   出力先は tests/integration/payment/
> - モック/フィクスチャ作成: tests/helpers/payment/ に共有テストフィクスチャ、
>   モックデータ、テストヘルパーを作成
> 
> 各チームメイトの共通事項：
> - tests/unit/user/ の既存テストパターンをリファレンスとして参照すること
> - テストフレームワークは vitest を使用すること
> - 正常系だけでなくエッジケースのカバレッジを目指すこと
> ```

**ポイント**:

- テスト種別（単体・結合・ヘルパー）で分けるのが自然な分割
- 既存テストコードをリファレンスとして指定すると、プロジェクトの規約に沿ったテストが生成されやすい
- 出力先ディレクトリを明示して衝突を回避する

### 3.3 リファクタリング

**狙い**: 大規模なリファクタリングを安全に進めるため、分析・実装・検証を並行する。

> **📎 Claudeへの指示**
> ```
> Create an agent team to refactor the legacy order processing module.
> Spawn 3 teammates:
> - Analyst: Read src/legacy/order/ thoroughly. Document all 
>   public interfaces, dependencies, and side effects. 
>   Create a refactoring plan in docs/refactoring-order.md. 
>   Do NOT modify any source code.
> - Implementer: Wait for the analyst's plan, then refactor 
>   src/legacy/order/ following the plan. Ensure all existing 
>   tests still pass after changes.
> - Test guardian: Monitor changes made by the implementer. 
>   Run existing tests after each significant change. 
>   Add regression tests for any behavior that lacks test coverage.
>   Report any test failures immediately.
> 
> Use task dependencies:
> 1. Analyst completes analysis → Implementer begins refactoring
> 2. Implementer makes changes → Test guardian validates
> ```
>
> **📎 和訳**
> ```
> レガシーの注文処理モジュールをリファクタリングするエージェントチームを作成してください。
> 3人のチームメイトを生成してください：
> - 分析担当: src/legacy/order/ を徹底的に読み込み、
>   すべての公開インターフェース、依存関係、副作用を文書化すること。
>   docs/refactoring-order.md にリファクタリング計画を作成すること。
>   ソースコードは一切変更しないこと。
> - 実装担当: 分析担当の計画を待ち、計画に従って
>   src/legacy/order/ をリファクタリングすること。
>   変更後もすべての既存テストがパスすることを確認すること。
> - テスト監視担当: 実装担当の変更を監視すること。
>   重要な変更のたびに既存テストを実行すること。
>   テストカバレッジが不足している動作にはリグレッションテストを追加すること。
>   テスト失敗があれば即座に報告すること。
> 
> タスク依存関係を使用すること：
> 1. 分析担当の分析完了 → 実装担当がリファクタリング開始
> 2. 実装担当が変更 → テスト監視担当が検証
> ```

**ポイント**:

- リファクタリングでは「分析→実装→検証」のフェーズを**役割分担**するのが効果的
- タスク依存関係を使い、分析完了前に実装が始まらないようにする
- テスト担当を独立させることで、実装担当が「壊していないか」を常時監視できる

---

## 4. CLAUDE.md の設計（業務プロジェクト向け）

Agent Teams では、全チームメイトが作業ディレクトリの `CLAUDE.md` を自動で読み込みます。業務利用では以下の項目を記載しておくと品質が安定します。

```markdown
# CLAUDE.md

## プロジェクト概要
- [プロジェクト名と目的を簡潔に]

## コーディング規約
- 言語: TypeScript (strict mode)
- フォーマッタ: prettier
- リンター: eslint
- テストフレームワーク: vitest
- コミットメッセージ: Conventional Commits 準拠

## ディレクトリ構成
- src/api/       - REST API エンドポイント
- src/services/  - ビジネスロジック
- src/types/     - 型定義（共有インターフェース）
- tests/unit/    - 単体テスト
- tests/integration/ - 結合テスト

## 禁止事項
- node_modules/ 配下のファイルを直接編集しない
- .env ファイルをコミットしない
- 既存の public API のシグネチャを無断で変更しない

## テスト方針
- 新規コードにはユニットテストを必ず書く
- テスト実行: npm run test
- カバレッジ確認: npm run test:coverage
```

---

## 5. コスト管理とトークン消費

Agent Teams は**チームメイト数に比例してトークンを消費**します。業務利用ではコスト意識が重要です。

### 5.1 コスト感覚の目安

| 構成 | トークン消費イメージ |
|---|---|
| 単一セッション | 1x（ベースライン） |
| Lead + 2 Teammates | 約 3x |
| Lead + 4 Teammates | 約 5x |

> 実際の消費量はタスクの複雑さ、チームメイト間のメッセージ量、各チームメイトのコンテキスト使用量により変動します。

### 5.2 コストを抑えるための判断基準

| 状況 | 推奨 |
|---|---|
| 単一ファイルの修正、簡単なバグ修正 | 単一セッション |
| 1モジュール内のリファクタリング | 単一セッション or サブエージェント |
| 複数モジュールにまたがる並行作業 | **Agent Teams** |
| 複数観点での同時レビュー・分析 | **Agent Teams** |

### 5.3 チームメイトのモデル選択でコスト削減

チームメイトには Sonnet を指定することでコストを抑えられます。

> **📎 Claudeへの指示**
> ```
> Create an agent team with 3 teammates.
> Use Sonnet for each teammate.
> ```
>
> **📎 和訳**
> ```
> 3人のチームメイトでエージェントチームを作成してください。
> 各チームメイトには Sonnet を使用してください。
> ```

Lead は Opus、Teammates は Sonnet という組み合わせが、コストと品質のバランスが良い構成です。

---

## 6. 既知の制限事項と注意点

### 6.1 技術的な制限

| 制限 | 内容 |
|---|---|
| セッション再開 | チームのセッション再開には既知の制限あり |
| シャットダウン | チームメイトは現在のリクエスト/ツール呼び出しの完了を待ってから停止するため、時間がかかる場合がある |
| ファイル衝突 | 複数チームメイトによる同一ファイル編集は最大のリスク。担当ディレクトリの明確な分離が必須 |
| VS Code 統合ターミナル | 分割ペイン表示は非対応（インプロセスモードは動作） |

### 6.2 業務利用上の注意

- **実験的機能（Research Preview）** であることを認識しておく。本番コードへの直接適用前に必ずレビューする
- チームメイトの権限は Lead の設定を継承する。`--dangerously-skip-permissions` を使う場合は全チームメイトに伝播するため注意
- 機密性の高いコードベースで使用する場合、API 経由でコードが送信される点を情報セキュリティ方針と照合しておく

---

## 7. 運用設計 — TEAMCREATE / TASK によるタスク管理

### 7.1 ファイル構成

チーム作成指示と機能開発指示を分離し、機能単位で管理します。

```
.claude/
├── CLAUDE.md                       ← プロジェクト共通ルール（全チームメイトが自動読み込み）
├── teams/
│   ├── TEAMCREATE_AUTH.md          ← 認証機能のチーム構成指示
│   ├── TEAMCREATE_DASHBOARD.md     ← ダッシュボード機能のチーム構成指示
│   └── TEAMCREATE_TEMPLATE.md      ← テンプレート（コピー元）
└── tasks/
    ├── TASK01_LOGIN_FORM.md         ← ログインフォームの機能開発指示書
    ├── TASK02_AUTH_PROVIDER.md       ← 認証プロバイダの機能開発指示書
    └── TASK_TEMPLATE.md             ← テンプレート（コピー元）
```

### 7.2 ファイルの役割分担

| ファイル | 記載内容 | 誰が読むか |
|---|---|---|
| **CLAUDE.md** | コーディング規約、ディレクトリ構成、禁止事項 | 全チームメイト（自動） |
| **TEAMCREATE_XXX.md** | チーム構成、役割、Claude への指示文、タスク依存関係 | あなた（人間）→ Claude Code に貼る |
| **TASKXX_XXX.md** | 機能仕様、対象ファイル、バリデーション、API、テスト方針 | 開発者・テスタ（チームメイト） |

### 7.3 チーム構成（React / Next.js フロントエンド向け）

| 役割 | Agent Teams での位置づけ | 主な責務 |
|---|---|---|
| **PL（プロジェクトリーダ）** | Team Lead（Opus） | 計画承認、機能間の整合性確認、完了判定。自分ではコードを書かない |
| **開発者** | Teammate（Sonnet） | TASK.md に従って実装 + ユニットテスト作成 |
| **レビュア** | Teammate（Sonnet） | コード品質・規約準拠・a11y・パフォーマンスのレビュー。コードは変更しない |
| **テスタ** | Teammate（Sonnet） | 結合テスト + Playwright E2E テスト作成・実行。ソースコードは変更しない |

### 7.4 実行フロー

```
1. あなたが TEAMCREATE_XXX.md の「📎 Claudeへの指示」を Claude Code に貼る
    ↓
2. PL（Lead）がチームを生成し、各チームメイトに TASK.md を割り当てる
    ↓
3. 開発者が TASK.md を読み、実装計画を作成 → PL が承認 or 却下
    ↓
4. 開発者が実装 + ユニットテスト作成
    ↓
5. レビュアがコードレビュー → 指摘事項を開発者にフィードバック
    ↓
6. 開発者が修正 → レビュア再確認 → 承認
    ↓
7. テスタが結合テスト + Playwright E2E テスト作成・実行
    ↓
8. PL が全体確認、他機能との整合性チェック → 完了判定
```

### 7.5 テンプレート

TEAMCREATE と TASK のテンプレートを別ファイルとして提供しています。

- **TEAMCREATE_TEMPLATE.md** — チーム構成指示のテンプレート
- **TASK_TEMPLATE.md** — 機能開発指示書のテンプレート

新しい機能を開発する際は、テンプレートをコピーして `[機能名]` や `[対象ディレクトリ]` を書き換えてください。

### 7.6 運用のコツ

- **TASK.md は「何を作るか」に専念**する。「誰がどう進めるか」は TEAMCREATE に書く
- **1つの TEAMCREATE に複数の TASK を紐づけ可能**。認証機能なら TASK01（ログイン）、TASK02（登録）、TASK03（パスワードリセット）のように分ける
- **計画承認は必ず有効にする**。特に業務コードでは「Require plan approval」を省略しない
- **delegate モード（Shift+Tab）を活用する**。PL が自分でコードを書き始めてしまう場合に使う
- **レビュアの観点をカスタマイズ**する。プロジェクトに応じて TEAMCREATE 内のレビュー観点を追加・変更する

---

## 8. 検証ステップ（自分で試す手順）

まず以下の順序で段階的に検証することを推奨します。

### Step 1: 最小構成で動作確認

> **📎 Claudeへの指示**
> ```
> Create an agent team with 2 teammates to analyze this project.
> - Teammate A: List all source files and summarize the structure
> - Teammate B: Check for any TODO/FIXME comments and list them
> ```
>
> **📎 和訳**
> ```
> 2人のチームメイトでこのプロジェクトを分析するエージェントチームを作成してください。
> - チームメイトA: すべてのソースファイルを一覧表示し、構造を要約する
> - チームメイトB: TODO/FIXME コメントを確認して一覧にする
> ```

確認ポイント: チームが生成されるか、チームメイト間の通信が行われるか、結果が統合されるか。

### Step 2: テストコード生成で実用性検証

小規模なモジュールを対象に、テストコードの並行生成を試す。生成されたテストの品質・網羅性を確認する。

### Step 3: リファクタリングで信頼性検証

既存テストがあるモジュールを対象に、リファクタリングを実行。テストが全てパスすることを確認する。

### Step 4: 評価・判断

- 品質: 手動で書く場合と比較して実用レベルか
- コスト: トークン消費量は許容範囲か
- 効率: 並行化による時間短縮効果はあるか
- 安定性: エラーやハングは発生しないか

これらの結果をもとに、チーム展開の判断材料とする。

---

## 9. 参考リンク

- [Claude Code Agent Teams 公式ドキュメント](https://code.claude.com/docs/en/agent-teams)
- [Anthropic Engineering Blog: Building a C Compiler with Agent Teams](https://www.anthropic.com/engineering/building-c-compiler)

---

*本ガイドは Agent Teams のリサーチプレビュー段階（2026年2月時点）の情報に基づいています。機能の仕様は今後変更される可能性があります。*
