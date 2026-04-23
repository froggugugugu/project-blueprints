# 落とし穴集 — Claude Code 協調開発で踏みやすい失敗パターン

AI 協調開発で頻出する失敗事例と対策をまとめる。
実際に発見したプロジェクト固有の落とし穴は `project-config.md` §11 や `docs/development-patterns.md` に追記する。
本ファイルは **テンプレート横断の普遍的な落とし穴** に絞る。

## 運用上の落とし穴

### 1. CLAUDE.md の肥大化

| 項目 | 内容 |
| ---- | ---- |
| **現象** | CLAUDE.md が長くなるほど、書いた指示が守られなくなる |
| **原因** | 200 行を超えると重要度の低い指示に埋もれて参照精度が落ちる。全セクションを毎セッション読み込むためトークンコストも肥大 |
| **対策** | 横断ルールのみに絞る。詳細は skill / `docs/` / `.claude/rules/` に分離。`@path` import を活用 |

### 2. subagent は親の skill / rules を継承しない

| 項目 | 内容 |
| ---- | ---- |
| **現象** | `subagent` から skill を呼ぶと、親の CLAUDE.md や rules が読まれず期待通り動かない |
| **原因** | Claude Code の仕様。subagent は独立コンテキストで起動し、親の memory を共有しない |
| **対策** | subagent の `prompt` に必要なルール・前提を明示的に書く。agent 定義ファイル本文にも再掲する |

### 3. `~/.claude/skills/` はフラット構造必須

| 項目 | 内容 |
| ---- | ---- |
| **現象** | `~/.claude/skills/category/my-skill/SKILL.md` を置いても認識されない |
| **原因** | ユーザー領域の skill scan は 1 階層のみ。再帰探索されない |
| **対策** | `~/.claude/skills/<skill-name>/SKILL.md` のフラット構造で配置する。プロジェクト側 `.claude/skills/` は階層 OK |

### 4. Full content injection によるトークン爆発

| 項目 | 内容 |
| ---- | ---- |
| **現象** | skill / agent 実行が遅い。コストが想定の 10 倍かかる |
| **原因** | skill 本文や agent prompt で巨大ファイルを `Read` で全読みしている |
| **対策** | Grep で候補行を絞ってから Read。Read の `limit` / `offset` を使う。大きい docs は `@docs/...` の import に分離 |

### 5. Hooks: exit 1（非ブロック）と exit 2（ブロック）の混同

| 項目 | 内容 |
| ---- | ---- |
| **現象** | 危険コマンドをブロックしたはずが通ってしまう |
| **原因** | Hook で `exit 1` を返しているが、Claude Code は `exit 2` のみをブロック扱いする |
| **対策** | ブロック系は必ず `exit 2`。警告系は `exit 0` + stderr にメッセージ。既存 `safety-check.sh` を参考に |

### 6. ANTHROPIC_API_KEY スコープ過大による課金事故

| 項目 | 内容 |
| ---- | ---- |
| **現象** | 意図しない大量 API 呼び出しで高額課金（数百〜数千ドル） |
| **原因** | GitHub Actions・CI で無制限の API キーを使い、PR 大量作成や autonomous loop が暴走 |
| **対策** | 月額 / 日額上限を API キーに設定。`claude-code-action` には `max_turns` / `timeout_minutes` を設定。autonomous loop は exit gate を二重化 |

## セキュリティ・権限の落とし穴

### 7. MCP サーバーの信頼モデル誤解

| 項目 | 内容 |
| ---- | ---- |
| **現象** | MCP サーバー経由で任意コマンドが実行され、シークレットが流出 |
| **原因** | MCP サーバーはローカルで任意コマンドを実行する権限を持つ。悪意のあるサーバーを `.mcp.json` に追加すると危険 |
| **対策** | 公式・信頼できるソースのサーバーのみ。認証情報は環境変数参照（`${VAR}`）。`permissions.deny` で未知の MCP を拒否し、`permissions.allow` で明示許可 |

### 8. `.claude/settings.local.json` の誤共有

| 項目 | 内容 |
| ---- | ---- |
| **現象** | 個人の allow リストがチームに共有され、他メンバーの環境で想定外のコマンドが通る |
| **原因** | `.gitignore` に `settings.local.json` が含まれていない or 含めずにコミット |
| **対策** | `.gitignore` に必ず含める。チーム共有ルールは `settings.json` 側に書く |

### 9. `output/` と `input/` の越境

| 項目 | 内容 |
| ---- | ---- |
| **現象** | AI が `input/requirements/REQ_*.md` を勝手に書き換えたり、人間が `output/reports/` に手書き追記したり |
| **原因** | input/output の責務分離ルールを知らないセッションが介入 |
| **対策** | CLAUDE.md §「ドキュメント管理方針」を全 agent の prompt に引き継ぐ。agent 側の `tools` でスコープ制限 |

### 10. `testreport/` を git にコミット

| 項目 | 内容 |
| ---- | ---- |
| **現象** | リポジトリ肥大化。カバレッジ HTML や大量の JSON が履歴に残る |
| **原因** | `setup.sh` が `.gitignore` に追加するが、既存プロジェクトで追加前にコミットしてしまった |
| **対策** | `.gitignore` に `testreport/` を含める。過去に混入していたら `git filter-repo` で履歴から除去 |

## スキル・チーム運用の落とし穴

### 11. Skill の `description` が長すぎて発動が曖昧

| 項目 | 内容 |
| ---- | ---- |
| **現象** | skill が意図せず発動する / 発動しない |
| **原因** | `description` が 500 字を超えると Claude のマッチング精度が落ちる |
| **対策** | 1〜2 文、100 字程度に絞る。「〜のときに使用する」の形式で条件を明示 |

### 12. 並行 team 起動時の共有レイヤー競合

| 項目 | 内容 |
| ---- | ---- |
| **現象** | `TEAM_PJM --parallel` で複数 Bundle が同じ `src/shared/` を編集して競合 |
| **原因** | Feature Bundle 特定時に共有レイヤーの分離を怠った |
| **対策** | `TEAM_PJM.md` の「Feature Bundle 特定ルール」を遵守。共有レイヤーは Phase 4b で逐次処理 |

### 13. `project-config.md` §11 と `docs/development-patterns.md` の二重更新

| 項目 | 内容 |
| ---- | ---- |
| **現象** | 落とし穴が 2 ファイルに散らばり、どちらが最新か不明に |
| **原因** | 更新責務が曖昧。複数 skill が同じ情報を別の場所に書く |
| **対策** | CLAUDE.md §「docs/ 更新の競合防止」の責務テーブルを守る。一次更新者は `/implementing-features` |

### 14. `@` import のパス誤り

| 項目 | 内容 |
| ---- | ---- |
| **現象** | `@.claude/pitfalls.md` が見つからず、CLAUDE.md の参照が壊れる |
| **原因** | `@` import は Claude Code がリポジトリルートからのパスとして解決する。CLAUDE.md 自身のディレクトリからの相対ではない |
| **対策** | 既存の `@docs/*.md` / `@.claude/*.md` パターンに倣う（ルート相対）。迷ったら `ls` で存在を確認 |

### 15. Git フック迂回の誘惑

| 項目 | 内容 |
| ---- | ---- |
| **現象** | フック失敗時に `--no-verify` で強行通過、後でバグが表面化 |
| **原因** | フック失敗の原因を修正するより迂回の方が速く見えるため |
| **対策** | `--no-verify` は既存 `safety-check.sh` フックでブロック済み。迂回したくなったら「フックが何を守っているか」を調べる。本 CLAUDE.md §Git 操作ポリシーも参照 |

## 今後の拡張候補（Out of Scope）

以下は現テンプレートに未実装だが、取り込み検討中:

- **`/bug-fix` 専用 skill**: Pimzino/claude-code-spec-workflow 風の Report→Analyze→Fix→Verify パイプライン
- **EARS 形式要件記述**: gotalab/cc-sdd 風の Kiro spec-driven を `/prd` に導入
- **`brief.md` 成果物**: セッション再開用の scope summary を Phase 0 成果物として追加
- **Plugin 化**: `.claude-plugin/marketplace.json` を追加して marketplace 配布可能に
- **英語版同期**: `project-blueprint-en/` への完全反映（本テンプレート変更の追従）

これらは将来の強化計画で取り込む。現状は「本 pitfalls.md に記録」レベルで予告に留める。
