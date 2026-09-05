# Changelog

All notable changes to this project will be documented in this file.

このプロジェクトの注目すべき変更を記録する。日英バイリンガル(同一構造)。
形式は [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) に準拠し、
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) を採用。

## [Unreleased]

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

### Changed

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

[Unreleased]: https://github.com/froggugugugu/project-blueprints/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/froggugugugu/project-blueprints/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/froggugugugu/project-blueprints/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/froggugugugu/project-blueprints/releases/tag/v0.1.0
