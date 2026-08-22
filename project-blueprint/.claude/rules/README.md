# .claude/rules/ — パス別 / 言語別ルールの拡張ポイント

`.claude/rules/` は **Claude Code 公式のルール置き場**。ここに置いた `.md` は
再帰的に探索され、`CLAUDE.md` と同じ優先度でコンテキストに載る。

## 2 種類のルール

| 種類 | frontmatter | load タイミング | 使い分け |
| ---- | ----------- | --------------- | -------- |
| **always-on** | なし | 全セッションの起動時 | 常に効かせたい短いルール(例: コミット規約) |
| **path-specific** | `paths:` あり | 該当パスのファイルを Claude が触ったときだけ | 言語別・レイヤー別の詳細ルール |

> **重要**: `paths:` を書かないルールは**全セッションで常時 load される**。
> CLAUDE.md から切り出しただけでは軽量化にならないので、
> 汎用でないルールには必ず `paths:` を付けること。

### path-specific ルールの書き方

```markdown
---
paths:
  - "src/api/**/*.ts"
  - "src/**/*.{ts,tsx}"
---

# API 開発ルール

- すべてのエンドポイントで入力バリデーションを行う
- エラーレスポンスは標準フォーマットに従う
```

`paths` は glob。ブレース展開(`{ts,tsx}`)も使える。

| パターン | マッチ対象 |
| -------- | ---------- |
| `**/*.ts` | 全ディレクトリの TypeScript ファイル |
| `src/**/*` | `src/` 配下すべて |
| `*.md` | プロジェクトルート直下の Markdown |
| `src/components/*.tsx` | 特定ディレクトリのコンポーネント |

## 同梱ルールの構成

| ファイル | 種類 | スコープ |
| -------- | ---- | -------- |
| `git-conventions.md` | always-on | 全セッション(コミットは常に発生しうる) |
| `document-management.md` | path-specific | `docs/**` `output/**` `input/**` `project-config.md` |
| `workflow-advanced.md` | path-specific | `src/**` `app/**` `lib/**` `packages/**` `tests/**` |
| `language-typescript.md.example` | path-specific(サンプル) | `**/*.{ts,tsx}` |
| `language-python.md.example` | path-specific(サンプル) | `**/*.py` |
| `path-backend.md.example` | path-specific(サンプル) | `backend/**/*` |

## サンプルの有効化(2 ステップ)

```bash
# 1. .example を外してコピー
cp .claude/rules/language-typescript.md.example .claude/rules/language-typescript.md

# 2. paths: と本文をプロジェクトに合わせて編集
vi .claude/rules/language-typescript.md
```

`CLAUDE.md` への追記は不要 — `paths:` にマッチしたときに自動で load される。

## 命名規則

| プレフィックス | 用途 | 例 |
| -------------- | ---- | -- |
| `language-*.md` | 言語 / フレームワーク別 | `language-typescript.md`, `language-python.md`, `language-swift.md` |
| `path-*.md` | 特定パス配下のみに適用するルール | `path-backend.md`, `path-frontend.md`, `path-mobile.md` |
| `rule-*.md` | 特定の技術トピックに対するルール | `rule-accessibility.md`, `rule-performance-budget.md` |

サブディレクトリ(`frontend/` `backend/` 等)も再帰的に探索される。
シンボリックリンクも解決されるため、複数プロジェクトで共通ルールを共有できる:

```bash
ln -s ~/shared-claude-rules .claude/rules/shared
```

## rules と skill の使い分け

| | `.claude/rules/` | `.claude/skills/` |
| --- | --- | --- |
| load 契機 | 起動時 or パス一致時(受動) | 呼び出し時 or 説明文一致時(能動) |
| 向くもの | 「常に守るべき制約」 | 「特定作業の手順」 |
| コスト | 常時 or 頻繁にコンテキストを消費 | 起動時のみ |

タスク固有の手順は rules ではなく skill に置く(公式ガイダンス)。

## コンセプト整合

- `.claude/rules/` は汎用テンプレート層の一部(プロジェクト固有値は `project-config.md` や `docs/` に)
- ルールは 1 ファイル 50〜100 行を目安に(CLAUDE.md と同じ理由で肥大化を避ける)
- example は初期状態で**無効**(`.example` 拡張子がついている限り読まれない)
- ルールが増えすぎるとトークンコストが膨らむ。always-on は最小限、詳細は `paths:` で絞る
- 詳細は `@.claude/pitfalls.md` の #1, #4 参照
