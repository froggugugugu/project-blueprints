# Claude Code 自動 PR レビューのセットアップ

`anthropics/claude-code-action` を使った PR レビュー自動化のセットアップ手順。
**本機能はオプトイン**。有効化しなければ既存の開発フローに影響しない。

## 前提

- GitHub リポジトリのオーナーまたは管理者権限
- Anthropic API キー（[console.anthropic.com](https://console.anthropic.com) で取得）
- 初期コスト見積もり: 中規模 PR 1 件あたり $0.05 〜 $0.30（Sonnet 使用時）

## セットアップ（4 ステップ）

### 1. ワークフローを有効化

```bash
# テンプレートをコピー
cp .github/workflows/claude-review.yml.template .github/workflows/claude-review.yml
```

### 2. API キーを GitHub Secrets に登録

1. リポジトリの **Settings** → **Secrets and variables** → **Actions**
2. **New repository secret** をクリック
3. Name: `ANTHROPIC_API_KEY`
4. Value: Anthropic Console で発行した API キーを貼り付け
5. **Add secret**

### 3. API キーのスコープと上限を設定（必須）

Anthropic Console で:

1. API キーの **Rate limits** を設定（例: 1,000 requests/day）
2. **Spend limit** を設定（例: 月額 $50）
3. **Workspace** を専用に分離（本番キーと混ぜない）

**これをやらないと課金事故のリスクあり**（`@.claude/pitfalls.md` #6 参照）。

### 4. 動作確認

1. テスト用の PR を作成
2. PR コメントに `@claude このPRをレビューして` と書く
3. 数分後、Claude からのレビューコメントが投稿される

## トリガー条件

デフォルトで以下のイベントで発動する（`.yml.template` の `if` 条件）:

| イベント | 発動条件 |
| -------- | -------- |
| PR コメント | `@claude` メンションを含む |
| PR レビューコメント | `@claude` メンションを含む |
| PR 作成・更新 | Draft でない PR |

不要なトリガーは `.yml` ファイルの `on:` / `if:` を編集して無効化する。

## カスタマイズ

### モデル選択

コストと品質のトレードオフ:

| モデル | 用途 | コスト目安 |
| ------ | ---- | ---------- |
| `claude-opus-5` | 高品質レビュー、アーキテクチャ監査 | 高（$0.30〜/PR） |
| `claude-sonnet-5` | 標準レビュー（推奨） | 中（$0.10/PR） |
| `claude-haiku-4-5-20251001` | 軽量レビュー、簡易チェック | 低（$0.02/PR） |

### レビュー観点のカスタマイズ

`claude-review.yml` の `direct_prompt` を編集。プロジェクト固有の観点を追加:

```yaml
direct_prompt: |
  ...
  追加観点:
  6. **パフォーマンス**: バンドルサイズ増加が 50KB を超えていないか
  7. **a11y**: キーボード操作・スクリーンリーダー対応
```

### max_turns による暴走防止

`max_turns` を小さく保つことで、無限ループ / 過剰な API 消費を防ぐ:

- 10（デフォルト、ほとんどの PR で十分）
- 5（簡易レビューのみ）
- 20（複雑な PR、要注意）

## セキュリティ注意事項

- **API キーは絶対にコード内に書かない**。Secrets 経由のみ
- **Permissions** は最小限（contents: read, pull-requests: write）。contents: write は付与しない
- **Forked PR** からの実行はデフォルトで secrets にアクセスできない（GitHub の仕様）。
  外部コントリビューターの PR をレビューするには `pull_request_target` を使うが、
  **セキュリティリスクがあるので慎重に**（[GitHub 公式警告](https://securitylab.github.com/research/github-actions-preventing-pwn-requests/)）

## コスト管理

- **月次で使用量を確認**: Anthropic Console の Usage 画面
- **アラート設定**: Spend limit の 80% で通知
- **コードが大きい PR**: `max_turns` を一時的に増やすより、**事前に PR を分割**するのが推奨（論点ごとに小さく切ると、レビュー精度もコスト効率も向上）
- **無駄な実行を避ける**: Draft PR でトリガーしないように `if` 条件を維持

## トラブルシューティング

| 症状 | 原因 | 対策 |
| ---- | ---- | ---- |
| ワークフローが走らない | `@claude` メンションの綴り間違い | `@claude`（小文字）を確認 |
| API エラー | Spend limit 到達 | Anthropic Console で上限を引き上げ or 待機 |
| レビューが的外れ | `direct_prompt` の観点が曖昧 | プロンプトを具体化、`project-config.md` を参照させる |
| forked PR で動かない | Secrets にアクセス不可 | GitHub の仕様。管理者が別途トリガー |

## 無効化

ワークフローを一時無効化するには:

```bash
# ファイルを .disabled に改名（削除より安全）
mv .github/workflows/claude-review.yml .github/workflows/claude-review.yml.disabled
```

恒久的に不要な場合はファイル自体を削除する。

## 関連

- 公式ドキュメント: [anthropics/claude-code-action](https://github.com/anthropics/claude-code-action)
- コスト guardrail のパターン: `@.claude/pitfalls.md` #6
- プロジェクトのレビュー規約: `@.claude/skills/code-review/SKILL.md`
