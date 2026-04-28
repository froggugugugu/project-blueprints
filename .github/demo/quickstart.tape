# project-blueprints — 5 行 quickstart デモ
# 出力: .github/demo/quickstart.gif
# 実行: vhs .github/demo/quickstart.tape

# 注: 録画前に /tmp/demo-rc-off.json を準備しておく(remoteControl 無効化用):
#   echo '{"remoteControlAtStartup": false}' > /tmp/demo-rc-off.json
# (本テンプレ利用者には不要な操作。ここでは GIF への session URL 露出を回避するため)
#
# CI 再生成について: claude の出力タイミングは環境差で揺れるため、固定 Sleep
# ではなく Wait+Screen による出力ベースの待機を採用。それでも完全に決定論的では
# ないので、本 tape は「maintainer の手動再生成」を想定し、CI 自動再生成は意図しない。

Output .github/demo/quickstart.gif

Set Shell "bash"
Set FontSize 14
Set Width 1100
Set Height 700
Set Theme "TokyoNight"
Set TypingSpeed 45ms
Set PlaybackSpeed 1.0

Hide
# 毎回ユニークな workspace を使う(claude の trust list に過去の render が
# 登録されると trust prompt が出なくなり Wait が timeout するため)
Type "DEMO_WS=$(mktemp -d) && cd $DEMO_WS && export PS1='$ ' && clear" Enter
Show

Sleep 600ms
Type "# project-blueprints — 5 行で動かす quickstart"
Sleep 800ms
Enter
Sleep 400ms

# Line 1: clone(完了は Resolving deltas で判定)
Type "git clone https://github.com/froggugugugu/project-blueprints.git"
Sleep 200ms
Enter
Wait+Screen /Resolving deltas: 100%/

# Line 2: setup(完了は「セットアップ完了」で判定)
Type "bash project-blueprints/project-blueprint/setup.sh ./my-app"
Sleep 200ms
Enter
Wait+Screen /セットアップ完了/

# Line 3: §2 を printf で追加
Type "printf '\\n## §2 技術スタック\\n- TypeScript / Vite / Vitest\\n' >> ./my-app/project-config.md"
Sleep 200ms
Enter
Sleep 400ms

# 録画限定: remoteControl 無効化(GIF 上の session URL 露出を防ぐ)
Hide
Type "cp /tmp/demo-rc-off.json ./my-app/.claude/settings.local.json" Enter
Type "clear" Enter
Show

# Line 4: cd & claude 起動
Type "cd ./my-app && claude"
Sleep 200ms
Enter

# Claude Code の trust prompt が出るまで待つ
Wait+Screen /Yes, I trust this folder/

# trust 承認(Enter で default 選択)
Enter

# Claude のメインプロンプト(status bar の "1M context" or "Tasks")が出るまで待つ
Wait+Screen /1M context/

Sleep 600ms

# /plan 投入
Type "/plan ログイン機能の設計"
Sleep 400ms
Enter

# Claude の処理開始は名前(Forging/Pontificating/Hullaballooing 等)がランダムに
# 変わるため安定マッチが難しい。ここは固定 Sleep で AI の応答開始を見せる。
Sleep 4500ms
