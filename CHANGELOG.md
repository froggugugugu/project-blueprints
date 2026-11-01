# Changelog

All notable changes to this project will be documented in this file.

このプロジェクトの注目すべき変更を記録する。日英バイリンガル(同一構造)。
形式は [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) に準拠し、
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) を採用。

## [Unreleased]

### Added (運用面の強化: 配布と更新 / 検証の実測 / サプライチェーン / 観測, 2026-11-01)

- **`setup.sh --upgrade [--dry-run]`(JP/EN)**: 導入時に `.claude/blueprint-manifest.txt`(版・プロファイル・ファイルごとの SHA-256)を記録し、
  テンプレート更新時は未変更のファイルだけ上書き、手で変えたファイルは `<path>.blueprint-new` を横に置いて報告、テンプレートに増えたファイルは
  追加(プロファイルの剪定は維持)、`project-config.md` / `docs/` / `input/` / `output/` / `settings.local.json` は触らない。
  `scripts/test_setup.sh`(`validate-harness.sh --setup`、96 ケース)が導入 / プロファイル / 更新 / 競合 / 冪等性 / manifest 不在を検証。
- **`scripts/run_skill_evals.py`**: skill の `evals/evals.json` を `setup.sh` で作った使い捨てプロジェクトで headless 実行(skill あり / なし、
  許可リスト + `dontAsk`、Stream JSON から Skill 発動を検出)し、ツール無しの別 `claude -p` が assertion ごとに採点、`evals/baseline/latest.json`
  との比較で劣化を検出(exit 1)。`evals/fixtures/ja/`(§1〜§3 を埋めた project-config、PRD / TASK / レビュー対象コードの seed)。
  `.github/workflows/skill-evals.yml`(週 1 + 手動。リポジトリ変数 `SKILL_EVALS_ENABLED` と `ANTHROPIC_API_KEY` でゲート、artifact に保存)。
- **`.claude/scripts/harness-stats.sh`(JP/EN)**: 観測フックの `testreport/` JSONL(拒否・失敗・設定変更・rule の load・subagent 起動)を
  1 枚の Markdown(`--json` で機械可読)に集計。`/harness-refine` Round 0 と guardrails「コントロールの棚卸し」の実測値。`--hooks` 152 → 168 件。
- **`VERSION` + `scripts/release.sh`(prepare / publish)**: VERSION と CHANGELOG の最新リリース見出しの整合を validator が検査(`--test` 53 → 56)。
- **`SECURITY.md`**(対象・報告経路・サポート版・防御モデル、JP + EN)、`.github/CODEOWNERS`、`.github/dependabot.yml`(Actions の更新)。
  GitHub 側: main の branch protection(`validate` 必須、force push / 削除禁止、管理者にも適用)と Private vulnerability reporting を有効化。

### Changed (2026-11-01)

- **`.mcp.json.template`(JP/EN)**: 全 npx パッケージを `name@x.y.z` で固定(context7 4.4.4 / playwright 0.0.84 / filesystem 2.1.0 /
  sentry 0.42.0 / brave-search 2.1.4)。deprecated の `server-postgres` → `@bytebase/dbhub@1.5.0 --readonly`(SELECT 専用ロール併用を注記)、
  `server-slack` → Slack 公式リモート MCP(`https://mcp.slack.com/mcp`)。validator は有効サーバーの未固定を ERROR、例示ブロックの
  未固定(範囲指定含む)を WARN にし、`--online` 無しでも検査する。
- **README(JP/EN)**: 前提条件(Claude Code 2.1.314 以上 / bash / git / jq)、`--upgrade` の手順、プロファイル表の agent 9 / hook 18 への修正。
  ルート README に「バージョンと更新」「計測」節。
- **guardrails.md / `/harness-refine` Round 0(JP/EN)**: 棚卸しの集計を `harness-stats.sh` に。

## [0.4.0] — 2026-11-01

Claude 5 系対応と公式仕様 2.1.283〜2.1.316 への追従をまとめたリリース。フック 18 本 / 登録 27、agent 9、skill 17、
フェイルクローズ、`verifier` agent、`config-guard.sh`、`AGENTS.md` 分離、検証ゲート(`--test` 53 / `--hooks` 152)を含む。
0.3.0 以降の Unreleased を全て含む(PR #16〜#28)。

### Added (公式仕様 2.1.283〜2.1.316 とハーネス工学の知見の取り込み, 2026-10-26 / 10-31)

- **フック 6 イベントを追加(JP/EN、settings 登録 20 → 27、スクリプト 17 → 18)**:
  `UserPromptExpansion`(`scan-harness.sh` — `/skill` の直接入力は PreToolUse(Skill) を通らないため、同じ判定を展開前に掛ける)/
  `FileChanged`(`scan-harness.sh filechanged` — `sed -i` や外部エディタによる `constitution.md` の改変をファイル監視で検知し `testreport/config-changes/` に記録)/
  `StopFailure`(`post-failure-log.sh` が `tool=api:<error>` で記録、`notify-claude.sh failure` が通知)/
  `TeammateIdle`(`verify-gate.sh teammate` — agent teams の teammate の手待ちにも検証ゲート)/
  `PermissionRequest`(`permission-denied-log.sh request` — 無人実行で止まった呼び出しを `kind=request` で記録)/
  `InstructionsLoaded`(新規 `instructions-log.sh` — CLAUDE.md / rules の load 実績を `testreport/instructions/` に記録。rule 棚卸しの実測値)。
- **フェイルクローズ**: ブロック系 4 本(`safety-check.sh` / `protect-files.sh` / `config-guard.sh` / agent frontmatter の `scope-guard.sh`)に
  `onFailure: "block"`(v2.1.295)。フックが起動できない・タイムアウトしたときに操作が素通りしなくなった。
  `validate_harness.py` が欠落を WARN し、`onFailure` の値(continue / block)と型(command / http 限定)、`FileChanged` matcher の正規表現混入を検査。
- **`.claude/agents/verifier.md`(JP/EN、agent 8 → 9)**: 完了直前に 1 回だけ差分を受け入れ条件・検証結果と照合する読取専用の第三者レビュー
  (公式 best-practices の adversarial review step。`memory` を持たず判定を持ち越さない)。`/implementing-features` の手順 6、
  TEAM_PJM / TEAM_FEATURE のレビュアー、teams/README の dispatch 表、`project-config.md` §13.4、CLAUDE.md のサブエージェント戦略に組み込み。
- **`settings.json` の `isolatePeerMachines: true`(JP/EN)**: 他マシンのセッションへメッセージを送る前に必ず確認(cross-session messaging)。
  `managed-settings.example.json` に `crossSessionInbound` と `SendMessage` / `ListAgents` の deny の案内。
- **`guardrails.md`**: 「フェイルクローズ(`onFailure: block`)」「コントロールの棚卸し(harness rot 対策)」節、idle compaction・セッション間メッセージ・
  OTel `claude_code.safety_event`・agent memory のレビュー対象化の注記。**`pitfalls.md` #37〜#39**(`/skill` 直接入力の抜け道 / プロンプトキャッシュを
  無効化する操作 / フックの fail-open)。
- **`validate-harness.sh --test` 47 → 52 件 / `--hooks` 106 → 150 件**(UserPromptExpansion の must-block / must-allow、FileChanged の一致 / 不一致、
  teammate、StopFailure、request、instructions-log)。
- **作業ディレクトリ外への書込拒否(v2.1.314)**: `permissions.blockWritesOutsideWorkingDirectories` を `managed-settings.example.json`
  (`requiredMinimumVersion` 2.1.314)と `settings.local.json.template` の `_comment_working_dir_fence`(opt-in)、`guardrails.md` の Layer 2、
  `permissions-guide.md` に追加。`validate_harness.py` は `permissions` の未知キー(黙って無視される)を ERROR にし、`--test` 52 → 53 件。
- **`config-guard.sh`(JP/EN)**: `safety-check.sh` / `protect-files.sh` の登録から `onFailure: block` が消える変更(フェイルオープン化)もブロック。`--hooks` 150 → 152 件。
- **`project-config.md` §13.1b(JP/EN)**: effort の動かし方の表(`high` / `xhigh`・`low`・`max`・`ultrathink`(v2.1.311 で `xhigh`)・
  `CLAUDE_CODE_SUBAGENT_EFFORT`(v2.1.316))。

### Changed (公式仕様 2.1.283〜2.1.316 とハーネス工学の知見の取り込み, 2026-10-26 / 10-31)

- **auto mode の既定**: v2.1.283 以降は全プラン・全プロバイダで既定の権限モードになったため、「Pro / Max / Team の既定」という記述を
  CLAUDE.md / pitfalls #23 / settings.local.json.template / permission-denied-log.sh で更新。README のクイックスタートに `/auto-mode-setup` を追加。
- **`project-config.md` §13(JP/EN)**: 固定 ID を Sonnet 5.5(`claude-sonnet-5-5`)/ Haiku 5.5(`claude-haiku-5-5`)に更新。§13.1c advisor(上位モデルへの相談)、
  Sonnet 5.5 の `low` effort は検証せず完了報告しがちという注意、§13.5「セッション途中でモデルを切り替えない(キャッシュ無効化)」を追加。
- **`harness-authoring.md`(JP/EN)**: 規則には理由を添える / 絶対規則は安全と不可逆操作に限り、他は望ましい状態を記述する(Claude 5 系の公式ガイダンス:
  rules から judgement へ)/ skill 編集後の `/skill-doctor`、モデル更新時の `/doctor prompt-audit` / ブロック系フックの `onFailure: block` /
  `UserPromptExpansion` への二重登録。
- **`/harness-refine` Round 0(JP/EN)**: `/doctor prompt-audit` と「コントロールの棚卸し」(`testreport/instructions|denials|failures|config-changes` の集計)を追加。
- **`permission-denied-log.sh` / `post-failure-log.sh` / `verify-gate.sh` / `scan-harness.sh` / `notify-claude.sh`(JP/EN)**: 上記イベントに対応するモード引数を追加。
  既存の挙動(PermissionDenied / PostToolUseFailure / Stop・TaskCompleted / PreToolUse(Skill) / stop・notify)は変えていない。
- **OTel の記述(`guardrails.md`)**: `claude_code.safety_event` は v2.1.312 で送信停止。フリート集計は `claude_code.tool_decision` と `testreport/` の JSONL に改めた。
- **effort の既定値(`project-config.md` §13.1)**: Opus 5.5 / Sonnet 5.5 / Haiku 5.5 が `medium`、他は `high`(公式)。§13.1c advisor を §13.1b の後ろへ移動。
- **コントロールの棚卸し(`guardrails.md` / `harness-authoring.md`)**: 公式の「好みを符号化したフックは消す・強制は少数に保つ」を追記。
  `guardrails.md` の 3 層防御図の Layer 1 を 27 登録に合わせ、検証ゲートに `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` を追記。
- **`/harness-refine`(JP/EN)**: Round 0 の棚卸しに `/usage`。基準ソースを `changelog` 主軸(`whats-new` は補助)、`.md` 直接取得、anthropic.com/research に更新。
- **`claude-review.yml.template`(JP/EN)**: `--model claude-sonnet-5` → `claude-sonnet-5-5`。
- **`settings.local.json.template` / `managed-settings.example.json`(JP/EN)**: autoMode の各リストに `"$defaults"` を残す注意、`/fewer-permission-prompts`、
  `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`、`CLAUDE_CODE_SUBAGENT_EFFORT` の案内。

### Added (Claude 5 系対応 + 公式仕様の総点検, 2026-09-26)

- **`.claude/hooks/config-guard.sh`(JP/EN)**: `ConfigChange` フック。セッション中の設定変更を
  `testreport/config-changes/` に記録し、`disableAllHooks: true`・`settings.local.json` の `permissions.deny`・
  `.claude/settings.json` からの Layer 1 ブロック系フック(`safety-check.sh` / `protect-files.sh`)の削除は
  exit 2 でセッションへの適用を止める(constitution ⑤ の機械強制。公式 security docs の推奨)。フック 17 本 / 登録 20。
- **`REVIEW.md`(JP/EN、`setup.sh` が配置)**: Claude の Code Review(GitHub App)が読むレビュー専用の基準。
  Important の定義・Nit 上限・報告しない領域(`output/` `testreport/` 生成物)・常に確認する項目・根拠の基準・再レビューの収束・要約の形。
  ローカルの `/code-review` はこのファイルを読まないことも明記。
- **`.claude/loop.md`(JP/EN)**: 引数なし `/loop` の既定プロンプト。未完了作業 → PROGRESS.md の次の一手 → PR の CI /
  レビュー対応 → `/code-review` の順で 1 反復だけ進め、不可逆操作と未検証の完了報告を禁じる。validator が 25,000 文字上限を検査。
- **`settings.json` の `env`(JP/EN)**: `CLAUDE_CODE_ENABLE_TODO_TOOLS=1`(Task ツールは Sonnet 5 / Opus 5.5 / Fable では
  既定で無く、`TaskCompleted` ゲートと team のタスク追跡が一度も動いていなかった)と
  `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`(agent の入れ子禁止 = constitution ④ を設定で強制)。
- **`validate_harness.py`**: hook の `if`(ツール系 5 イベント限定・`&&`/`||` 不可)、`PermissionRequest` の agent 型禁止、
  権限ルールの閉じ括弧後テキスト(v2.1.260)、`Bash(cmd * sub)` のワイルドカード位置(v2.1.246)、project / local settings で
  無視されるキー(`pluginConfigs` / `remoteControlAtStartup` / `sandbox.ripgrep` / OTel と一時ディレクトリの `env`)、
  `enabledPlugins` の marketplace 実在(ローカルキャッシュがあるとき)、予約名前空間 `anthropic-skills` / `claude-ai`、
  agent の `omitClaudeMd` / `background` / `experimental.cacheTtl`、`.claude/loop.md` の上限を検査。負のテストは 47 件、
  フック機能テストは 106 件(config-guard 8 + SessionStart compact 3)。
- **`pitfalls.md` #32〜#36(JP/EN)**: Task ツール不在で TaskCompleted が発火しない / project settings の OTel 変数は無視 /
  存在しないプラグインは黙って無視 / Claude 5 系で逆効果になる指示(過剰検証・過剰委譲・保守的レビュー・思考の開示)/
  フックの `if` は安全装置にならない。

### Changed (Claude 5 系対応 + 公式仕様の総点検, 2026-09-26)

- **コンパクト後の再注入を公式パターンへ**: `session-start.sh` が `source == "compact"` で中核ルールと PROGRESS.md を
  圧縮直後に注入する(SessionStart の `compact` matcher)。`post-compact-restore.sh` は要約保全だけ、`user-prompt-submit.sh` は
  プロンプト検査だけになり、マーカー(`testreport/.post-compact-pending`)経由の 2 段構えを廃止した。旧方式は次のユーザー
  プロンプトまで再注入が遅れ、自動コンパクト後に Claude が続行する間は無防備だった。
- **`commit-quality.sh` の登録に `"if": "Bash(git commit *)"`**: git commit のときだけプロセスを起動する。
- **`enabledPlugins` から `draw.io@claude-plugins-official` を削除(JP/EN)**: 公式 marketplace(311 プラグイン)に存在せず、
  起動時に黙って無視されていた。`CLAUDE.md` / `phase-design` / `project-config.md` §12 の draw.io 参照は mermaid に置換。
- **`claude-review.yml.template`(JP/EN)**: beta 時代の `model` / `max_turns` / `direct_prompt` 入力を v1 の
  `prompt` + `claude_args`(`--model claude-sonnet-5 --max-turns 10`)に修正し、`id-token: write` / `actions: read` を追加。
  `CLAUDE_REVIEW_SETUP.md` も追随。`claude-skills-ci.yml.template` に `--max-budget-usd` / `--no-session-persistence`、
  `claude-scheduled-audit.yml.template` に既定ブランチ限定・60 日無活動での無効化・`allowed_bots` の注記。
- **Claude 5 系のプロンプティングガイドを反映**: `CLAUDE.md` の subagent 戦略を「独立・並列・隔離が要るときだけ委譲、
  数回のツール呼び出しで済む作業は自分で」に改め、レビュー subagent には全件報告→MUST だけ対応。`code-review` skill から
  「gap に限定」を外して全件列挙→重要度で絞る方針にし、「大したことはない」と自己却下しない規則を追加。`AGENTS.md` に
  「問題の説明・質問には評価だけを返し、修正は依頼されてから」を追加。`harness-authoring.md` に「最重要指示を冒頭に(コンパクト後
  5,000 トークンで切り詰め)」「慎重に考えろ・推論を示せ・念のため再確認を書かない」「回帰 eval と能力 eval の区別」
  「`paths:` 付き rule はコンパクトで消える」「hooks の `if`」を追加。`CLAUDE.md` の Compact instructions にユーザーの制約(原文)と
  行き詰まり・回避策を追加。
- **`project-config.md` §13.1(JP/EN)**: Frontier tier `fable`(`claude-fable-5-1`)を追加、`opus` の固定 ID を
  `claude-opus-5-5` に更新、Opus 5.5 の既定 effort が `medium` である注記を追加。§12 のツール表は draw.io → mermaid。
- **`explorer` agent に `omitClaudeMd: true`**: 読取専用で CLAUDE.md の規則を要さないため、起動ごとの
  CLAUDE.md + AGENTS.md(200 行)の読込を省く。`agents/README.md` に `omitClaudeMd` / `background` / `mcpServers` /
  `experimental.cacheTtl`、入れ子の既定(3 階層・同時 20)、委譲の判断、fork、出力スキャンの節を追加。
- **`managed-settings.example.json`(JP/EN)**: `sandbox.credentials`(`~/.aws/credentials` / `~/.ssh` / `GITHUB_TOKEN` /
  `NPM_TOKEN` を deny。認証情報に組み込みの deny リストは無い)、`failIfUnavailable: true` / `allowUnsandboxedCommands: false`
  (公式の組織向け推奨)、`permissions.blockReadsOutsideWorkingDirectories: true`、`requiredMinimumVersion: 2.1.277`。
- **`settings.local.json.template`(JP/EN)**: OTel 変数は project / local settings では無視される(v2.1.282)ため
  `_comment_telemetry` を訂正、任意の公式プラグイン一覧(`_comment_plugins`)、`sandbox.credentials` の例、
  `Workflow(review-sweep)` / `Workflow(skill-eval)` の allow、フック profile 一覧に `config-guard`。
- **`.mcp.json.template`(JP/EN)**: `@upstash/context7-mcp@4.1.1` / `@playwright/mcp@0.0.82` に更新し、context7 プラグイン
  (リモート MCP)有効時は stdio 版を削除する注記を追加。
- **`guardrails.md` / `permissions-guide.md` / `teams/README.md` / `workflow-advanced.md` / `quality-gates.md` /
  `harness-refine`(JP/EN)**: フック表 17 本、ConfigChange の decision 可否、`if` の限定、Routines の最小間隔 1 時間と権限
  プロンプト無し、サーバー側分類器の既定化(v2.1.278)、`--permission-prompts none`、Task ツールの有効化、workflow の
  規模目安と `Workflow(<名前>)`、進捗報告はツール結果に根拠のあるものだけ、判定の種類(コード / モデル / 人間)、
  基準ソースに Claude 5 系プロンプティングガイドと `tools-reference` / `changelog` を追加。`prd` テンプレートの受け入れ基準に
  EARS 形式を推奨。

### Changed (constitution ⑥, 2026-09-23)

- **`constitution.md` ⑥(root / JP / EN)**: 行数上限の対象を「CLAUDE.md」から「常時 load する指示
  (CLAUDE.md + AGENTS.md)の合計」に改めた。Claude Code は `@AGENTS.md` で取り込んだ内容も毎セッション全文読むため、
  片方へ移すだけでは削減にならない。判定の「`@import` で参照に置換」は、import が context を減らさない事実
  (`harness-authoring.md`)と矛盾していたため「パスと読む条件で参照」に訂正。関連ドキュメントに `AGENTS.md` を追加。
  変更プロトコルに従い `.claude/.constitution.sha256`(JP/EN)を同じ PR で再計算。

### Added (AGENTS.md for non-Claude agents, 2026-09-23)

- **`project-config.md` §13.7 マルチ LLM 併用(JP/EN)**: 主系は Claude Code に固定し、Codex / Cursor / Copilot /
  Gemini CLI の利用可否・役割・書込範囲・`AGENTS.md` の読ませ方を人間が決める表と併用ルールを追加。
  `AGENTS.md` は他エージェントに §13.7 への従属を求め、`yes` でなければ読取専用で振る舞わせる。

- **`AGENTS.md`(JP/EN)**: ツール非依存の開発ルール(原則・ドキュメント管理・品質基準・実装ワークフロー・
  Git・セキュリティ規則)を `.claude/CLAUDE.md` から切り出した。Codex / Cursor / Copilot / Gemini CLI などは直接読み、
  Claude Code は `CLAUDE.md` 冒頭の `@AGENTS.md` で取り込む。`CLAUDE.md` には skill・team・subagent・フック・権限など
  Claude Code 固有の仕組みだけを残した(2 ファイル合計で従来と同じ 200 行)。
- **`setup.sh`**: `AGENTS.md` をプロジェクトルートに配置する。既存の `AGENTS.md` は上書きせず、テンプレート版を
  `AGENTS.blueprint.md` として横に置いて統合を促す。
- **`validate_harness.py`**: `CLAUDE.md` が `@AGENTS.md` を取り込んでいること、`AGENTS.md` に行頭 `@` が無いこと
  (他ツールは import を解釈しない)、両ファイルが引く `project-config.md` の §番号が実在することを検査し、
  行数の上限は 2 ファイルの合計で判定する。負のテストは 39 件。
- **`scan-harness.sh`**: secret 検査の対象にルートの `CLAUDE.md` / `AGENTS.md` を追加(フックテスト 84 件)。

### Changed (AGENTS.md split follow-ups, 2026-09-23)

- **安全に関わる禁止事項は `CLAUDE.md` 本体にも置く**: auto mode の分類器が `@import` 先を読むかは公式に記載が無いため、
  `--no-verify` / `--force` 付きの push の禁止を `CLAUDE.md` に残し、`harness-authoring.md` / `permissions-guide.md` /
  `pitfalls.md` #23 / `settings.local.json.template` にその理由を記載。
- **移動した節への参照を更新**: `code-review` / `implementing-features` / `review-fix` ほか 4 skill、`doc-writer` /
  `doc-synchronizer`、6 team、`guardrails.md`、`learnings/README.md`、`pitfalls.md`、`claude-review.yml.template` が
  `AGENTS.md` の該当節を指すようにした。`/harness-refine` の採点も 2 ファイル合計に揃えた。
- **`setup.sh` の再実行**: テンプレートと同一の `AGENTS.md` は保持し、`AGENTS.blueprint.md` を作らない。
- **対応ツールの記述**: 既定で `AGENTS.md` を読むのは Codex / Cursor。Copilot(VS Code)と Gemini CLI は設定が要る。

### Added (template extraction / eval runner / new official behaviors, 2026-09-19)

- **`workflows/skill-eval.js`**: `evals/evals.json` を skill あり / なしの 2 系統で実行し、実行していない
  agent が assertions を判定して pass rate を比較する saved workflow。出力は
  `testreport/evals/<skill>/iteration-N/`。skill の description と本文の寄与を数値で確認できる。
- **`permissions-guide.md` の制限モード節**: `claude --restricted`(v2.1.248 以降)はコマンド実行系ツールと
  `WebFetch` を既定から外し、ファイル操作を working directory に限定し、managed settings と `--settings`
  だけを読む。`bypassPermissions` は拒否され、auto mode の分類器も保護パスへの書込を承認できない。
- **`pitfalls.md` #31**: `CLAUDE.md` があると `AGENTS.md` は読まれない。`setup.sh` は既存の `AGENTS.md` を
  検出したら `@AGENTS.md` を import する手順を警告として表示する。
- **`validate_harness.py`**: 参照ファイルが SKILL.md からリンクされているか、`references/` へのリンクが
  実在するか、本文が 300 行を超えていないかを検査。負のテストは 35 件。

### Changed

- **13 skill × JP/EN の出力テンプレート**: SKILL.md に埋め込まれていた雛形(最大 122 行)を
  `references/*.md` へ逐語で移設し、本文からはパスと読む条件のリンクで参照する。
  skill 起動時に読まれる本文は JP 4,091 → 3,344 行(172→153KB)、EN 4,107 → 3,360 行(154→137KB)。
  最長 skill は 349 行から 281 行になった。100 行超の参照ファイル 4 本には目次を追加。
- **SKILL.md の参照表記 16 か所**: コードスパンから markdown リンクに変換し、SKILL.md から 1 階層で
  辿れる状態にした(公式の progressive disclosure パターン)。

### Added (authoring conventions / skill evals / write-scope enforcement, 2026-09-12)

- **`skills/*/evals/evals.json`(17 skill × JP/EN)**: agentskills.io 形式の eval。各 skill に典型と境界の
  2 ケースと、出力契約から導いた検証可能な assertions(1 ミラーあたり 34 ケース / 128 assertions)。
  skill-creator プラグインで skill あり / なしを比較して回す。
- **`hooks/scope-guard.sh`**: 書込可能な subagent の frontmatter `hooks.PreToolUse` に登録し、
  範囲外の Edit / Write を exit 2 で止める(doc-synchronizer=docs / doc-writer=output / test-writer=tests)。
- **`rules/harness-authoring.md`**(path-scoped): CLAUDE.md・skill・agent・workflow の執筆規約。
  Markdown の書き方、置き場所の判断、description の型、行頭 `@` の禁止、参照ファイルの目次、eval-first。
- **`workflows/review-sweep.js`**(full プロファイル): 差分を 4 観点で並列レビューし、MUST 指摘を
  3 票の反証で検証してから 1 本のレポートにまとめる saved dynamic workflow(team 層)。
- **`pitfalls.md` #28〜#30**: skill の行頭 `@` 添付 / skill 一覧予算 1% / acceptEdits agent の範囲外書込。
- **`validate_harness.py`**: skill の行頭 `@`、description 上限(1024)と人称、日付記述、参照ファイルの
  目次と入れ子、evals スキーマ、agent / skill frontmatter hooks、書込 agent の scope-guard 有無、
  workflow の meta リテラル・phase 整合・非決定 API・構文を検査。負のテスト 32 件、フック機能テスト 80 件。

### Fixed

- **skill の「関連参照」ブロック(15 skill × JP/EN)**: 行頭 `@path` はローカル skill では起動時に
  ファイル全文が添付される(公式 skills 仕様)。見出しの「必要に応じて load」と実挙動が逆で、
  17 skill 合計 JP 357KB / EN 322KB を起動のたびに添付しうる状態だった。「パス — 読む条件」の箇条書きに変換。
- **skill description(17 × JP/EN)**: 制約文と引数説明を除き「何をするか + いつ使うか」に統一
  (JP 6,577→2,037 字 / EN 7,080→4,192 字)。一覧予算(context の 1%)超過による説明の欠落を防ぐ。
- **`.claude/CLAUDE.md`**: agents/README.md の常時 import を廃止し、`@import` で自動 load される前提の
  記述を訂正(常時 load JP 24.0→14.8KB / EN 21.7→13.4KB)。
- **`teams/TEAM_*.md`**: 本文の `@` 行は Read では展開されないため、「起動時に Read する」指示に変換。
- **`setup.sh` / `.gitignore`**: full 以外のプロファイルで workflows を剪定し、skill-creator の
  作業ディレクトリ `.claude/skills/*-workspace/` を除外。

### Added (official best-practice alignment, 2026-09)

- **`verify-gate.sh`**(PostToolUse + Stop): 公式「Claude に検証手段を与え Stop フックで
  決定論的にゲートする」の実装。ソース編集後に検証コマンド(テスト / lint / 型チェック /
  ビルド)が走らずに終了しようとすると standard=警告 / strict=1 回差し戻し。
  `stop_hook_active` と `background_tasks` を尊重しループしない。
- **`permission-denied-log.sh`**(PermissionDenied): auto mode(Pro / Max / Team の既定)の
  分類器による拒否を `testreport/denials/` に記録し、allow ルール / `/auto-mode-setup` の
  改善入力にする。
- **`.claude/tasks/PROGRESS_TEMPLATE.md`** + `session-start.sh` の自動注入: Anthropic の
  長時間エージェント運用知見(進捗ノート / 機能リスト / 1 セッション 1 機能 / スモークテスト)。
- **`CLAUDE.md`**: 証拠ルール(証拠のない完了報告禁止)、`Compact instructions` 節、bundled
  skill(`/verify` `/btw` `/goal` `/batch`)連携、auto mode での deny / ask の位置づけ、
  長期タスク引き継ぎ。199 行(目安 200 行以内を維持)。
- **`pitfalls.md` #23〜#27**: auto mode / CLAUDE.md 途中編集無効 / project settings で無視される
  `defaultMode: auto` `autoMode` / bundled skill の同名上書き / Stop フックの 8 回上限。
- **`validate_harness.py`**: `PreModelSwitch` / `PostModelSwitch`、hook handler の `type` /
  `prompt` / boolean / `timeout` 検証、project settings の `defaultMode: auto` / `autoMode`
  警告、`disable-model-invocation` / `user-invocable` の厳密値、output style の
  `keep-coding-instructions` 警告。負のテスト +5(22/22)。

- **`scripts/test_hooks.sh`**(`validate-harness.sh --hooks`): 全フックに hook JSON を流して
  exit code / 出力を検証する機能テスト 54 ケース(JP/EN 両ミラー)。CI に組み込み。
- **`verify-gate.sh task`**(TaskCompleted): 検証コマンド未実行のタスク完了マークを
  standard=警告 / strict=exit 2 で差し止め(品質ゲート③の機械強制)。
- **`.claude/managed-settings.example.json`**: 組織ポリシー例(deny / sandbox / OpenTelemetry /
  `requiredMinimumVersion`)。`settings.local.json.template` に OTel と `modelPricing` の指針を追加。
- **`rules/README.md`**: monorepo 指針(per-directory skill / `claudeMdExcludes` /
  `worktree.sparsePaths` / `skillOverrides`)。
- **`/plan` / `/implementing-features`**: PROGRESS.md の機能リスト初期化と `passes` /
  セッションログ更新を手順化(複数セッション引き継ぎの自動化)。
- **`session-start.sh`**: 常時 `@import` される `docs/*.md` が 300 行を超えたら切り出しを警告。
- **`setup.sh`**: `settings.local.json` を雛形から自動生成。

### Changed

- **`.mcp.json.template`**: 有効サーバーをバージョン固定(`@upstash/context7-mcp@4.0.5` /
  `@playwright/mcp@0.0.80`)。validator `--online` が固定版の解決を検証し、未固定を WARN。
- **output styles(4 × JP/EN)**: `keep-coding-instructions: true` を追加。これまでは
  Claude Code 標準のソフトウェアエンジニアリング指示(検証習慣・変更スコープ)を丸ごと
  落としていた(公式 output-styles 仕様)。
- **`pitfalls.md` #2**: 「subagent は親の skill / rules を継承しない」は公式仕様と矛盾。
  CLAUDE.md 階層 / `.claude/rules/` / git status は継承し、継承しないのは skill 本文・
  会話履歴・auto memory に訂正。
- **`permissions-guide.md`**: auto mode 既定化(v2.1.228+)、評価順序
  (deny → ask → 分類器 → フック)、設定の置き場所表、拒否ログ活用を反映して全面改訂。
- **`review-fix` / `harness-refine`**: `disable-model-invocation: true`(副作用のある
  ワークフローは手動起動のみ)。
- **`code-review`**: 「正確性・要件に影響する gap のみ報告」原則、bundled `/review` との関係。
- **`agents/README.md`**: fork mode 既定 ON / 背景実行、継承範囲、ネスト禁止(constitution ④)、
  description 予算、`Agent(param:value)`、`agent-memory` の保存先。
- **`guardrails.md`**: フック一覧 15 スクリプト / 18 登録、検証ゲート節、`if` / `once` /
  `asyncRewake`、`agent` 型、`PreModelSwitch`。
- **`.gitignore` / `setup.sh`**: `.claude/worktrees/` / `.claude/agent-memory-local/` /
  `.claude/settings.local.json` を除外対象に追加。

### Removed

- **`.claude-plugin/marketplace.json`**: プラグインマーケットプレイス配布を見送り削除。
  本リポジトリは clone-and-use ハーネス(`setup.sh` でターゲットへ配置)を主経路とする。
  理由: skill が namespace 化(`/project-blueprint-ja:prd`)されると skill/team 内部の
  bare スラッシュ相互参照が崩れ、プラグイン単体では `project-config.md` /
  `input` / `output` / `docs` が scaffold されないため(0.3.0 の plugin 対応化を撤回)。

### Fixed (hook robustness + doc consistency)

- **`commit-quality.sh`**: `git diff HEAD~1..HEAD` は初回コミットで失敗する。
  `git show HEAD` に変更（全コミットで動作）。
- **`notify-claude.sh`**: `--wait` 引数末尾で `$2` が `set -u` 下で未定義エラー。
  `${2:-}` に変更。
- **`protect-files.sh`**: `/\.git/` パターンは `.git/` 直下ファイルを保護できない
  (`path = ".git/config"` 形式で不一致)。`(^|/)\.git(/|$)` に修正。
- **`safety-check.sh`**: jq 不在時の sed フォールバックを削除（誤検知リスク大）。
  fail-open に変更。`git push --force` / `git clean -f` の固定文字列マッチを
  正規表現に移行（フラグ順バイパスを防止）。
- **`scan-harness.sh`**: jq 不在時 SKILL 名が空になり deploy ブロックが無効化。
  sed フォールバックを追加。`permissions.deny: []`（空配列）が `length > 0` を
  通過してしまう問題を `getpath != null` チェックに変更。
- **`guardrails.md`**: `UserPromptSubmit` フックは `exit 0 + stdout JSON` で
  差し戻す（`exit 2` ではない）仕様を明記。
- **`doc-synchronizer.md`**: "docs/*.md のみ書込可" とありながら下方では
  `project-config.md` §2/§3/§11 も更新可と矛盾。行 43 を整合させた。
- **`performance/SKILL.md`**: レポート出力先が `testreport/` 契約と矛盾。
  計測ツール生データを `testreport/perf/` に保存する旨を明記。
- **`TEAM_PLANNING.md`**: プランナーの出力が `PLAN_<名>.md` だが
  `TEAM_FEATURE.md` は `TASK_<名>.md` を参照。`TASK_<名>.md` に統一。
- **`planner.md`**: リスク・前提セクションに `【仮定】` ラベルを追加
  (`CLAUDE.md` の `【仮定】` 明示規約と整合)。
- **`phase-prd.md`**: `AskUserQuestion` に "Claude Code 組み込みツール" の
  説明を追記（cross-reference 欠落）。
- **`.mcp.json.template`**: `@modelcontextprotocol/server-fetch` が廃止予定。
  active セクションから除去し optional に移動して廃止警告を追加。
  `filesystem` / `github` に `npm show` 確認コマンドの注記を追加。

### Changed

- **README / README-en「いま入っているもの」**: 実数に合わせ skills 16→17
  (`/harness-refine` 追加)、agents 6→8(`researcher` / `doc-writer` 追加)に修正。
  非準拠で誤解を招く `1 plugin` 行を削除。
- **`CLAUDE.md`**: skill 数記述を 17 skills に統一(`/harness-refine` を補助 skill に追記)。

## [0.3.0] — 2026-04-27

Major self-enhancement release adopting Claude Code 2026 specs and elements
from top OSS harness projects (superpowers, ECC, spec-kit, BMAD, claude-flow).

### Added

- **`constitution.md`**(repo ルート): 7 つの不変原則を分離。`scan-harness.sh` の
  hash 監視で改竄検出。各 blueprint 配下にミラー、`setup.sh` で自動配置。
- **`.claude-plugin/marketplace.json`**: Claude Code 2026 plugin 仕様で
  日英 2 plugin を marketplace 配布対応化。
- **`/brainstorm` skill**: `/prd` の前段で Socratic 質問駆動の前提整理を行う
  読取専用 skill。`output/brainstorm/` に保存、3 ラウンド上限。
- **`.claude/learnings/`**: 成功パターンを confidence スコア付きで蓄積する継続学習層。
  `pitfalls.md`(失敗パターン集)の対概念。サンプル `L0001-*.md` 同梱。
- **新 hook 3 種**:
  - `user-prompt-submit.sh`: ユーザー入力に機密パターン検出
  - `session-end.sh`: セッション終了時に集計を `output/reports/sessions/<date>.md` に追記
  - `scan-harness.sh`: ハーネス自身の SAST + 高リスク skill (`deploy*`) 実効ブロック
- **Hook profile**: `BLUEPRINT_HOOK_PROFILE=minimal|standard|strict` で挙動切替。
- **Output styles**(`.claude/output-styles/`): フェーズ別 4 種(prd / design /
  implementation / review)。`/output-style phase-prd` で切替、`statusline.sh` で表示。
- **Statusline**(`.claude/statusline.sh`): モデル名 / git ブランチ / フェーズ /
  output-style を表示。`settings.json` の `statusLine` で配線。
- **Permissions guide**(`.claude/permissions-guide.md`): allowlist / auto / sandbox の
  3 階層運用ガイド。
- **Agents frontmatter 拡張**(2026 spec): `security-reviewer` に `isolation: worktree`、
  `doc-synchronizer` / `explorer` に `memory: project`、5 agents に `skills:` 参照。
- **Teams topology メタデータ**: `claude-flow` 風の hierarchical / mesh / star 分類を
  6 チームに付記(`teams/README.md`)。
- **Pitfalls #16-20**: コンテキスト管理の 5 失敗パターン(Kitchen sink / Over-correction /
  Bloated CLAUDE.md / Trust-then-verify gap / Infinite exploration)とセッション運用コマンド表。
- **MCP optional servers**: `filesystem`, `brave-search` を推奨度マーク付きで追加。

### Changed

- **CLAUDE.md を 200 行以内に再構成**(351 → 194 行 ja / 196 行 en)。詳細を
  `.claude/rules/{document-management,git-conventions,workflow-advanced}.md` に分離。
- **設定ファイルの統合**: `settings.json` に `statusLine` / `UserPromptSubmit` /
  `SessionEnd` / `PreToolUse(Skill)` hook を配線。`Agent(name)` 構文を `_comment` で説明
  (公式採用済みだが本テンプレでは default の 6 agents を保持)。
- **`settings.local.json.template`**: `BLUEPRINT_HOOK_PROFILE` env を追加。
- **`.gitignore`**: `output/reports/sessions/` / `output/brainstorm/` /
  `.claude/memory/` を追加。

### Fixed

- `user-prompt-submit.sh` の grep 正規表現で `-----BEGIN ...` がフラグとして
  解釈される問題を `grep -qE --` で修正。
- `scan-harness.sh` が stdin を捨てて毎回フル SAST する問題を、
  skill 別判定(低リスクは constitution+local deny のみ、高リスクのみフル)に最適化。
- `marketplace.json` の `components.hooks` を settings.json から hooks ディレクトリへ修正。
- 英語版 `session-end.sh` のテーブルヘッダを日本語のままだったので英語化。

### Security

- `scan-harness.sh` による self-SAST(secret パターン / constitution hash /
  settings.local の deny 弱体化検出)で 4 重防御に強化:
  Layer 1(hooks) → Layer 2(deny) → Layer 3(allow) + meta(self-SAST)。
- `protect-files.sh` 既存リスト維持。
- `bypassPermissions` モードでも `.claude/`、`.git/` への書き込みは保護される(公式仕様)。

### Documentation

- `README.md` / `README-en.md` の数値クレームを更新(16 skills + 12 hooks +
  6 agents + 4 output styles + constitution)。
- `pitfalls.md` の Out of Scope を整理、実装済み機能リストは本 CHANGELOG に集約。
- `guardrails.md` のフック一覧と hook profile 説明を更新。

### Migration notes

既存の blueprint 利用者向け:

1. `setup.sh` を再実行すると `constitution.md` がターゲットに配置される(既存ファイルは保持)。
2. `settings.json` を再生成または手動マージし、`statusLine` / 新 hook 3 種を配線。
3. `settings.local.json` に `"BLUEPRINT_HOOK_PROFILE": "standard"` を追加(任意)。
4. `Agent(general-purpose)` を deny したい場合は手動で `permissions.deny` に追加可能(2026-04 公式仕様で対応)。

---

## [0.2.0] — 2026-04-23

Initial blueprint self-enhancement series(PR #10 マージ — `17cbf99`)。
詳細は git log 参照。

## [0.1.0] — 2026-02-22

15 skills + 6 teams + 6 agents + 9 hooks + MCP テンプレート + 13 セクションの
project-config.md を備えたブループリント初版(PR #2 マージ — `c46966a`)。

[Unreleased]: https://github.com/froggugugugu/project-blueprints/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/froggugugugu/project-blueprints/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/froggugugugu/project-blueprints/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/froggugugugu/project-blueprints/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/froggugugugu/project-blueprints/releases/tag/v0.1.0
