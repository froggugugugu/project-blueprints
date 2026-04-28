# Demo recording

GIF を再生成する手順(`vhs` 必要):

```bash
# 1. 録画前準備: remoteControl 無効化用設定ファイル
echo '{"remoteControlAtStartup": false}' > /tmp/demo-rc-off.json

# 2. レンダリング
vhs docs/demo/quickstart.tape
# → docs/demo/quickstart.gif が再生成される
```

## 必要なツール

- [vhs](https://github.com/charmbracelet/vhs) — VHS declarative terminal recorder
- [ttyd](https://github.com/tsl0922/ttyd) — vhs 依存(疑似ターミナル)
- ffmpeg — vhs 依存(動画エンコード)

## ファイル

- `quickstart.tape` — VHS スクリプト(declarative、再現可能)
- `quickstart.gif` — レンダリング済み GIF(README から参照、~715 KB)

## 録画前準備が必要な理由

`vhs` は **実コマンドを実行**するため、`claude` 起動時に表示される
**remote-control session URL** が GIF にそのまま映ってしまいます。

- claude.ai 認証なしには内容にアクセス不能なので**実害なし**
- ただし session ID の露出は OSS 配布物として気持ち悪い

そのため、録画前に `/tmp/demo-rc-off.json` を準備し、tape 内で
`./my-app/.claude/settings.local.json` にコピーすることで `remoteControlAtStartup: false`
を有効化 → URL が出ない状態で録画する。

## ローカル再現を本物にする条件

`vhs` は実コマンドを実行するため、以下が `PATH` にある状態で実行すれば
**本物の Claude Code セッションを含む GIF** がそのまま生成される:

- `git`(`git clone` 用)
- `bash`
- `claude` (Claude Code CLI、認証済み・workspace 信頼済みが望ましい)

GIF サイズが GitHub 制限(10 MB)を超えそうなら、`Set Width` / `Set Height` を
小さくするか、`Set TypingSpeed` を速める。
