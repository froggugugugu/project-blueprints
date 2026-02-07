# Agent Teams 実行手順書（Ubuntu + tmux）

> **環境**: Ubuntu + VS Code + Claude Code  
> **前提**: Claude Code がインストール済み・ログイン済みであること  
> **作成日**: 2026-02-07

---

## Phase 1: 環境準備（初回のみ）

### 1-1. tmux のインストール

```bash
sudo apt update
sudo apt install tmux -y
```

確認：

```bash
tmux -V
```

バージョンが表示されれば OK。

### 1-2. tmux の設定（アクティブペインの視認性改善）

デフォルトの tmux は、どのペインが選択中か非常にわかりにくいです。  
提供する `.tmux.conf` を配置してください。

```bash
cp tmux.conf ~/.tmux.conf
```

この設定で以下が変わります：

| 要素 | 非アクティブペイン | アクティブペイン |
|---|---|---|
| **背景色** | グレー（薄暗い） | 黒（通常の明るさ） |
| **ボーダー色** | 暗いグレー | 明るい水色 |

その他の便利機能：

- **マウスクリックでペイン選択**が可能（`mouse on`）
- **`Ctrl+B` → `Q`** でペイン番号を2秒間表示（どれが何番か確認）
- **`Ctrl+B` → `R`** で設定ファイルをリロード（変更を即反映）
- ステータスバーが**上部に表示**（ペイン内容を邪魔しない）

> 既に `.tmux.conf` がある場合は、内容をマージしてください。

### 1-3. Claude Code のアップデート

```bash
claude update
claude --version
```

Agent Teams 対応版（Opus 4.6 以降）であることを確認。

### 1-4. Agent Teams の有効化

`~/.claude/settings.json` を編集：

```bash
nano ~/.claude/settings.json
```

以下を追記（既存の内容がある場合はマージ）：

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

保存して閉じる（nano の場合: `Ctrl+O` → `Enter` → `Ctrl+X`）。

> **補足**: settings.json に書いておけば、毎回環境変数を設定する必要はありません。

---

## Phase 2: プロジェクトのファイル準備（機能ごとに実施）

### 2-1. ディレクトリ構成の確認

プロジェクトルートに以下の構成があることを確認：

```
.claude/
├── CLAUDE.md                        ← プロジェクト共通ルール
├── teams/
│   └── TEAMCREATE_ASSIGNMENT.md     ← チーム構成指示（英語版）
└── tasks/
    └── TASK03_EN.md                 ← 機能開発指示書（英語版）
```

なければ作成：

```bash
mkdir -p .claude/teams .claude/tasks
```

### 2-2. CLAUDE.md の確認

プロジェクト共通ルールが記載されているか確認。全チームメイトが自動で読み込むファイルです。

```bash
cat .claude/CLAUDE.md
```

### 2-3. TEAMCREATE / TASK ファイルの配置

対象機能の TEAMCREATE と TASK ファイルが `.claude/teams/` と `.claude/tasks/` に配置されているか確認。

```bash
ls .claude/teams/
ls .claude/tasks/
```

---

## Phase 3: tmux セッション起動 → Agent Teams 実行

### 3-1. tmux セッションを開始

**VS Code のターミナルではなく、Ubuntu のターミナルアプリ（Guake 等）で実行してください。**  
分割ペインモードを使う場合、VS Code 統合ターミナルでは動作しません。

```bash
tmux new -s agent-work
```

> **`-s agent-work`** はセッション名。任意の名前でOK。

### 3-2. プロジェクトディレクトリに移動

```bash
cd /path/to/your/project
```

### 3-3. Claude Code を起動

```bash
claude
```

### 3-4. Agent Teams を実行

Claude Code のプロンプトに以下を入力：

> **📎 Claudeへの指示**
> ```
> Read .claude/teams/TEAMCREATE_ASSIGNMENT.md and follow all instructions
> in that file. Create the agent team as specified, use delegate mode,
> and require plan approval before any changes.
> ```
>
> **📎 和訳**
> ```
> .claude/teams/TEAMCREATE_ASSIGNMENT.md を読み、そのファイルの全指示に従ってください。
> 記載通りにエージェントチームを作成し、デリゲートモードを使用し、
> 変更前に必ず計画承認を要求してください。
> ```

---

## Phase 4: チーム作業中の操作

### 4-1. チームメイトの確認・切り替え

| 操作 | キー |
|---|---|
| チームメイト一覧を見る | Lead のターミナルに自動表示 |
| チームメイトを選択 | `Shift + ↑` / `Shift + ↓` |
| 選択したチームメイトのセッションに入る | `Enter` |
| チームメイトの作業を中断 | `Escape` |
| タスクリストの表示/非表示 | `Ctrl + T` |
| delegate モードの切り替え | `Shift + Tab` |

### 4-2. 計画承認のフロー

チームメイトが計画を作成すると、PL（Lead）に承認リクエストが届きます。

1. PL のターミナルに計画承認リクエストが表示される
2. 内容を確認する
3. **承認する場合**: PL が自動で承認判断（TEAMCREATE に記載した承認基準に従う）
4. **却下する場合**: PL がフィードバック付きで却下 → チームメイトが修正して再提出

> **注意**: PL の承認基準は TEAMCREATE.md の指示文で制御できます。  
> 例: 「ユニットテストを含まない計画は承認しない」

### 4-3. チームメイトへの直接指示

特定のチームメイトに追加指示を出したい場合：

1. `Shift + ↑/↓` でチームメイトを選択
2. メッセージを入力して `Enter`

### 4-4. PL が自分でコードを書き始めた場合

`Shift + Tab` を押して delegate モードに切り替え。  
PL がオーケストレーション（生成・メッセージ・タスク管理）のみに制限されます。

---

## Phase 5: 作業完了・後片付け

### 5-1. 完了確認

TEAMCREATE の完了条件をチェック：

- [ ] 開発者: 実装完了 + ユニットテスト全パス
- [ ] レビュア: レビュー完了 + 指摘事項がすべて解消
- [ ] テスタ: 結合テスト + E2E テスト全パス
- [ ] PL: 他機能との整合性確認完了

### 5-2. チームの終了

PL（Lead）に以下を指示：

> **📎 Claudeへの指示**
> ```
> Shut down all teammates and clean up the team.
> ```
>
> **📎 和訳**
> ```
> 全チームメイトをシャットダウンし、チームをクリーンアップしてください。
> ```

> **注意**: チームメイトは現在の作業の完了を待ってから停止するため、少し時間がかかる場合があります。

### 5-3. Claude Code の終了

```
/exit
```

### 5-4. tmux セッションの終了

```bash
exit
```

または、tmux セッションが残っている場合：

```bash
# セッション一覧を確認
tmux ls

# 特定のセッションを終了
tmux kill-session -t agent-work
```

---

## tmux 基本操作リファレンス

Agent Teams の操作とは別に、tmux 自体の基本操作をまとめます。

| 操作 | コマンド / キー |
|---|---|
| 新しいセッションを作成 | `tmux new -s セッション名` |
| セッション一覧 | `tmux ls` |
| セッションに再接続 | `tmux attach -t セッション名` |
| セッションからデタッチ（裏に回す） | `Ctrl+B` → `D` |
| セッションを終了 | `exit` または `tmux kill-session -t セッション名` |
| ペインを縦分割 | `Ctrl+B` → `%` |
| ペインを横分割 | `Ctrl+B` → `"` |
| ペイン間の移動 | `Ctrl+B` → `矢印キー` |
| スクロールモード | `Ctrl+B` → `[`（`q` で終了） |

> **注意**: Agent Teams が分割ペインモードで動作している場合、tmux のペイン操作は Agent Teams が自動管理します。手動でペインを追加する必要はありません。

---

## トラブルシューティング

### Agent Teams が有効にならない

```bash
# settings.json の確認
cat ~/.claude/settings.json

# 環境変数での確認
echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
```

どちらかで `1` が設定されていること。設定後、Claude Code を再起動。

### tmux セッションが残ってしまった

```bash
# 全セッション確認
tmux ls

# 不要なセッションを削除
tmux kill-session -t セッション名

# 全セッションを削除（注意）
tmux kill-server
```

### チームメイトがエラーで止まった

1. `Shift + ↑/↓` でチームメイトを選択
2. `Enter` でセッションに入る
3. エラー内容を確認
4. 修正指示を送るか、チームメイトを再起動するよう PL に指示

### PL が delegate モードから外れた

`Shift + Tab` で再度 delegate モードに切り替え。

### 「チームメイトが利用できないプラン」と警告が出る

Claude Code のバージョンが古い可能性があります。`claude update` を実行してください。

---

*本手順書は Agent Teams のリサーチプレビュー段階（2026年2月時点）の情報に基づいています。*
