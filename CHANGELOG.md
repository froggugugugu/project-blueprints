# Changelog

All notable changes to this project will be documented in this file.

このプロジェクトの注目すべき変更を記録する。日英バイリンガル(同一構造)。
形式は [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) に準拠し、
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) を採用。

## [Unreleased]

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

Initial blueprint self-enhancement series。詳細は git log 参照
(`17cbf99` Merge PR #10 までの履歴)。

## [0.1.0] — 2026-04-01

15 skills + 6 teams + 6 agents + 9 hooks + MCP テンプレート + 13 セクションの
project-config.md を備えたブループリント初版。

[Unreleased]: https://github.com/froggugugugu/project-blueprints/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/froggugugugu/project-blueprints/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/froggugugugu/project-blueprints/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/froggugugugu/project-blueprints/releases/tag/v0.1.0
