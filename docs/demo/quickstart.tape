# project-blueprints — 5 行 quickstart デモ
# 出力: docs/demo/quickstart.gif
# 実行: vhs docs/demo/quickstart.tape

# 注: 録画前に /tmp/demo-rc-off.json を準備しておく(remoteControl 無効化用):
#   echo '{"remoteControlAtStartup": false}' > /tmp/demo-rc-off.json
# (本テンプレ利用者には不要な操作。ここでは GIF への session URL 露出を回避するため)

Output docs/demo/quickstart.gif

Set Shell "bash"
Set FontSize 14
Set Width 1100
Set Height 700
Set Theme "TokyoNight"
Set TypingSpeed 45ms
Set PlaybackSpeed 1.0

Hide
Type "cd /tmp && rm -rf demo-workspace && mkdir -p demo-workspace && cd demo-workspace && export PS1='$ ' && clear" Enter
Show

Sleep 600ms
Type "# project-blueprints — 5 行で動かす quickstart"
Sleep 800ms
Enter
Sleep 400ms

Type "git clone https://github.com/froggugugugu/project-blueprints.git"
Sleep 200ms
Enter
Sleep 2200ms

Type "bash project-blueprints/project-blueprint/setup.sh ./my-app"
Sleep 200ms
Enter
Sleep 2500ms

Type "printf '\\n## §2 技術スタック\\n- TypeScript / Vite / Vitest\\n' >> ./my-app/project-config.md"
Sleep 200ms
Enter
Sleep 800ms

# 録画限定: remoteControl 無効化(GIF 上の session URL 露出を防ぐ)
Hide
Type "cp /tmp/demo-rc-off.json ./my-app/.claude/settings.local.json" Enter
Type "clear" Enter
Show

Type "cd ./my-app && claude"
Sleep 200ms
Enter

# trust prompt
Sleep 4500ms
Enter
Sleep 3500ms

Type "/plan ログイン機能の設計"
Sleep 500ms
Enter
Sleep 5000ms
