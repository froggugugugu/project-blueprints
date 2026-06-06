---
name: harness-refine
version: 1.0.0
description: >
  This skill should be used when the user asks to "refine the harness", "self-improve the blueprint",
  "restructure .claude/ to match best practices", "audit harness configuration",
  or mentions "ハーネス補正", "ベストプラクティス準拠", "self-refine", "セルフリファイン",
  "ハーネス自己点検", "skill/agent/team 配置の見直し".
  Scope is limited to harness scaffolding — `.claude/` (skills / agents / teams / rules / output-styles),
  CLAUDE.md, README.md and the input/output/docs/testreport directory skeleton — under
  `project-blueprint/` and `project-blueprint-en/`. Source code, `docs/` content,
  `output/` deliverables, and `testreport/` raw data are out of scope.
  `constitution.md` and `project-config.md` §1 / §4-§10 / §12 / §13 are immutable.
  Both JP and EN mirrors MUST be kept in lockstep — completion requires structural parity.
  Runs self-score → self-improve → self-review for **2 fixed rounds**; escalates to a human
  if the round-2 reviewer does not approve.
  Outputs a refinement report to `output/reports/harness-refine/` (requires Write permission to that path).
  Takes optional argument: /harness-refine <target-dir or instruction>
argument-hint: "<対象ディレクトリ or 補正指示(省略可)>"
allowed-tools: Read, Glob, Grep, Bash(ls *, find *, wc *, diff *, git *), Edit, Write, WebFetch, WebSearch, Agent, mcp__plugin_context7_context7__resolve-library-id, mcp__plugin_context7_context7__query-docs
context: main
---

# Harness Refine — ベストプラクティス準拠の自己採点・強化・レビュー(2 ラウンド固定)

ハーネス構成(`project-blueprint/` および `project-blueprint-en/`)を、
**Claude Code 公式ベストプラクティス** と **`constitution.md` 7 原則** の両方を rubric として
**自己採点 → 自己強化 → セルフレビュー** を **2 ラウンド** 回して構造補正するメタスキル。

実装コード、`docs/` 内容、`output/` 成果物、`testreport/` 生データは対象外。**テンプレート骨格のみ**を扱う。

## 起動条件(代表例)

- 「ハーネスを補正して」「ベストプラクティス準拠で再構築して」「セルフリファインして」
- 「.claude/ の構造を見直したい」「skill / agent / team の配置を点検したい」
- 「project-blueprint と project-blueprint-en の整合性を整えて」

## 前提と参照ファイル

| 参照 | 用途 | 改変 |
| ---- | ---- | ---- |
| `constitution.md`(repo ルート) | 7 不変原則(rubric の上位条件) | ❌ 改変禁止 |
| `project-config.md` §1 / §4-§10 / §12 / §13 | 人間決定領域 | ❌ 改変禁止 |
| `project-config.md` §2 / §3 / §11 | AI 可変領域 | ⚠️ 構造のみ可(値は触らない) |
| `.claude/CLAUDE.md` | 横断ルール(原則 ⑥: ≤200 行目安) | ✅ |
| `.claude/skills/*/SKILL.md` | スキル骨格(frontmatter / pipeline) | ✅ |
| `.claude/agents/*.md` | 単発専門家定義 | ✅ |
| `.claude/teams/TEAM_*.md` | オーケストレーション | ✅ |
| `.claude/hooks/*.sh` | 3 層防御 Layer 1 | ❌ 本スキルでは触らない(別 PR で議論) |
| `.claude/rules/*.md` | パス / 言語別ルール拡張 | ✅(`.example` 規約を維持) |
| 公式ドキュメント | 最新 best practice | WebFetch / Context7 MCP |

## 改変境界(MUST 守れ)

| 領域 | 可否 | 補足 |
| ---- | ---- | ---- |
| `constitution.md` | ❌ | 改変は別 PR + `.constitution.sha256` 更新が必須(原則範囲外) |
| `project-config.md` §1 / §4-§10 / §12 / §13 | ❌ | 人間決定領域 |
| `project-config.md` §2 / §3 / §11 | ⚠️ | 構造的整形のみ。値の改変は禁止 |
| `.claude/CLAUDE.md` | ✅ | 200 行を超えない(220 行ハード上限) |
| `.claude/{skills,agents,teams,rules,output-styles}/` | ✅ | name 衝突 / 循環参照を作らない |
| `.claude/hooks/*.sh` | ❌ | スクリプト本体の編集は禁止(原則 ⑤) |
| `docs/`, `output/`, `testreport/` 内容 | ❌ | 本スキル対象外(`output/reports/harness-refine/` のみ書く) |
| `input/requirements/` | ❌ | 人間入力 |

破ろうとした場合は **即停止して人間に確認**。`scan-harness.sh` フックが検知する場合もある。

## 全体ワークフロー(2 ラウンド固定 — 3 ラウンド目は禁止)

```text
ラウンド 1                              ラウンド 2
  ┌─────────────┐                        ┌─────────────┐
  │ 1-A 自己採点 │                        │ 2-A 自己採点 │
  │   (rubric)   │                        │  (差分中心)  │
  └─────┬────────┘                        └─────┬────────┘
        ▼                                       ▼
  ┌─────────────┐                        ┌─────────────┐
  │ 1-B 自己強化 │ ── 日英ミラー適用 ──→  │ 2-B 自己強化 │ ── 日英ミラー適用 ──→
  └─────┬────────┘                        └─────┬────────┘
        ▼                                       ▼
  ┌─────────────┐                        ┌─────────────┐
  │ 1-C レビュー │ (code-reviewer agent)  │ 2-C レビュー │ (code-reviewer agent)
  └─────┬────────┘                        └─────┬────────┘
        └────────► R2 入力 ───────────────────┘
                                                ▼
                                         最終レポート出力
```

- ラウンド 1 で **大枠補正**(命名揺れ、配置ミス、frontmatter 欠落、ミラー乖離など)
- ラウンド 2 で **R1 残課題 + 二次効果**(`@import` 切れ、CLAUDE.md スキル一覧との不整合、リンク 404)
- 各ラウンドのレビューは `pr-review-toolkit:code-reviewer` agent に委任して **独立判定**を取る
- ラウンド 2 で承認に届かなければ **人間にエスカレーション**(自動 3 ラウンド禁止)

## ラウンド 1 — 大枠補正

### 1-A. 自己採点(10 項目 × 0/1/2 点 = 20 点満点)

| # | 項目 | 0 点 | 1 点 | 2 点 |
| - | ---- | ---- | ---- | ---- |
| 1 | constitution 7 原則の遵守 | 違反あり | 形式上遵守 | + `scan-harness.sh` でテスト化 |
| 2 | CLAUDE.md ≤200 行(原則 ⑥) | 220 行超 | 200-220 行 | 200 行以下 + `@import` 整理済 |
| 3 | skill frontmatter 規約 | name / description 欠落あり | 全項目あり | + allowed-tools / context / argument-hint 整備 |
| 4 | 三層分離(skill ⇄ agent ⇄ team, 原則 ④) | 循環 / 混在あり | 直線的 | + `agents/README.md` に選定ガイド |
| 5 | 3 層防御維持(原則 ⑤) | hook 削除あり | 同数維持 | + 各 hook の責務 header コメントあり |
| 6 | 日英ミラー同期(原則 ②) | ファイル数 / 構造に差 | ファイル数一致 | + 章立てまで一致 |
| 7 | rules オプトイン方式 | `.example` なし or 直読み込み | `.example` あり | + 命名規約(`language-*`, `path-*`, `rule-*`)厳守 |
| 8 | 5 品質ゲート(原則 ③) | 削減あり | 5 ゲート存在 | + 各 skill から `@.claude/quality-gates.md` 参照 |
| 9 | pipeline 連携明示 | 前後工程記載なし | 一部記載 | 全 skill に「前工程 → 本スキル → 後工程」表 |
| 10 | 公式 best practice 準拠(SKILL.md / settings 配置) | 古い形式 | 一部準拠 | 最新形式準拠 |

**目標**: ラウンド 1 で **16/20 以上**、ラウンド 2 で **19/20 以上**。

採点根拠は会話内に **必ずファイルパス + 行番号**で提示する(「なんとなく低い」は禁止)。
公式ベストプラクティスの判断は WebFetch(anthropic.com)/ Context7 MCP で最新版を参照する(訓練データのみで判断しない)。

### 1-B. 自己強化(補正)

スコア 0 / 1 点の項目を補正する。優先順:

1. **constitution 違反**: 即停止 → 人間確認(自動修正禁止。違反内容を箇条書きで提示)
2. **CLAUDE.md 行数超過**: `@.claude/rules/<topic>.md` に切り出し → `@import` 参照に置換
3. **frontmatter 欠落 / 命名揺れ**: skill / agent ファイルに追加・統一
4. **三層分離違反**: 該当呼び出しを単方向に矯正(skill → agent は可、agent → team は禁止)
5. **ミラー乖離**: 不足側にコピーし、文言は既存 `README-en.md` のトーンで翻訳
6. **`.example` 規約違反**: 実体ファイルを `.example` に戻すか、命名規約に揃える

**ミラー適用ルール**:

- 日本語側で 1 ファイル変更したら **同じターンで英語側にも適用**(片側だけで完了させない)
- 構造は完全一致、文言のみ翻訳。章立て番号・テーブル列・コードブロックは bit-identical
- 英語版にだけある体裁要素(セミコロン区切り等)は維持

### 1-C. セルフレビュー(独立判定)

`Agent` 経由で `pr-review-toolkit:code-reviewer` を **1 回呼ぶ**。
渡すコンテキスト:

- ラウンド 1 で行った全 Edit / Write の `git diff`
- `constitution.md` 7 原則の遵守チェックを明示依頼
- 日英ミラー差分(`diff -r project-blueprint/.claude/skills/ project-blueprint-en/.claude/skills/` の結果)

レビュー結果(MUST / SHOULD / CONSIDER)はラウンド 2 入力に集約。

## ラウンド 2 — 残課題と二次効果

### 2-A. 自己採点(差分中心)

ラウンド 1 で **1 点以下** だった項目を再採点。加えて以下を新規スコア対象に追加:

- ラウンド 1 Edit の副作用(`@import` 切れ、参照リンク 404、CLAUDE.md スキル一覧との不整合)
- ミラー側に取りこぼした変更
- code-reviewer の指摘(MUST は必ず採点へ反映)

### 2-B. 自己強化(クロージング)

- 残スコアを 2 点に引き上げる微修正のみ。新規大規模変更はしない
- `@import` リンク全件の存在確認:

  ```bash
  grep -rh '^@\.claude' project-blueprint/ project-blueprint-en/ | sort -u | \
    while read line; do
      path="${line#@}"
      test -e "project-blueprint/$path" || echo "MISSING(JP): $path"
      test -e "project-blueprint-en/$path" || echo "MISSING(EN): $path"
    done
  ```

- `CLAUDE.md` スキル一覧表の rebuild(`.claude/skills/*/SKILL.md` の `name:` と突き合わせ)
- ファイル数差を 0 に:

  ```bash
  diff <(cd project-blueprint && find .claude -type f | sort) \
       <(cd project-blueprint-en && find .claude -type f | sort)
  ```

### 2-C. セルフレビュー(最終)

再度 `pr-review-toolkit:code-reviewer` を呼ぶ。判定:

| レビュー判定 | 次アクション |
| ------------ | ------------ |
| **承認** | 最終レポート生成 → スキル終了 |
| **条件付き承認** | 残 MUST 修正可能か確認 → 可なら修正、不可なら人間エスカレーション |
| **要修正** | **即停止して人間エスカレーション**(ラウンド 3 への自動継続は禁止) |

## 出力契約

### 最終レポート(必須)

`output/reports/harness-refine/REFINE_<YYYY-MM-DD>_<HHMM>.md` に出力:

```markdown
# ハーネス補正レポート — <日付>

## サマリ
- ラウンド 1 スコア: NN/20 → ラウンド 2 スコア: MM/20(目標 ≥19)
- 補正ファイル数: 日本語側 X / 英語側 Y(差分 0 が MUST)
- constitution 違反: 検出 N 件 / 修正 N 件(自動修正は 0、すべて人間確認経由)
- code-reviewer 判定: 承認 / 条件付き / 要修正

## ラウンド 1
### 採点(10 項目)
[各項目: 点数 + 根拠ファイル:行]
### 補正
[ファイルパスごとの変更要約 + WHY]
### レビュー結果
[code-reviewer agent 出力サマリ]

## ラウンド 2
[同上]

## 残課題
- (あれば箇条書き。人間判断が必要なもののみ)

## ミラー差分検証
- ファイル数 diff: 一致 / 差 N
- 章立て差: なし / N 件(列挙)
- `@import` 切れ: 0 件 / N 件(列挙)
```

### 会話への提示

- 各ラウンド開始時に「これからラウンド N の採点を行います」と明示
- 採点結果は **1 行 1 項目** で表示(箇条書き)
- 補正は **何を / なぜ / どこを** を都度報告(silent edit 禁止)
- ミラー適用は **JP → EN を同一ターンで報告**

## 他スキルとの連携

| 前工程 | 本スキル | 後工程 |
| ------ | -------- | ------ |
| (なし — メタスキル) | `/harness-refine` | `/code-review`(コード側) / `/refactoring`(コード側) |

`/refactoring` はソースコード再構成、本スキルはハーネス骨格再構成と役割が異なる。混同しないこと。

## 禁止事項

- `constitution.md` の改変(全文 immutable)
- `project-config.md` §1 / §4-§10 / §12 / §13 の改変
- `.claude/hooks/*.sh` 本体の改変(原則 ⑤)
- 日英ミラーの **片側だけ**更新して完了とすること(原則 ②)
- `--no-verify` / `--force` を使った git 操作
- **3 ラウンド以上の自動ループ**(ラウンド 2 で承認得られなければ人間判断)
- ソースコード / `docs/` 内容 / `output/`(本スキル成果以外) / `testreport/` への変更
- 採点根拠を伴わないスコア提示

## 関連参照(必要に応じて Claude が load)

@.claude/guardrails.md
@.claude/quality-gates.md
@.claude/rules/workflow-advanced.md
@.claude/pitfalls.md
