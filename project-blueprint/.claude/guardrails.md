# ガードレール — 安全機構の全体像

本ファイルは、プロジェクトに適用されるすべての安全機構をまとめた参照文書。
`CLAUDE.md` の各セクションに分散するルールを一元的に把握できるようにする。

---

## フック一覧

| フック | イベント | 対象 | 動作 | 説明 |
| ------ | -------- | ---- | ---- | ---- |
| `safety-check.sh` | PreToolUse | Bash | ブロック | 危険なシェルコマンドを検出・阻止 |
| `protect-files.sh` | PreToolUse | Edit\|Write | ブロック | 機密ファイル・設定ファイルへの書き込みを阻止 |
| `session-start.sh` | SessionStart | — | 警告 | project-config.md / docs/ / settings.local.json の存在チェック |
| `commit-quality.sh` | PostToolUse | Bash (git commit) | 警告 | Conventional Commits 形式チェック・シークレット検出 |
| `console-warn.sh` | PostToolUse | Edit\|Write | 警告 | デバッグステートメント（console.log 等）の残存検出 |
| `notify-claude.sh` | Stop / Notification | — | 通知 | タスク完了時の外部通知（ntfy） |

### フックの動作原則

- **ブロック系**: exit 2 で操作を中止。理由を stderr で通知
- **警告系**: exit 0 で操作は許可。フィードバックを stderr で通知
- **通知系**: exit 0。外部サービスに通知を送信
- **fail-open ポリシー**: JSON パース失敗時は操作を許可（安全側に倒さず、作業を止めない）
- フックは `--dangerously-skip-permissions` モードでも有効（多層防御）

### フックタイプの使い分け

| タイプ | 用途 | 例 |
| ------ | ---- | -- |
| `command` | シェルスクリプトを実行。パターンマッチ・ファイル検査等の決定論的チェック | safety-check.sh, protect-files.sh |
| `prompt` | AIに判断を委ねるプロンプトを実行。文脈依存の柔軟な判定が必要な場合 | 「このBashコマンドは本番環境で安全か評価せよ」 |

- デフォルトは `command` タイプを推奨（決定論的で高速）
- `prompt` タイプはコンテキスト依存の判断が必要な場合のみ使用（トークンを消費する）
- 両タイプを同一イベントに併用可能（command → prompt の順で評価）

### 拡張可能なフックイベント

本テンプレートで使用していないが、プロジェクト固有に追加可能なフックイベント:

| イベント | タイミング | 用途例 |
| -------- | ---------- | ------ |
| `SubagentStart` | サブエージェント起動時 | DB接続セットアップ、環境変数注入 |
| `SubagentStop` | サブエージェント終了時 | リソースクリーンアップ、結果集約 |
| `InstructionsLoaded` | CLAUDE.md/rules読み込み時 | 観測・ログ記録（ブロック不可） |

`settings.json` に追加する形式:

```json
{
  "SubagentStart": [
    {
      "matcher": "db-agent",
      "hooks": [
        { "type": "command", "command": "./scripts/setup-db.sh", "timeout": 10 }
      ]
    }
  ]
}
```

---

## Deny ルール（settings.json）

| パターン | 目的 |
| -------- | ---- |
| `Bash(rm -rf *)` | 再帰削除の防止 |
| `Bash(rm -rf /*)` | ルートディレクトリ削除の防止 |
| `Bash(rm -fr *)` | 再帰削除（フラグ順違い）の防止 |
| `Bash(git push --force *)` | 強制プッシュの防止 |
| `Bash(git push -f *)` | 強制プッシュ（短縮形）の防止 |
| `Bash(git reset --hard *)` | ハードリセットの防止 |
| `Bash(git clean -f *)` | 追跡外ファイル一括削除の防止 |
| `Bash(sudo *)` | 特権昇格の防止 |

---

## 保護ファイル一覧

### シークレット・認証情報（protect-files.sh）

| ファイル / パターン | 理由 |
| -------------------- | ---- |
| `.env`, `.env.local`, `.env.production` 等 | 環境変数（シークレット含有の可能性） |
| `id_rsa`, `id_ed25519`, `id_ecdsa`, `id_dsa` | SSH秘密鍵 |
| `credentials.json`, `service-account.json` | クラウド認証情報 |
| `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.jks`, `*.keystore` | 証明書・キーストア |
| `.claude/settings.json`, `.claude/settings.local.json` | Claude Code 設定 |

### ツールチェーン設定（protect-files.sh）

| ファイル / パターン | 理由 |
| -------------------- | ---- |
| `biome.json`, `biome.jsonc` | Biome リンター/フォーマッター設定 |
| `.eslintrc.*`, `eslint.config.*` | ESLint 設定 |
| `.prettierrc.*`, `prettier.config.*` | Prettier 設定 |
| `tsconfig.json`, `tsconfig.*.json` | TypeScript コンパイラ設定 |
| `.editorconfig` | エディタ設定 |

---

## 禁止操作（CLAUDE.md + safety-check.sh）

| 操作 | 理由 |
| ---- | ---- |
| `--no-verify` | Git フックの迂回は禁止 |
| `--force` (git push) | 履歴の破壊は原則禁止 |
| `sudo` | 特権昇格は禁止 |
| `curl \| bash` | リモートスクリプトのパイプ実行は禁止 |
| `chmod 777` | 過剰な権限付与は禁止 |
| `dd if=` / `mkfs` | ディスク操作は禁止 |

---

## 3層防御モデル

```text
Layer 1: フック（PreToolUse / PostToolUse / SessionStart）
  ↓  --dangerously-skip-permissions でも有効
Layer 2: Deny ルール（settings.json）
  ↓  通常モードで有効
Layer 3: Allow ルール（settings.local.json）
  ↓  通常モードでのみ有効
```

- Layer 1 は常に有効。最も信頼性の高い防御層
- Layer 2 は通常モードで自動適用
- Layer 3 はプロジェクト固有の許可ルール（テンプレートから設定）
