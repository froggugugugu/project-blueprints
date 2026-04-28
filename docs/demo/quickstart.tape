# project-blueprints — 5 行 quickstart デモ
# 出力: docs/demo/quickstart.gif
# 実行: vhs docs/demo/quickstart.tape

Output docs/demo/quickstart.gif

Set Shell "bash"
Set FontSize 14
Set Width 1100
Set Height 700
Set Theme "TokyoNight"
Set TypingSpeed 45ms
Set PlaybackSpeed 1.0

# クリーンな demo workspace の準備(画面外で)
Hide
Type "cd /tmp && rm -rf demo-workspace && mkdir -p demo-workspace && cd demo-workspace && export PS1='$ ' && clear" Enter
Show

Sleep 600ms
Type "# project-blueprints — 5 行で動かす quickstart"
Sleep 800ms
Enter
Sleep 400ms

# Line 1: clone
Type "git clone https://github.com/froggugugugu/project-blueprints.git"
Sleep 200ms
Enter
Sleep 2200ms

# Line 2: setup
Type "bash project-blueprints/project-blueprint/setup.sh ./my-app"
Sleep 200ms
Enter
Sleep 2500ms

# Line 3: §2 を printf で追加
Type "printf '\\n## §2 技術スタック\\n- TypeScript / Vite / Vitest\\n' >> ./my-app/project-config.md"
Sleep 200ms
Enter
Sleep 1000ms

# Line 4: cd & claude 起動
Type "cd ./my-app && claude"
Sleep 200ms
Enter

# Claude Code が起動 → 信頼ダイアログが出るので Enter で承認
Sleep 4500ms
Enter
Sleep 3500ms

# Claude プロンプトに /plan 投入
Type "/plan ログイン機能の設計"
Sleep 500ms
Enter
Sleep 5000ms
