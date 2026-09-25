# ハーネス補強レポート — 2026-09-26(Claude 5 系対応 + 公式仕様の総点検)

## サマリ

- 対象: `project-blueprint/` と `project-blueprint-en/` の `.claude/` 骨格・ルート指示ファイル・CI テンプレート、`scripts/`
- 変更: 69 ファイル修正(ルート文書・`scripts/` を含む)/ 6 ファイル新規(JP/EN 各 3: `hooks/config-guard.sh`、`REVIEW.md`、`.claude/loop.md`)。ミラー構成差分 0
- 検証: `bash scripts/validate-harness.sh` → ERROR 0 / WARN 0、`--test` 47/47 検出(+7)、`--hooks` PASS 106 / FAIL 0(+22)、
  `--online` で固定版が解決、`setup.sh --profile full` の展開先に validator をかけて ERROR 0 / WARN 0
- 依頼: 「最新のハーネス構造のトレンド、Markdown の書き方、Anthropic 公式のベストプラクティス、Anthropic エンジニアの推奨を
  包括的に取り込み、最強のハーネス構造として見直して補完する」(5 巡目)

## Round 0 — 参照した一次ソース(2026-09-25〜26 取得)

公式 docs は `https://code.claude.com/docs/en/<page>.md` が生 Markdown を返す(`llms.txt` に全ページ索引)。HTML 経由の取得は
Next.js の描画で本文が落ちるため、この経路で 60 ページを保存して機械的に突き合わせた。

| ソース | 反映先 |
| ------ | ------ |
| code.claude.com/docs `hooks` / `hooks-guide` | SessionStart `compact` matcher による再注入(公式パターン)、`if` の限定条件と best-effort、ConfigChange の decision 可否、PermissionRequest の agent 型禁止 |
| code.claude.com/docs `tools-reference` | Task ツールは Claude 3.x / Opus 4〜4.7 / Sonnet 4〜4.6 / Haiku 4.5 でだけ既定 → `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` |
| code.claude.com/docs `sub-agents` / `skills` | `omitClaudeMd` / `background` / `mcpServers` / `experimental.cacheTtl`、入れ子の既定 3 階層と `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`、出力スキャン、skill の `paths` / `when_to_use`、予約名前空間 |
| code.claude.com/docs `context-window` / `memory` / `costs` | コンパクトで残るもの(paths 付き rule と skill 本文は消える、skill は 5,000 トークンで切り詰め)、AGENTS.md の読込条件(v2.1.277+) |
| code.claude.com/docs `settings-reference` / `changelog`(2.1.245〜2.1.282) | project / local settings で無視されるキー(OTel env は v2.1.282)、`attribution` / `includeCoAuthoredBy` 非推奨、`workflowSizeGuideline`、Opus 5.5 既定化(v2.1.280) |
| code.claude.com/docs `permissions` / `permission-modes` / `auto-mode-config` / `security` / `sandboxing` | サーバー側分類器の既定化、`blockReadsOutsideWorkingDirectories`、認証情報に組み込み deny リスト無し(`sandbox.credentials`)、ConfigChange フックの推奨 |
| code.claude.com/docs `github-actions` / `code-review` / `routines` / `scheduled-tasks` / `workflows` / `model-config` | claude-code-action v1 の入力(`prompt` / `claude_args`)、`REVIEW.md`、`.claude/loop.md`、Routines の最小 1 時間、`Workflow(<名前>)`、`fable` / `best` エイリアスと effort 既定 |
| platform.claude.com/docs `prompting-claude-{opus-5,opus-5-5,fable-5,fable-5-1}` / `claude-prompting-best-practices` | 過剰検証・過剰委譲・保守的レビュー・思考の開示・出力長の指示が Claude 5 系で逆効果になる点 |
| anthropic.com/engineering `effective-harnesses-for-long-running-agents` / `harness-design-long-running-apps` / `effective-context-engineering` / `writing-tools-for-agents` / `building-effective-agents` / `multi-agent-research-system` / `demystifying-evals` / `claude-code-auto-mode` | コンテキストリセット > コンパクト、QA agent は既定で甘い、進捗はツール結果で裏付ける、回帰 eval と能力 eval の分離、判定の種類(コード / モデル / 人間) |
| claude.com/blog `how-anthropic-teams-use-claude-code`(PDF 全文)/ research `claude-code-expertise` | 「検証可能な成功シグナル」「slot machine(直すより作り直す)」「計画は人間・実行は AI」 |
| agents.md / agentskills.io / OpenAI `harness-engineering` / Spec Kit / BMAD / Kiro / superpowers / ECC / claude-flow / ccpm | AGENTS.md は目次、機械強制 > 散文、ハーネス設定自体を攻撃面として検査、EARS 形式の受け入れ基準、ハーネス設定のドリフト検知 |

## 公式仕様で判明した欠陥(今回の主要な発見)

| # | 欠陥 | 根拠 | 影響 |
| - | ---- | ---- | ---- |
| 1 | `TaskCompleted` の検証ゲート(品質ゲート③の機械強制)が現行モデルでは一度も発火していなかった | tools-reference: Task ツールは Sonnet 5 / Opus 5.5 / Fable で既定無効 | team の「TaskCreate でタスクリスト」も無効。`env` で有効化 |
| 2 | コンパクト後の再注入が次のユーザープロンプトまで遅れていた | hooks-guide: SessionStart の `compact` matcher の出力は圧縮直後に文脈へ入る | 自動コンパクト後に Claude が続行する間、rule と進捗の再注入が無かった |
| 3 | `enabledPlugins` の `draw.io@claude-plugins-official` が公式 marketplace(311 個)に存在しない | ローカルの marketplace キャッシュと突合 | 起動時に黙って無視。CLAUDE.md 等の draw.io 参照は空約束だった |
| 4 | `claude-review.yml.template` が beta 時代の入力(`model` / `max_turns` / `direct_prompt`)を使っていた | github-actions: v1 の入力は `prompt` / `claude_args` | コピーしてもモデル指定とターン上限が効かない |
| 5 | `settings.local.json.template` が OTel 変数を project / local settings の `env` に書く手順を案内していた | changelog v2.1.282 | 案内どおりにしても無視される |
| 6 | `CLAUDE.md` / `code-review` が Claude 5 系で逆効果の指示を含んでいた(「gap のみ報告」「subagent を積極活用」) | prompting guides: 保守的レビューは文字どおり報告を減らし、Opus 5 系は委譲を多用 | レビューの取りこぼしと不要な委譲 |
| 7 | サンドボックスの例に認証情報の deny が無かった | sandboxing: 組み込みの credential deny リストは存在しない | `~/.aws` `~/.ssh` が既定で読める |

## 適用した補正(ファイルパスごと)

### 新規(JP/EN)

| ファイル | 内容 | 根拠 |
| -------- | ---- | ---- |
| `.claude/hooks/config-guard.sh` | `ConfigChange` で設定変更を JSONL 記録し、`disableAllHooks` / local の deny / Layer 1 ブロック系フックの削除は exit 2 でセッションへの適用を止める | security docs「ConfigChange hooks で設定変更を監査・阻止」/ constitution ⑤ |
| `REVIEW.md` | Code Review(GitHub App)専用の基準: Important の定義・Nit 上限 5・報告しない領域・常に確認する項目・`file:line` の根拠・再レビュー収束・要約の形 | code-review docs `REVIEW.md` |
| `.claude/loop.md` | 引数なし `/loop` の既定プロンプト(未完了作業 → PROGRESS.md の次の一手 → PR 対応 → `/code-review`)。不可逆操作と未検証の完了報告を禁止 | scheduled-tasks docs `loop.md` |

### 修正

| ファイル | 変更 | 根拠 |
| -------- | ---- | ---- |
| `.claude/settings.json` | `env`: `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` / `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`。`commit-quality.sh` に `"if": "Bash(git commit *)"`。`ConfigChange` → `config-guard.sh`。draw.io 削除(17 スクリプト / 20 登録) | tools-reference / sub-agents / hooks |
| `.claude/hooks/session-start.sh` | `source == "compact"` で起動時チェックを省き、中核ルール + PROGRESS.md を即座に再注入 | hooks-guide「Re-inject context after compaction」 |
| `.claude/hooks/post-compact-restore.sh` / `user-prompt-submit.sh` | マーカー機構を撤去。前者は要約保全のみ、後者はプロンプト検査のみ | 同上 |
| `.claude/agents/explorer.md` | `omitClaudeMd: true`(読取専用・CLAUDE.md 不要) | sub-agents `omitClaudeMd` |
| `.claude/CLAUDE.md` | subagent 戦略(委譲条件・全件報告→MUST 対応)、コンパクト再注入の記述、Compact instructions(制約の原文・行き詰まり)、`/loop`、mermaid | prompting guides / context-window |
| `AGENTS.md` | 「問題の説明・質問には評価だけを返し、修正は依頼されてから」(1 行入替で 200 行維持) | Fable 5 guide「State the boundaries」 |
| `.claude/rules/harness-authoring.md` | 最重要指示を冒頭に / 番号付き手順は順序が要るときだけ / 思考開示・再確認の指示を書かない / レビューは全件報告 / `paths:` / `omitClaudeMd` / hooks の `if` / SessionStart compact / 回帰 eval と能力 eval | prompting guides / context-window / demystifying-evals |
| `.claude/rules/workflow-advanced.md` | Task ツールの有効化注記、進捗はツール結果で裏付け、区切りで PROGRESS.md 更新 + `/clear`(リセット > コンパクト) | harness-design-long-running-apps / Fable 5 guide |
| `.claude/skills/code-review/SKILL.md` | 「gap に限定」→ 全件列挙し重要度で絞る、自己却下の禁止 | Opus 5 guide / harness-design(QA agent は甘い) |
| `.claude/skills/prd/references/prd-template.md` | 受け入れ基準に EARS 形式を推奨 | Kiro specs |
| `.claude/skills/harness-refine/SKILL.md` | Round 0 に `/skill-doctor` / `/doctor`、基準ソースにプロンプティングガイドと tools-reference / changelog | — |
| `.claude/agents/README.md` | 新フィールド 4 種、入れ子の既定と env、委譲の判断、fork、出力スキャン | sub-agents |
| `.claude/teams/README.md` | Task ツールの有効化、`workflowSizeGuideline`、`Workflow(<名前>)` | workflows |
| `.claude/pitfalls.md` | #21 訂正、#32〜#36 追加、拡張候補から EARS を削除(実装済み) | — |
| `.claude/guardrails.md` | フック表 17 本、コンパクト節の書き換え、ConfigChange の decision、`if` の限定、env 行、`sandbox.credentials`、Routines の注意 | hooks / sandboxing / routines |
| `.claude/permissions-guide.md` | サーバー側分類器、`blockReadsOutsideWorkingDirectories`、`--permission-prompts none` | permission-modes / changelog |
| `.claude/quality-gates.md` | 判定の種類(コード / モデル / 人間)。モデル判定だけでゲートを通さない | demystifying-evals |
| `.claude/managed-settings.example.json` | `sandbox.credentials`、`failIfUnavailable: true`、`allowUnsandboxedCommands: false`、`blockReadsOutsideWorkingDirectories`、`requiredMinimumVersion: 2.1.277` | sandboxing「Organization configuration」 |
| `.claude/settings.local.json.template` | OTel の置き場所訂正、任意プラグイン一覧、credentials の例、`Workflow(...)` allow、profile 一覧 | changelog v2.1.282 / sandboxing / workflows |
| `.claude/output-styles/phase-design.md` / `project-config*.md` §12 | draw.io → mermaid | marketplace 実在確認 |
| `project-config*.md` §13.1 | Frontier tier `fable`、`opus` = `claude-opus-5-5`、Opus 5.5 の既定 effort `medium` の注記 | model-config |
| `.mcp.json.template` | `@upstash/context7-mcp@4.1.1` / `@playwright/mcp@0.0.82`、context7 プラグインとの二重接続注記 | `--online` で解決確認 |
| `.github/workflows/claude-review.yml.template` / `CLAUDE_REVIEW_SETUP.md` | v1 入力(`prompt` + `claude_args`)、`id-token: write` / `actions: read` | github-actions |
| `.github/workflows/claude-skills-ci.yml.template` | `--max-budget-usd 5` / `--no-session-persistence`、`--permission-prompts none` の注記 | cli-reference |
| `.github/workflows/claude-scheduled-audit.yml.template` | 既定ブランチ限定・60 日無活動での無効化・`allowed_bots`・`ultra` を付けない | github-actions / code-review |
| `setup.sh` | `REVIEW.md` の配置(既存は保持)、フック本数 17 | — |
| `scripts/validate_harness.py` / `test_validate_harness.py` / `test_hooks.sh` | 検査 9 種追加(下記)、負のテスト +7、フック機能テスト +22 | — |
| ルート `README*.md` / `CLAUDE.md` / blueprint `README.md` / `.github/pages` / `CHANGELOG.md` | 本数・新規ファイル・仕組みの反映 | — |

### validator に追加した検査

`if` はツール系 5 イベント限定(他は ERROR)・`&&` / `||` 不可 / PermissionRequest の agent 型は ERROR /
権限ルールの閉じ括弧後テキストは ERROR / `Bash(cmd * sub)` は WARN / project settings の `pluginConfigs` /
`remoteControlAtStartup` / `sandbox.ripgrep` / OTel・一時ディレクトリの `env` は WARN / `enabledPlugins` の marketplace 実在
(ローカルキャッシュがあるときだけ WARN)/ 予約名前空間 `anthropic-skills` `claude-ai` は ERROR / agent の
`omitClaudeMd` `background` は true / false のみ、`experimental.cacheTtl` は 5m / 1h のみ / `.claude/loop.md` は 25,000 文字まで。

## 定量比較

| 指標 | 変更前 | 変更後 |
| ---- | ------ | ------ |
| フック(スクリプト / settings 登録) | 16 / 19 | 17 / 20 |
| 常に発火する PostToolUse Bash フック | 3(safety-check は Pre、commit-quality / verify-gate track) | commit-quality は `git commit` 時のみ |
| コンパクト後の再注入タイミング | 次のユーザープロンプト | 圧縮直後 |
| TaskCompleted ゲートの発火(Sonnet 5 / Opus 5.5 / Fable) | 0 回(ツール不在) | 有効 |
| `explorer` 起動ごとの CLAUDE.md + AGENTS.md 読込 | 200 行 | 0 行 |
| validator の負のテスト / フック機能テスト | 40 / 84 | 47 / 106 |
| `CLAUDE.md` + `AGENTS.md` | 200 行(JP / EN) | 200 行(JP / EN) |

## 見送った項目(理由)

- **PROGRESS.md の機能リストを JSON 化**(Anthropic の長時間エージェント知見): 人間が読む引き継ぎノートと SessionStart 注入の
  可読性を優先。`passes` 列だけ更新する規約と検証ゲートで同じ目的を満たしている
- **skill-eval に発動率(should / should-not trigger)の測定モードを追加**: `evals.json` の形式変更と workflow の改修が要る。
  現状は `/skill-doctor` の使用率で代替し、次回の候補に残す
- **TDD の RED→GREEN をフックで機械強制**(ECC): テストファイル先行の検知はテストの配置規約に依存し、スタック非依存の
  テンプレートでは誤検知が多い。`verify-gate.sh` の検証コマンド追跡までに留める
- **`sandbox.enabled` の既定 ON**: 引き続きプロジェクト側の判断(npm install など閉域運用を壊す)。managed settings 例には推奨値を反映
- **`REVIEW.md` を `/code-review` にも読ませる**: 公式仕様でローカル版は読まないため、両方に効かせる規則は skill 側に置く運用にした
- **`/skill-eval` / `/review-sweep` の実行**: トークン消費が大きいため未実行。構文と workflow 規約は validator で検査済み

## 残課題(人間判断)

1. `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` は Task ツールの定義をコンテキストに戻す。TaskCompleted ゲートと team のタスク追跡を
   使わないプロジェクトでは `settings.json` の `env` から外してよい
2. `explorer` の `omitClaudeMd: true` は「日本語で応対」の規則も外す。探索結果の言語が問題になるなら agent 本文に明記する
3. `managed-settings.example.json` の `failIfUnavailable: true` は sandbox 依存(bubblewrap / socat)の無い Linux で起動を止める。
   組織展開時に確認する
4. `--online` の WARN 6 件は `_comment_optional_servers` の deprecated パッケージ(postgres / slack / brave-search)で既知。
   後継が出たら差し替える
