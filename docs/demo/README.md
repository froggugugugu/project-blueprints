# Demo recording

GIF を再生成する手順(`vhs` 必要):

```bash
# 必要なツール:
# - vhs: https://github.com/charmbracelet/vhs
# - ttyd, ffmpeg(vhs の依存)

vhs docs/demo/quickstart.tape
# → docs/demo/quickstart.gif が再生成される
```

## ファイル

- `quickstart.tape` — VHS スクリプト(declarative、再現可能)
- `quickstart.gif` — レンダリング済み GIF(README から参照)

## ローカル再現を本物にする条件

`vhs` は実コマンドを実行するため、以下が `PATH` にある状態で実行すれば
**本物の Claude Code セッションを含む GIF** がそのまま生成される:

- `git`(`git clone` 用)
- `bash`
- `claude` (Claude Code CLI、認証済み・workspace 信頼済みが望ましい)

GIF サイズが GitHub 制限(10 MB)を超えそうなら、`Set Width` / `Set Height` を
小さくするか、`Set TypingSpeed` を速める。
