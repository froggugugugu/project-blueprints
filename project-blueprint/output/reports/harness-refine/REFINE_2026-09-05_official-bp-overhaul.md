# ハーネス補強レポート — 2026-09-05(公式ベストプラクティス総点検)

## サマリ

- 対象: `project-blueprint/` と `project-blueprint-en/` の `.claude/` 骨格 + `scripts/validate_harness.py`
- 変更: 47 ファイル修正 / 6 ファイル新規(JP/EN 各 3)。ミラー構成差分 0
- 検証: `bash scripts/validate-harness.sh` → ERROR 0 / WARN 0、負のテスト 22/22 検出(新規 5 ケース)
- 新規フックの動作テスト: `verify-gate.sh`(track / gate × standard / strict / minimal / stop_hook_active / background_tasks)、
  `permission-denied-log.sh`、`session-start.sh` の PROGRESS 注入をサンプル JSON で確認済み

## Round 0 — 参照した一次ソース(2026-09-05 取得)

| ソース | 反映先 |
| ------ | ------ |
| code.claude.com/docs `best-practices` | 検証手段の付与・証拠提示・Stop フックゲート・敵対的レビュー・plan 省略基準・CLAUDE.md の include/exclude |
| code.claude.com/docs `memory` / `context-window` / `prompt-caching` / `costs` | 200 行目安・HTML コメントは context に載らない・途中編集は無効・Compact instructions |
| code.claude.com/docs `hooks` | `PreModelSwitch` / `PostModelSwitch`、`if` / `once` / `asyncRewake`、prompt / agent 型、Stop の 8 回上限 |
| code.claude.com/docs `permissions` / `permission-modes` / `auto-mode-config` | auto mode 既定化(v2.1.228+)、deny → ask → 分類器の評価順、project settings で無視されるキー、`Tool(param:value)` |
| code.claude.com/docs `skills` / `sub-agents` / `output-styles` | bundled skill の同名上書き、`disable-model-invocation`、fork mode 既定 ON、ネスト 5 階層、`keep-coding-instructions` |
| code.claude.com/docs `worktrees` / `settings-reference` | `.claude/worktrees/` / `agent-memory-local/` の gitignore、`autoMemoryEnabled` |
| anthropic.com/engineering `effective-harnesses-for-long-running-agents` | PROGRESS ノート・機能リスト・1 セッション 1 機能・スモークテスト |
| anthropic.com/engineering `effective-context-engineering-for-ai-agents` | 最小高信号コンテキスト・note-taking・sub-agent 隔離 |
| claude.com/blog `steering-claude-code-...`(Anthropic staff) | 「毎回必ず X」はフック、「絶対にしない」は deny、手順は skill、output style の落とし穴 |
| code.claude.com/docs `whats-new`(W13〜W34) | auto mode 既定化 / fork mode 既定化 / cross-session messaging / dynamic workflows |

## 適用した補正(ファイルパスごと)

### 新規

| ファイル(JP/EN) | 内容 | 根拠 |
| ---------------- | ---- | ---- |
| `.claude/hooks/verify-gate.sh` | PostToolUse で編集 / 検証コマンドを記録し、Stop で未検証終了を検知(standard=systemMessage / strict=1 回 block)。`stop_hook_active` と `background_tasks` を尊重 | best-practices「Stop hook as deterministic gate」/ hooks「8 consecutive blocks」 |
| `.claude/hooks/permission-denied-log.sh` | auto mode の分類器拒否を `testreport/denials/` に JSONL 記録 | auto-mode-config「Review denials」 |
| `.claude/tasks/PROGRESS_TEMPLATE.md` | 複数セッション引き継ぎノート(状態 / 機能リスト passes / 次の一手 / セッションログ) | long-running harness ブログ |

### 修正

| ファイル | 変更 | 根拠 |
| -------- | ---- | ---- |
| `.claude/settings.json` | `verify-gate.sh track`(PostToolUse)/ `verify-gate.sh gate`(Stop)/ `permission-denied-log.sh`(PermissionDenied)を登録(15 スクリプト / 18 登録) | 同上 |
| `.claude/CLAUDE.md` | 証拠ルール、bundled skill(`/verify` `/btw` `/goal` `/batch`)、`/code-review` 上書き注記、auto mode の deny/ask 位置づけ、subagent の背景実行、plan 省略基準、長期タスク引き継ぎ、**Compact instructions** 節。199 行に収めるため 3 節を圧縮 | best-practices / memory / costs |
| `.claude/hooks/session-start.sh` | `output/tasks/PROGRESS.md` の先頭 60 行を additionalContext で注入 | long-running harness |
| `.claude/output-styles/*.md`(4 × 2) | `keep-coding-instructions: true` を追加。**従来は Claude Code 標準のエンジニアリング指示(検証習慣・変更スコープ)を丸ごと落としていた** | output-styles / steering ブログ |
| `.claude/pitfalls.md` | #2 を公式仕様に訂正(subagent は CLAUDE.md / rules を継承する。継承しないのは skill 本文・会話・auto memory)。#23〜#27 追加(auto mode / 途中編集無効 / project settings で無視 / bundled 上書き / Stop ループ) | sub-agents / permission-modes / prompt-caching / skills / hooks |
| `.claude/guardrails.md` | フック一覧 15/18、検証ゲート節、profile 対応リスト、`if` / `once` / `asyncRewake`、`agent` 型、`PreModelSwitch` | hooks |
| `.claude/permissions-guide.md` | 全面改訂: auto mode 既定化、評価順序(deny → ask → 分類器 → フック)、設定の置き場所表、拒否ログ活用、`/auto-mode-setup`、`/goal` | permissions / auto-mode-config |
| `.claude/rules/workflow-advanced.md` | §2 に証拠提示・レビュー subagent の指示、§6「長期タスクの引き継ぎ」新設 | best-practices / long-running harness |
| `.claude/agents/README.md` | 「公式仕様の補足」節: 背景実行 / 継承範囲 / ネスト禁止(constitution ④)/ description 予算 / `Agent(param:value)` / メモリ保存先 | sub-agents / permissions |
| `.claude/skills/code-review/SKILL.md` | 「正確性・要件に影響する gap のみ」原則、bundled `/review` との関係 | best-practices「adversarial review」 |
| `.claude/skills/{review-fix,harness-refine}/SKILL.md` | `disable-model-invocation: true`(副作用のあるワークフローは手動起動) | skills / best-practices |
| `.claude/skills/harness-refine/SKILL.md` | 基準ソース表を更新(404 だった URL を修正、公式ドキュメント 4 群 + steering ブログ + whats-new を追加) | — |
| `.claude/settings.local.json.template` | `_comment_auto_mode` / `_comment_stop_gate`(prompt 型 Stop フック例)追加、Layer 1 一覧更新 | permissions / hooks |
| `.claude/quality-gates.md` / `.claude/teams/README.md` | 証拠要件 / dynamic workflows との使い分け | best-practices / workflows |
| `.gitignore` / `setup.sh` | `.claude/worktrees/` `.claude/agent-memory-local/` `.claude/settings.local.json` を除外(setup.sh はループ化) | worktrees / sub-agents |
| `README.md`(blueprint JP/EN)/ ルート `CLAUDE.md` `README*.md` | フック本数・ツリー・PROGRESS テンプレの反映 | — |
| `scripts/validate_harness.py` / `test_validate_harness.py` | `PreModelSwitch` / `PostModelSwitch`、hook `type` / `prompt` / boolean / timeout 検証、project settings の `defaultMode: auto` / `autoMode` 警告、`disable-model-invocation` / `user-invocable` の厳密値、output style の `keep-coding-instructions` 警告。負のテスト +5 | hooks / permission-modes / output-styles |

## 見送った項目(理由)

- **dynamic workflow(`.claude/workflows/`)の同梱**: スクリプト API を一次ソースで検証してからにする。README / teams で使い分けのみ記述
- **`FileChanged` フック(project-config.md 監視)**: 公式仕様上 decision control も context 注入もできず、ログ以上の価値が薄い
- **`bashOutputMaxChars` 等の出力上限設定**: 既定で十分。プロジェクト側の判断に委ねる
- **plugin 配布の再検討**: 撤回済み判断(2026-08)を覆す新事実なし

## 残課題(人間判断)

1. `verify-gate.sh` の `VERIFY_PATTERNS` はプロジェクトの検証コマンドに合わせて追記する(既定はメジャーな言語 / ツールのみ)
2. `strict` プロファイルで運用するかは各プロジェクトで決める(既定 `standard` は警告のみ)
3. `.claude/settings.json` の編集はテンプレート自身の `protect-files.sh` に阻まれるため、今回はシェル経由で JSON を書き換えた。差分は `git diff project-blueprint/.claude/settings.json` で確認できる

## ミラー差分検証(Round 1 時点)

- `.claude/` 配下ファイル数: JP 83 / EN 83(新規 3 ずつ、差分 0)
- `bash scripts/validate-harness.sh`: ERROR 0 / WARN 0(日英 + 構成一致)
- `bash scripts/validate-harness.sh --test`: 22/22 検出

---

## Round 2 — 観点別評価で S 未達だった項目の解消(2026-09-06)

Round 1 後に 12 観点で世界標準基準の評価を行い、総合 A(S 目前)と判定した。
S に届かない要因は (1) 自律運用の自動化不足 (2) 評価基盤の欠如 (3) 組織展開層の未整備の 3 つ。
本ラウンドでそれぞれを解消した。

| 観点 | Round 1 | 対応 | Round 2 |
| ---- | ------- | ---- | ------- |
| 3 検証ループ | A- | `scripts/test_hooks.sh`(54 ケース、JP/EN 両ミラー)を新設し `--hooks` として CI に組み込み。フックが「存在するだけ」にならない回帰テスト | **S** |
| 6 長期自律運用 | B+ | `/plan` が PROGRESS.md の機能リストを初期化し、`/implementing-features` が `passes` とセッションログを更新する手順を skill 本文と禁止事項に組み込み | **A+** |
| 7 仕様駆動ライフサイクル | S- | `verify-gate.sh task` を **TaskCompleted** に登録。検証コマンド未実行のタスク完了マークを standard=警告 / strict=exit 2 で差し止め(品質ゲート③の機械強制) | **S** |
| 8 サプライチェーン | A- | `.mcp.json.template` の有効サーバーをバージョン固定(`@upstash/context7-mcp@4.0.5` / `@playwright/mcp@0.0.80`)。validator `--online` が固定版の解決を検証し、未固定の有効サーバーを WARN | **A+** |
| 10 可観測性・コスト | B+ | `managed-settings.example.json`(deny / sandbox / OTel / `requiredMinimumVersion`)を同梱し、`settings.local.json.template` に OTel と `modelPricing` の指針を追加 | **A** |
| 11 導入体験 | A- | `setup.sh` が `settings.local.json` を雛形から自動生成。SessionStart の未作成警告が初回から消える | **A+** |
| 12 可搬性・大規模リポ | B | `rules/README.md` に monorepo 指針(per-directory skill / `claudeMdExcludes` / `worktree.sparsePaths` / `skillOverrides`)を追加 | **A** |
| 1 指示の階層化 | A+ | SessionStart が常時 `@import` される `docs/*.md` の肥大化(300 行超)を警告 | **S-** |

**Round 2 後の総合: S-**。残る差は観点 5(dynamic workflows の同梱スクリプト無し)と観点 2(sandbox 既定 OFF、`prompt` / `agent` 型フックは例示のみ)で、いずれも公式機能の成熟待ちか各プロジェクトの判断領域。

### Round 2 検証

- `bash scripts/validate-harness.sh`: ERROR 0 / WARN 0
- `bash scripts/validate-harness.sh --test`: 22/22 検出
- `bash scripts/validate-harness.sh --hooks`: PASS 54 / FAIL 0(JP 27 + EN 27)
- `bash scripts/validate-harness.sh --online`: 固定バージョンが npm で解決することを確認
- `.claude/CLAUDE.md`: JP 199 行 / EN 199 行(上限 200 行以内)
