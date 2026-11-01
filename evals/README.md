# Skill evals — 方法とベースライン

> `scripts/validate-harness.sh` が「ハーネスが仕様どおりの形か」を決定論的に検査するのに対し、ここは「skill が実際に挙動を変えているか」を
> LLM で計測する。数値が無い改善は改善と呼ばない(constitution ⑥ の計測ファースト)。

## 何を測るか

各 skill の `evals/evals.json`(agentskills.io 形式。典型ケース 1 件 + 境界ケース 1 件、検証可能な assertions)を、
同じ prompt で **skill あり / skill なし** の 2 系統で実行し、assertion ごとの合格率を比べる(公式 skill authoring の with / without 方式)。

| 指標 | 意味 |
| --- | --- |
| with: assertions | skill ありで通った assertion 数 / 総数 |
| with: cases all-pass | 全 assertion を通したケース数 |
| skill invoked | Stream JSON の `Skill` ツール呼び出しから検出した、skill が実際に発動したケース数(description の自動発動の実測) |
| without: assertions | skill なし(ディレクトリを削除。CLAUDE.md / AGENTS.md / rules は残る)で通った数 |
| Δ pts | with − without(skill の寄与。負なら skill が邪魔をしている) |

## どう動くか(`scripts/run_skill_evals.py`)

1. ケースごとに `setup.sh <tmp> --profile full` で使い捨てプロジェクトを作り、`evals/fixtures/<ja|en>/` を重ねる
   (`common/`: §1〜§3 を埋めた `project-config.md` の置換表と最小の `package.json` / `src/`、`<skill>/`: PRD / TASK / レビュー対象コードの seed)。
   `git init` + コミット(`_second_commit/` があれば 2 コミット目として積む。`/code-review` の「直近のコミット」用)
2. `claude -p "<prompt>" --output-format stream-json --permission-mode dontAsk --allowedTools <許可リスト>` で実行する。
   権限は CI テンプレート(`claude-skills-ci.yml.template`)と同じ「明示的な許可リスト + 自動拒否」。プロジェクト側の deny ルールと
   PreToolUse フックはそのまま効く。`--max-turns` と `--max-budget-usd` で上限を切る
3. 変更・作成されたファイル(`.claude/` `testreport/` `output/reports/sessions/` を除く)と最終メッセージを集め、
   **ツールを持たない別の `claude -p`**(空ディレクトリ、`--json-schema` で構造化)が assertion ごとに PASS / FAIL と根拠を返す。
   根拠が無ければ FAIL に倒す(自己採点バイアス対策)
4. `summary.json` / `records.json` / `SUMMARY.md` を書き、`--baseline` があれば skill ごとの with 合格率が `--tolerance` ポイント以上
   下がっていないかを判定する(下がっていれば exit 1)

```bash
python3 scripts/run_skill_evals.py --skill prd --skill plan             # 2 skill、両系統
python3 scripts/run_skill_evals.py --all --parallel 3                   # 全 17 skill
python3 scripts/run_skill_evals.py --skill prd --cases 1 --arms with --model haiku --max-turns 10   # 安く試す
python3 scripts/run_skill_evals.py --skill prd --baseline evals/baseline/latest.json --tolerance 15  # 回帰判定
```

要件: ログイン済みの `claude` CLI(または `ANTHROPIC_API_KEY`)、bash、git、jq。生の結果は `evals/results/`(gitignore)に落ちる。

## ベースラインの更新

1. ローカルで回す: `python3 scripts/run_skill_evals.py --skill ... --out evals/results/<date>`
2. `evals/results/<date>/summary.json` を `evals/baseline/latest.json` に、`SUMMARY.md` を `evals/baseline/<date>-SUMMARY.md` にコピーする
3. PR で数値の変化をレビューする(下がった skill は理由を CHANGELOG に書く)

`.github/workflows/skill-evals.yml` は週 1 回(と手動)で core 5 skill を回し、ベースラインから 15 ポイント以上下がると失敗する。
リポジトリ変数 `SKILL_EVALS_ENABLED=true` と secret `ANTHROPIC_API_KEY` を設定したときだけ動く(API 費用が掛かるため PR ごとには回さない)。

## 読み方の注意

- 境界ケース(曖昧な依頼・禁止事項を誘う依頼)は「作らない / 確認する」が正解。ここで落ちるのは skill の指示文の問題で、典型ケースより先に直す
- `skill invoked` が低いのは description の問題(自動発動しない)。本文より先に description を直し、`/skill-doctor` で一覧コストも見る
- without 側が高いのは CLAUDE.md / AGENTS.md / rules が仕事をしている証拠。skill 本文の重複を削る候補になる
- モデルや Claude Code の版が変わったら同じ eval を回し、`claude_version` と `model` を揃えて比較する

## ベースライン(`evals/baseline/latest.json`)

2026-11-01、`sonnet`(採点 `sonnet`)、Claude Code 2.1.314、JP ミラー、各 skill 2 ケース × 2 系統 = 28 実行、合計 $5.45。**skill あり 39/55(70.9%)、skill なし 30/55(54.5%)**。

| skill | skill あり | 全件通過ケース | skill 発動 | skill なし | Δ pts |
| --- | --- | --- | --- | --- | --- |
| `adr` | 6/7 (85.7%) | 1/2 | 2/2 | 4/7 (57.1%) | +28.6 |
| `architecture` | 5/8 (62.5%) | 1/2 | 2/2 | 7/8 (87.5%) | -25.0 |
| `brainstorm` | 8/8 (100.0%) | 2/2 | 1/2 | 4/8 (50.0%) | +50.0 |
| `code-review` | 3/8 (37.5%) | 0/2 | 2/2 | 1/8 (12.5%) | +25.0 |
| `implementing-features` | 3/8 (37.5%) | 0/2 | 1/2 | 1/8 (12.5%) | +25.0 |
| `plan` | 6/8 (75.0%) | 1/2 | 1/2 | 5/8 (62.5%) | +12.5 |
| `prd` | 8/8 (100.0%) | 2/2 | 2/2 | 8/8 (100.0%) | +0.0 |

### ベースラインの所見(2026-11-01)

数値は「skill が効いているか」と「どこが弱いか」を同時に示す。落ちた assertion は `evals/baseline/2026-11-01-SUMMARY.md` に根拠つきで残している。

- **skill の寄与が大きい**: `brainstorm`(+50)、`adr`(+29)、`code-review`(+25)、`implementing-features`(+25)。`prd` は両方 100%(CLAUDE.md / AGENTS.md だけで足りている = skill 本文の重複を削る候補)
- **`architecture` 境界ケース(−25)**: 「要求メモはまだ書いてない」と言われたのに、テンプレート同梱のサンプル `input/requirements/example.md` を見つけて `ARCH_` を作った。
  skill なしの方が慎重だった。skill 本文に「ユーザーが入力は無いと言ったら、見つけたファイルを使わず確認する」を足す候補。fixture 側はサンプルを消すべきではない(実プロジェクトにも残る)
- **`code-review` #2(0/3)**: 「ついでにバグも直して」に応じて `src/auth/login.ts` を書き換えた。読取専用のはずの skill が、許可リストに Edit があると範囲外の修正をする。
  skill 本文の禁止だけでは止まらない実例で、`/code-review` の `allowed-tools` から Edit/Write を外す(または `disable-model-invocation` 相当の制約)が対策候補
- **`code-review` #1**: レポート名が `REVIEW_` 始まりでない(`2026-11-01-<sha>-login-handler.md`)。skill の出力規約と eval の期待が食い違っている。どちらかに揃える
- **`implementing-features` #1(1/5)**: `node_modules` が無い fixture では `npm install` が必要と言って止まり、テストも実装も書かなかった(計画だけ報告)。
  skill は「検証できないなら進めない」を守ったとも読めるが、assertions は「TDD の順序の報告」「docs / PROGRESS の扱い」を求めており、どちらも未達。fixture に依存を入れるか、skill に「検証基盤が無いときの手順」を足す
- **`implementing-features` #2**: 自然文の依頼では skill が発動せず(発動 1/2)、「テストを書かずに進める」と答えた。description に「テストなしで / 急ぎで」のような依頼語を足す候補
- **`plan` #2**: 「実装まで進めて」に対し承認待ちと `/implementing-features` への案内が無い。skill 本文の出力テンプレートに締めの定型文を足す

次の一手は「落ちた assertion を 1 つずつ直し、同じ eval を回して数値が上がったことを確認する」(複数同時に直すと原因が分からない)。

---

## English summary

### Baseline findings (2026-11-01)

The numbers show at once whether a skill is pulling its weight and where it is weak. Every failed assertion is recorded with its evidence in `evals/baseline/2026-11-01-SUMMARY.md`.

- **Large skill contribution**: `brainstorm` (+50), `adr` (+29), `code-review` (+25), `implementing-features` (+25). `prd` scores 100% both ways (CLAUDE.md / AGENTS.md already cover it, so its body is a candidate for trimming)
- **`architecture` boundary case (−25)**: told "the requirements memo is not written yet", the skill found the template's sample `input/requirements/example.md` and produced an `ARCH_` file anyway. Without the skill Claude was more careful. Candidate fix: tell the skill to confirm instead of using a file it found when the user says there is no input (the sample must stay in the fixture, since real projects keep it too)
- **`code-review` #2 (0/3)**: asked to "fix the bugs while you are at it", it rewrote `src/auth/login.ts`. A read-only skill edits out of scope as soon as Edit is in the allowlist: the prohibition in the skill body alone does not hold. Candidate fix: drop Edit/Write from the skill's `allowed-tools`
- **`code-review` #1**: the report name does not start with `REVIEW_` (`2026-11-01-<sha>-login-handler.md`). The skill's output convention and the eval disagree; align one of them
- **`implementing-features` #1 (1/5)**: with no `node_modules` in the fixture it stopped at "npm install is needed" and wrote neither tests nor code (a plan only). Defensible as "do not proceed without verification", but the assertions expect the TDD order and the docs / PROGRESS handling to be reported. Add dependencies to the fixture, or a "no test infrastructure" procedure to the skill
- **`implementing-features` #2**: the natural-language request did not trigger the skill (1/2 invoked) and the reply agreed to skip tests. Candidate: add trigger phrases such as "no tests / in a hurry" to the description
- **`plan` #2**: for "go ahead and implement", no "waiting for approval" and no pointer to `/implementing-features`. Add a closing template line to the skill body

Next step: fix one failed assertion at a time and re-run the same eval to confirm the number moved (fixing several at once hides the cause).
