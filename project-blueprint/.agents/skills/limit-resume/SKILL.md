---
name: limit-resume
description: >
  サブスクの使用上限(5 時間・週次)に当たっても、解除時刻まで待ってタスクキューの続きを無人で回すランナーを準備・起動・監視する。
  「上限が解除されたら続けて回したい」「寝ている間に回したい」「無人で回したい」「リミット待ち」の依頼で使う。手動起動のみ。
argument-hint: "[setup | status | stop](省略時は setup)"
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(python3 .agents/skills/limit-resume/scripts/limit_resume.py *), Bash(claude --version), Bash(codex --version), Bash(touch testreport/limit-resume/STOP), Bash(tail *)
disable-model-invocation: true
---

# Limit Resume — 使用上限を待って無人で回す

使用上限による中断を「失敗」ではなく「待ち」として扱い、解除されたら同じキューの続きから再開させる。
従量課金を使わず、サブスクの範囲で長い作業を進めるための仕組み。

**ランナーはこのセッションの中で起動しない。** 何時間〜数日待つ長時間プロセスで、セッションの終了やコンパクトと寿命が合わないため。
キューと起動コマンドを用意し、起動はユーザーが別の端末(`tmux` / `nohup` など)で行う。

## 構成

| もの | 場所 |
| ---- | ---- |
| ランナー | `.agents/skills/limit-resume/scripts/limit_resume.py`(標準ライブラリのみ。Python 3.9 以上) |
| キュー | `output/tasks/limit-resume-queue.md`(既定の置き場所。`--queue` で変えられる) |
| 状態 | `testreport/limit-resume/state.json`(タスクごとの `pending` / `done` / `failed` と再開用のセッション ID) |
| 記録 | `testreport/limit-resume/runs.jsonl`(実行・待機・再開。Claude Code ではタスクごとの API 換算コストも残る) |
| 停止 | `testreport/limit-resume/STOP` を置くと、待機中か次のタスクの前で止まる |

ランナーの動き:

1. キューのタスクを上から 1 件ずつ、`claude -p --output-format json --permission-mode dontAsk` に渡す(Codex は `codex exec`)
2. 使用上限のメッセージを検知したら、そこから解除時刻を読み取り、解除時刻 + 120 秒まで眠る。読めなければ 15 分から倍々(最大 2 時間)で待つ
3. 再開時、Claude Code は中断したセッションを `--resume` で続ける。Codex は同じタスクを最初からやり直す
4. 上限による中断は試行回数に数えない。それ以外の失敗は 2 回まで試し、だめなら `failed` にして次へ進む
5. 状態を毎回保存するので、止めても同じコマンドで続きから再開できる(`done` は飛ばす)

## 引数による分岐

| 引数 | やること |
| ---- | -------- |
| `setup`(省略時) | 下の「準備」を最後まで行い、起動コマンドを渡す |
| `status` | `--status` の集計と `runs.jsonl` の末尾を読み、進み具合・待機中かどうか・失敗したタスクを報告する |
| `stop` | `touch testreport/limit-resume/STOP` を実行し、消せば同じコマンドで再開できることを伝える |

## 準備(setup)

この順で進める。

1. **課金の確認**: 次の 2 点をユーザーに確認する。ランナーは課金の設定を読めないため、ここで止める理由がある
   - usage credits(上限を超えた分の従量課金)を無効にするか、上限額を決めてあるか。有効なままだと、待たずに課金で走り続けることがある
   - `ANTHROPIC_API_KEY` を使わないこと。設定されているとサブスクではなく API の従量課金になる(ランナーは `--allow-api-key` が無いと起動しない)
2. **CLI の確認**: `claude --version`(Codex なら `codex --version`)が通ること
3. **キューを書く**: ユーザーの依頼をタスクに分け、下の形式で `output/tasks/limit-resume-queue.md` に書く。各タスクは次を満たす
   - 1 タスクだけ読んでも分かる(前のタスクの会話は引き継がれない)。対象ファイル・完了条件・検証コマンドを本文に書く
   - 2 回実行しても壊れない(冪等)。途中から再開・やり直しが起きるため
   - 不可逆な操作(push・merge・削除・デプロイ)を含めない。含めるなら、ユーザーの明示の指示をタスクに書き写す
4. **許可の確認**: `dontAsk` では allow に無い操作が拒否される。タスクが使うコマンド(テスト・lint・`git commit` など)が
   `.claude/settings.json` か `.claude/settings.local.json` の allow にあるかを確かめ、足りなければ追加案を示す(書き換えはユーザーの了承を得てから)
5. **dry-run**: `python3 .agents/skills/limit-resume/scripts/limit_resume.py --queue output/tasks/limit-resume-queue.md --dry-run` を実行し、
   対象タスクと組み立てたコマンド、`NG:` 行(事前チェックの不合格)が無いことを確認する
6. **起動コマンドを渡す**: 下の「起動」をユーザーに示して終える

### キューの形式

```markdown
# limit-resume キュー
<!-- `## <id>` 見出しごとに 1 タスク。id は英数字とハイフン。HTML コメントは無視される -->

## fix-lint
`src/` の lint エラーを直す。完了条件: `npm run lint` が 0 件。最後に `npm run lint` の結果を書く。

## add-tests-parser
`src/parser.ts` の分岐を網羅するテストを `tests/parser.test.ts` に足す。
完了条件: `npm test -- parser` が通り、カバレッジ 80% 以上。変更は 1 コミットにまとめる(push はしない)。
```

## 起動

```bash
# tmux で起動する例(端末を閉じても続く)
tmux new -s limit-resume \
  'python3 .agents/skills/limit-resume/scripts/limit_resume.py --queue output/tasks/limit-resume-queue.md'

# 進み具合
python3 .agents/skills/limit-resume/scripts/limit_resume.py --queue output/tasks/limit-resume-queue.md --status
tail -f testreport/limit-resume/runs.jsonl

# 止める(待機中でも止まる)。消して同じコマンドで再開
touch testreport/limit-resume/STOP
```

よく使うオプション:

| オプション | 既定 | 用途 |
| ---------- | ---- | ---- |
| `--agent claude\|codex` | `claude` | 使うエージェント |
| `--permission-mode` | `dontAsk` | Claude Code の権限モード。`bypassPermissions` は拒否する |
| `--max-wait-hours` | `170` | これより先の解除時刻なら待たずに終了する(週次上限を待つなら既定のまま) |
| `--notify-cmd "<cmd>"` | なし | 待機・完了・失敗のたびに `<cmd> <メッセージ>` を実行する(例: `terminal-notifier -message`) |
| `--stop-on-failure` | オフ | `failed` が出たらキューを止める |
| `--retry-failed` | オフ | 前回 `failed` にしたタスクもやり直す |
| `--max-turns` / `--model` | なし | `claude -p` にそのまま渡す |

## 報告(status)

```markdown
## limit-resume の状況
- キュー: done N / pending N / failed N
- 現在: <実行中のタスク id | <時刻> まで待機中(理由) | 停止中 | 完了>
- 失敗したタスク: <id と runs.jsonl の tail の要点>(無ければ「なし」)
- API 換算コストの合計: $X(サブスクの請求額ではなく、同じ量を API で使った場合の目安)
- 次の一手: <failed の対処 / キューへの追記 / 何もしない>
```

## Codex で使うとき

- `--agent codex` で `codex exec` を使う。権限は `.codex/config.toml` の設定に従う(ランナーは危険なフラグを渡さない)
- 中断したセッションの再開は使わず、タスクを最初からやり直す。冪等に書いたタスクだけを入れる
- Codex の上限メッセージの文言は実機で未確認。解除時刻が読めないときは上の指数バックオフで待つ

## 守ること

- 待機を短くするために usage credits を勧めない。待てない作業なら、ユーザーに「待つか課金するか」を選んでもらう
- タスクの本文に秘密情報を書かない(`runs.jsonl` に出力の末尾が残る)
- `failed` を黙って消さない。原因を報告し、直すか外すかをユーザーに決めてもらう
