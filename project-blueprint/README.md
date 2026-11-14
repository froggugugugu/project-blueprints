# Project Blueprint

Claude Code と Codex のための AI協調開発環境テンプレート。どちらか片方でも、両方を対等に併用しても使える。

プロジェクト固有の「人間の決定事項」を **`project-config.md`の1ファイルに集約**し、
ルーティング・ストア一覧・データモデル等の設計成果物はAIが自動生成・メンテナンスする。

---

## ミニマルスタート（5分で試す）

すべてのセクション・チーム・スキルを使う必要はない。**3ステップで今すぐ始められる。**

### Step 1: コピー

```bash
bash setup.sh /path/to/your-project                  # Claude Code と Codex の両方(既定)
bash setup.sh /path/to/your-project --agent claude   # Claude Code だけ
bash setup.sh /path/to/your-project --agent codex    # Codex だけ
```

> さらに軽くしたい場合は `--profile minimal` を足すと skills 5 / agents 2 / hooks 2 だけを導入できる(詳細は下記「プロファイル」参照)。

### Step 2: project-config.md に3セクションだけ記入

```markdown
## §1. プロジェクト基本情報
プロジェクト名: MyApp
概要: TODOアプリ
言語: 日本語

## §2. 技術スタック
- React 19 + TypeScript 5
- Vite 6

## §3. コマンド
- dev: npm run dev
- test: npm run test
- build: npm run build
```

> 残り10セクションは空欄のままで動作する。必要に応じて段階的に追記すればよい。

### Step 3: スキルを1つ試す

```text
/plan ログイン機能の設計       # Claude Code
$plan ログイン機能の設計       # Codex
```

これだけで AI が `project-config.md` を読み取り、構造化された設計ドキュメントを生成する。
以降の例は Claude Code の `/name` で書く。Codex では `$name` と読み替える。

### 段階的に広げる

| やりたくなったこと | 次のステップ |
|---|---|
| PRD → 設計 → 実装まで全部 AI に任せたい | `project-config.md` §4 を追記 → `.claude/teams/TEAM_PJM.md input/requirements/REQ_001.md` |
| 実装だけ手伝ってほしい | `/implementing-features ログイン機能を追加` |
| コードレビューしてほしい | `/code-review src/features/auth/` |
| チームで品質保証したい | `.claude/teams/TEAM_QA.md src/` |
| MCP サーバーを追加して AI のツールを拡張したい | `cp .mcp.json.template .mcp.json` → 必要な MCP サーバーを記入してコミット(プロジェクト共有) |

> 詳細なセットアップ手順・全機能については以降のセクションを参照。

---

## セットアップ手順（詳細）

### 前提条件

| 必要なもの | 用途 | 確認 |
| --- | --- | --- |
| Claude Code 2.1.314 以上(`--agent claude` / `both`) | `onFailure: block`（2.1.295）、`blockWritesOutsideWorkingDirectories`（2.1.314）、Task ツールの env 有効化 | `claude --version` |
| Codex CLI 0.162 以上(`--agent codex` / `both`) | フック(`.codex/hooks.json`)、権限プロファイル、`.agents/skills/` の読み込み | `codex --version` |
| bash 3.2 以上 + git | `setup.sh`（導入と `--upgrade`）、`migrate.sh`、フック | macOS 標準の bash で動く |
| jq | 全フックが JSON の読み書きに使う（無いと `safety-check.sh` が最重要パターン以外をスキップする） | `brew install jq` / `apt-get install jq` |
| python3 | テンプレート元リポジトリの `scripts/validate-harness.sh` だけ（導入先では不要） | `python3 --version` |

Windows は WSL2 か Git Bash で上記を揃える。Git Bash ではシンボリックリンクを作れないことがあり、その場合 `setup.sh` はコピーに切り替える(下記「共通の核とリンク」)。

### 方法A: setup.sh で1コマンドセットアップ（推奨）

```bash
bash setup.sh /path/to/your-project
```

これだけで以下がすべて完了する:
- `.agents/`(共通の核: skill・フック・ルール・品質ゲート)の配置
- `.claude/`(Claude Code 用アダプタ)と `.codex/`(Codex 用アダプタ)の配置。`--agent` で片方だけにできる
- `docs/`、`input/`、`output/`、`testreport/`、`project-config.md` の配置(既存ファイルは上書きしない)
- `AGENTS.md`(ツール共通ルール)と `CLAUDE.md` のプロジェクトルートへの配置(既存の `AGENTS.md` は上書きせず `AGENTS.blueprint.md` を、既存の `CLAUDE.md` は上書きせず `CLAUDE.md.blueprint-new` を横に置く)
- `constitution.md`・`REVIEW.md`(Claude の Code Review 用の審査基準)・`.mcp.json.template`・`.github/`(ワークフローテンプレート)の配置(既存ファイルは上書きしない)
- `.claude/skills/` と `.claude/rules/` から `.agents/` へのリンク作成、`.claude/settings.local.json` を雛形から生成(無い場合のみ)
- `.gitignore` への `testreport/` などローカル状態の追記
- 既存の `.agents/` `.claude/` `.codex/` がある場合は `<名前>.bak/` に自動バックアップ(`.bak/` が既にあれば消さず、`<名前>.bak.<日時>/` に置く)
- `.agents/blueprint-manifest.txt`（導入した版・エージェント・ファイルごとのハッシュ）を記録。`--upgrade` の基準になる

導入済みのプロジェクトにもう一度導入することはできない(足した skill や編集を退避先へ回してしまうため、`setup.sh` が止める)。版の追従は `--upgrade`、
アダプタの追加は `--upgrade --agent both`、リンクの張り直しは `--relink` を使う。`.agents` `.claude` `.codex` のどれかがシンボリックリンクの場合と、
ターゲットがテンプレート自身の場合も、何も変更せずに止まる。

#### エージェント（`--agent`）

| 値 | 入るもの | 起動後の最初の一歩 |
| --- | --- | --- |
| `both`（デフォルト） | `.agents/` + `.claude/` + `.codex/` + `CLAUDE.md` | 下の両方 |
| `claude` | `.agents/` + `.claude/` + `CLAUDE.md` | `claude` を起動し `/plan ...` |
| `codex` | `.agents/` + `.codex/` | `codex` を起動してプロジェクトを信頼し、`/hooks` でフックを確認して信頼してから `$plan ...` |

Codex はプロジェクトを信頼するまで `.codex/` の設定を読まず、フックは `/hooks` で信頼するまで実行しない(フックを更新したあとも同じ)。
あとからもう一方を足すには `bash setup.sh <dir> --upgrade --agent both`。安全装置の対応関係と差は `.agents/guardrails.md` の「エージェント別の対応」。

#### 共通の核とリンク（`--links` / `--relink`）

skill・フック・ルールの原本は `.agents/` に 1 つだけ置く。Codex は `.agents/skills/` を直接読む。
Claude Code は `.claude/skills/` と `.claude/rules/` しか読まないため、`setup.sh` が項目ごとにシンボリックリンクを作る。

| やりたいこと | 操作 |
| --- | --- |
| skill やルールを足した・消した | `.agents/skills/<名前>/` か `.agents/rules/<名前>.md` を編集し、`bash setup.sh <dir> --relink` |
| サンプルのルールを有効にする | `cp .agents/rules/language-typescript.md.example .agents/rules/language-typescript.md` のあと `--relink` |
| シンボリックリンクを使えない | `--links copy` で導入する。編集は `.agents/` 側だけで行い、`--relink` で `.claude/` 側へ反映する |

#### プロファイル（段階的インストール）

`--profile` オプションで導入する skill・agent・フックの範囲を選べる（省略時は `full`。`--agent` と組み合わせられる）:

| プロファイル | skills | agents | hooks | teams | 用途 |
| --- | --- | --- | --- | --- | --- |
| `minimal` | 5 | 2 | 2 | なし | まず最速で試す軽量構成 |
| `standard` | 17 | 9 | 18 | なし | チーム機能以外フル |
| `full`（デフォルト） | 17 | 9 | 18 | 6 | 現行と同じフル構成 |

```bash
bash setup.sh /path/to/your-project --profile minimal
bash setup.sh /path/to/your-project --profile standard
```

`minimal` は `brainstorm` / `prd` / `plan` / `implementing-features` / `code-review` の中核5 skillと、
`safety-check.sh` / `protect-files.sh` の最低限のガードレールのみを導入する軽量構成。
セーフガード系フック（`session-start.sh` 等）も間引かれる点に注意。

> project-config.md の「ミニマル/推奨/フル」（§記入量の目安）とは**別の独立した軸**。
> 例えば `--profile minimal` で導入しても project-config.md はフルまで記入して構わない。

#### 更新（`--upgrade`）

導入済みプロジェクトをテンプレートの新しい版に追従させる。導入時に書かれた `.agents/blueprint-manifest.txt`（版・プロファイル・エージェント・ファイルごとのハッシュ）と比べ、差分だけを適用する。

```bash
git -C /path/to/project-blueprints pull                   # テンプレートを更新
bash setup.sh /path/to/your-project --upgrade --dry-run   # 計画だけ表示
bash setup.sh /path/to/your-project --upgrade             # 適用
```

| 状態 | 動作 |
| --- | --- |
| 導入後に手を入れていないファイル | 新版で上書き |
| 手を入れたファイル | 触らず、新版を `<path>.blueprint-new` として横に置く（`diff` で統合して削除する）。前回の `.blueprint-new` が残っていて内容が違えば `.blueprint-new.old` に退避する |
| テンプレートに増えたファイル | 追加する（プロファイルの剪定は維持） |
| ローカルで削除したファイル | 復活させない |
| `project-config.md` / `docs/` / `input/` / `output/` / `settings.local.json` | 触らない（`project-config.md` のテンプレートが変わったときは警告だけ出す） |

観測フックのログは `bash .agents/scripts/harness-stats.sh --since 30` で集計できる。

#### 0.x からの移行（`migrate.sh`）

0.x で導入したプロジェクトは skill もフックも `.claude/` の下にあり、`--upgrade` では更新できない。先に `migrate.sh` で 1.0 の配置へ移す。

```bash
git -C /path/to/project-blueprints pull                    # 1.0 のテンプレート(git の履歴つきで clone したもの)
bash migrate.sh /path/to/your-project --dry-run            # 一時コピー上で最後まで実行し、結果だけ表示
bash migrate.sh /path/to/your-project                      # 適用(未コミットの変更があると止まる)
bash migrate.sh /path/to/your-project --rollback           # 取り消し(バックアップを消すまで可能)
```

| 段階 | 行うこと |
| --- | --- |
| 分類 | 各ファイルが「テンプレートのまま」か「手で変更あり」かを決める。0.x は導入時の記録を持たないため、テンプレートの git 履歴にある内容と照合する |
| 退避 | `.blueprint-migrate-backup/` に `.claude/` と書き換えるファイルを保存する(`.gitignore` に追加される) |
| 移動 | `.claude/{skills,hooks,rules,scripts,learnings,tasks}` と `guardrails.md` / `quality-gates.md` / `pitfalls.md` を `.agents/` へ。自分で足した skill やフックも一緒に移る |
| 参照修正 | `.claude/hooks/...` などの参照を `.agents/...` に書き換える。対象は `.agents/` `.claude/` `CLAUDE.md` `AGENTS.md` `project-config.md` `constitution.md` `docs/` `.github/` `.gitignore`。`settings.json` に登録した独自フックのパスもここで直る |
| 更新 | `setup.sh --upgrade` を呼び、未変更ファイルを 1.0 の内容に置き換え、Codex 用アダプタなどを足す。手で変えたファイルは上書きせず `<path>.blueprint-new` を横に置く |

| オプション | 用途 |
| --- | --- |
| `--agent claude` | Codex 用アダプタを足さず、Claude Code だけのまま移行する(既定は `both`) |
| `--assume-pristine` | ハーネスを一度も編集していないとき、またはテンプレートに git 履歴が無いとき。全ファイルを 1.0 で上書きする(元の版はバックアップに残る) |
| `--allow-dirty` | 未コミットの変更があっても進める(非推奨) |

途中で失敗した場合と、Ctrl-C などで中断した場合は、自動で移行前の状態へ戻る(戻し切れなかったときはバックアップを残して知らせる)。
移行後は `git status` で結果を確認し、`.blueprint-new` を統合して消し、Claude Code を起動し直す(フックのパスが変わるため)。

自動で書き換えない場所に旧パスが残っていれば、最後に一覧で知らせる(`package.json`・`Makefile`・git フックの設定・ルートの `README.md` などから
`.claude/scripts/` や `.claude/hooks/` を呼んでいる場合)。`~/.claude/skills/` のようなホーム側のパスは移動対象ではないので書き換えない。
`.claude` がシンボリックリンクのプロジェクトは、リンク先の実体を壊さないよう移行を始めない(実体のディレクトリにしてから実行する)。

### 方法B: 手動コピー

> 手動コピーは常に `full` 相当になり、manifest も書かれない(あとで `--upgrade` を使えない)。特別な理由が無ければ「方法A」を使う。

```bash
cd /path/to/new-project
B=/path/to/project-blueprints/project-blueprint

cp -r "$B/.agents" .agents                      # 共通の核
cp -r "$B/.claude" .claude                      # Claude Code を使う場合
cp -r "$B/.codex" .codex                        # Codex を使う場合
cp -r "$B/docs" "$B/input" "$B/output" "$B/testreport" .
cp "$B/project-config.md" "$B/constitution.md" "$B/AGENTS.md" "$B/.mcp.json.template" .
cp -r "$B/.github" .github

# Claude Code 用: CLAUDE.md をルートへ移し、skill とルールを .agents/ へリンクする
mv .claude/CLAUDE.md CLAUDE.md
rm -f .claude/settings.minimal.json .codex/hooks.minimal.json
mkdir -p .claude/skills .claude/rules
for d in .agents/skills/*/; do ln -s "../../.agents/skills/$(basename "$d")" ".claude/skills/$(basename "$d")"; done
for f in .agents/rules/*.md; do [ "$(basename "$f")" = README.md ] || ln -s "../../.agents/rules/$(basename "$f")" ".claude/rules/$(basename "$f")"; done
chmod +x .agents/hooks/*.sh .agents/hooks/lib/*.sh .agents/scripts/*.sh
```

### 2. project-config.mdを記入

> 記入例として [project-config.sample.md](project-config.sample.md) を参照（タスク管理アプリを題材にした全セクション記入済みサンプル）。

**必須セクション**（最低限これだけ埋めれば動作する）:

| セクション | 内容 |
| --- | --- |
| 1. プロジェクト基本情報 | 名前・概要・言語 |
| 2. 技術スタック | 使用するフレームワーク・ライブラリ |
| 3. コマンド | 開発・テスト・ビルドコマンド |

**推奨セクション**（記入すると品質が向上する）:

| セクション | 内容 |
| --- | --- |
| 4. アーキテクチャ | パターン・依存ルール |
| 6. 品質基準 | カバレッジ目標・TDD有無 |
| 7. デザインシステム | 参照するデザインガイド |
| 11. 注意事項 | フレームワーク固有の落とし穴（AIも追記） |

#### 段階的記入ガイド

すべてのセクションを一度に埋める必要はない。目的に応じて段階的に記入する:

| ステップ | 記入セクション | 利用可能になるスキル |
| -------- | -------------- | -------------------- |
| 最小構成 | §1 + §2 + §3 | `/prd`, `/plan` |
| 推奨構成 | + §4 | `/architecture`, `/implementing-features`, 全チーム |
| フル構成 | 全セクション | 全スキル（`/security-scan`, `/legal-check` 等） |

§6（品質基準）はスキルの前提条件ではないが、TDD・カバレッジ目標・品質ゲートの有効化に使用する。
未記入のオプションセクションはスキル実行時にスキップされる。

### 3. .gitignore に追記

> `setup.sh` を使った場合はこの手順は不要（自動で追記される）。

`testreport/` はツール直接出力（HTML/JSON/LCOV等）であり、リポジトリには含めない:

```gitignore
# ツール直接出力（AI生成の生データ）
testreport/
```

### 4. 権限設定をカスタマイズ

```bash
cp .claude/settings.local.json.template .claude/settings.local.json
```

### 5. 動作確認（ハローワールド）

セットアップが正しく完了したか、以下の最小手順で確認する:

```text
# スキル単体で動作確認（project-config.md の§1〜§3 が記入済みであること）
/plan プロジェクトの初期セットアップ状況を確認

# 正常に動作すれば、project-config.md と docs/ の参照が解決できている
```

期待される動作:

- AIが `project-config.md` と `docs/` を読み取り、現状のプロジェクト構成を分析する
- 出力として影響調査・タスク分解が提示される
- エラーが出る場合はファイルのコピー漏れや `project-config.md` の未記入セクションを確認する

### 6. docs/ の初回生成（任意）

セットアップ直後、`docs/` 配下はスタブ（空テンプレート）状態。
以下のスキル実行時に自動生成される:

| ファイル | 生成トリガー | 必要な project-config.md |
| -------- | ------------ | ----------------------- |
| `docs/architecture.md` | `/architecture` | §1〜§4 |
| `docs/project.md` | `/architecture` or `/implementing-features` | §1〜§3（最小）、§5,§7,§11〜§12も参照 |
| `docs/data-model.md` | `/implementing-features`（初回実装時） | §2, §5 |
| `docs/development-patterns.md` | `/implementing-features`（初回実装時） | §2, §7, §11 |

> **スタブのままでもスキルは動作する。** 各スキルは `docs/` がスタブの場合、
> `project-config.md` を直接参照してフォールバックする。
> PJMチームを使う場合は Phase 2〜4 で自動的に生成される。

### 7. Claude Code と Codex、その他のエージェント（任意）

Claude Code と Codex は対等に扱う。どちらも `AGENTS.md`(ツール共通ルール)と `.agents/`(skill・フック・ルール)を読み、単独で全工程を回せる。
両方を使うときは、工程ごとの担当を `project-config.md` §13.7 に記入する(例: 実装した側と別のエージェントがレビューと検証を担当する)。

| | Claude Code | Codex |
| --- | --- | --- |
| 指示ファイル | `CLAUDE.md`(`@AGENTS.md` を取り込む) | `AGENTS.md` |
| skill の起動 | `/name` | `$name` |
| 設定 | `.claude/settings.json` | `.codex/config.toml` + `.codex/hooks.json` + `.codex/rules/` |
| サブエージェント | `.claude/agents/*.md` | `.codex/agents/*.toml` |
| team / saved workflow | あり(`full` プロファイル) | なし(同じ skill を順に実行する) |

それ以外のエージェントは補助として `AGENTS.md` を読む。§13.7 で `yes` にしていなければ読取専用で振る舞う。

| エージェント | `AGENTS.md` を読ませる方法 |
| --- | --- |
| Cursor | 既定で読む |
| GitHub Copilot（VS Code） | 設定 `chat.useAgentsMdFile: true` |
| Gemini CLI | `.gemini/settings.json` に `{"context": {"fileName": ["AGENTS.md"]}}`（既定は `GEMINI.md`） |

> フックと deny ルールが効くのは Claude Code と Codex だけである。補助エージェントに書込を許すなら、禁止事項を CI や git フックでも強制する。

---

## クイックスタート（セットアップ後）

セットアップ完了後、以下の手順で開発を開始する。

> 初回のセッションで `/auto-mode-setup` を実行する(v2.1.283 以降、auto mode は全プランで既定の権限モード)。
> プロジェクトと直近のセッションを読んで分類器向けの環境定義を下書きし、`~/.claude/settings.json` に保存する(project 設定からは読まれない)。
> 指示ファイルの棚卸しは `/doctor prompt-audit`、skill のコストは `/skill-doctor` で確認できる。

### PJMチーム（フルライフサイクル）

```text
1. input/requirements/ に要求メモを配置（例: input/requirements/REQ_001.md）
2. Claude Codeで以下を実行:

   .claude/teams/TEAM_PJM.md input/requirements/REQ_001.md

   # 自律モード（ゲート承認をPJMに委任、最終報告のみ人間に提示）
   .claude/teams/TEAM_PJM.md input/requirements/REQ_001.md --auto

3. output/ に生成された成果物をレビュー・承認
```

### 個別スキル（チームなし）

スキル単体でも利用可能。引数は省略可能:

```text
/prd input/requirements/REQ_001.md
/plan ユーザー認証機能の設計
/implementing-features output/tasks/TASK_auth.md
/code-review src/features/assignment/
```

### 専門チーム

特定フェーズに特化したチームも利用可能。引数は省略可能:

```text
.claude/teams/TEAM_FEATURE.md output/tasks/TASK_auth.md
.claude/teams/TEAM_PLANNING.md input/requirements/REQ_001.md
.claude/teams/TEAM_QA.md src/features/assignment/
.claude/teams/TEAM_REFACTOR.md src/features/assignment/
```

---

## コンセプト

```text
┌─────────────────────────────────────────────────────────┐
│  人間のインプット                                         │
│                                                         │
│  input/requirements/ .... 要求メモ・要件メモ             │
│  project-config.md ...... 技術選定・品質基準・ポリシー    │
│                                                         │
└────────────────────────────┬────────────────────────────┘
                             │ AI が処理（PJMチーム）
                             ▼
┌─────────────────────────────────────────────────────────┐
│  AIのアウトプット（人間がレビュー）                        │
│                                                         │
│  output/prd/ ............ PRD（要求仕様書）               │
│  output/design/ ......... アーキテクチャ設計書            │
│  output/tasks/ .......... タスク分解・実装指示書          │
│  output/reports/ ........ 品質レポート                    │
│    review/ .............. コードレビュー                  │
│    test/ ................ テスト結果                      │
│    security/ ............ セキュリティスキャン            │
│    legal/ ............... 法務チェック                    │
│                                                         │
│  testreport/ ............ ツール直接出力（.gitignore対象）│
│    coverage/ ............ ユニットテストカバレッジ        │
│    e2e/ ................. E2Eテストレポート               │
│    security/ ............ セキュリティスキャン生データ    │
│                                                         │
│  docs/ .................. 技術ドキュメント（自動生成）    │
│                                                         │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  汎用（そのまま再利用）                                   │
│                                                         │
│  AGENTS.md .................... 共通ルール（ツール非依存）│
│  .claude/CLAUDE.md ............ 開発ガイド（Claude Code） │
│  .agents/hooks/ ............... 安全フック（多層防御）    │
│  .agents/skills/ .............. 17個のスキル定義         │
│  .claude/teams/ ............... 6チーム定義              │
│  .agents/tasks/ ............... タスク指示書テンプレート  │
│  .claude/settings.json ........ プラグイン・フック設定   │
│  .claude/settings.local.json .. 権限設定テンプレート     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## ファイル構成

```text
project-blueprint/
│
├── README.md                              ← このファイル
├── setup.sh                               ← 1コマンドセットアップスクリプト（導入 / --upgrade / --relink）
├── migrate.sh                             ← 0.x の配置（すべて .claude/ 配下）から 1.0 への移行スクリプト
├── AGENTS.md                              ← [汎用] ツール共通の開発ルール（Codex / Cursor / Copilot 等も読む）
├── project-config.md                      ← [人間+AI] 設定ファイル（13セクション）
├── project-config.sample.md               ← 記入済みサンプル（タスク管理アプリ）
├── constitution.md                        ← [人間] 不変原則 7 つ（hash で改変を検知）
├── .mcp.json.template                     ← [カスタマイズ] プロジェクト共有の MCP サーバー設定（.mcp.json にリネームして有効化）
├── .github/                               ← [汎用] GitHub Actions テンプレート（.template を外して有効化）
│   ├── CLAUDE_REVIEW_SETUP.md               導入手順
│   └── workflows/                           claude-review / claude-skills-ci / claude-scheduled-audit
│
├── input/                                 ← [人間] インプット
│   ├── README.md                            使い方ガイド
│   └── requirements/                        要求メモ置き場
│
├── output/                                ← [AI生成] アウトプット（人間がレビュー）
│   ├── README.md                            成果物の説明
│   ├── prd/                                 PRD
│   ├── design/                              アーキテクチャ設計書
│   ├── tasks/                               タスク分解
│   └── reports/                             品質レポート
│       ├── review/                            コードレビュー
│       ├── test/                              テスト結果
│       ├── security/                          セキュリティスキャン
│       └── legal/                             法務チェック
│
├── testreport/                            ← [AI生成] ツール直接出力（.gitignore対象）
│   ├── coverage/                            ユニットテストカバレッジ（HTML/LCOV）
│   ├── e2e/                                 E2Eテストレポート・トレース
│   └── security/                            セキュリティスキャン生データ
│
├── .agents/                               ← [汎用] 共通の核（Claude Code と Codex が共有。原本はここに 1 つだけ）
│   ├── .constitution.sha256               ← [自動] constitution.md の hash
│   ├── guardrails.md                      ← [汎用] 安全機構の全体像
│   ├── quality-gates.md                   ← [汎用] 5 つの品質ゲートの基準
│   ├── pitfalls.md                        ← [汎用] 失敗パターン 31 件と対策
│   ├── rules/                             ← [汎用] ルール（常時 1 本 + パス限定 3 本 + サンプル 3 本）
│   │   ├── git-conventions.md               常時 load: Git・コミット規約
│   │   ├── document-management.md           docs/・output/ 編集時: ドキュメント管理
│   │   ├── workflow-advanced.md             ソース編集時: 高度なワークフロー指針
│   │   ├── harness-authoring.md             ハーネス編集時: 執筆規約
│   │   └── *.md.example                     言語別・パス別サンプル（.example を外して有効化）
│   │
│   ├── learnings/                         ← [汎用] 成功パターンの記録（README.md / TEMPLATE.md / 記入例）
│   ├── hooks/                             ← [汎用] 安全フック（多層防御・18本）
│   │   ├── lib/codex-adapter.sh             Codex の入力を共通形に直して同じフックを呼ぶ
│   │   ├── safety-check.sh                  危険コマンドブロック（PreToolUse）
│   │   ├── protect-files.sh                 機密ファイル・設定ファイル保護（PreToolUse）
│   │   ├── scan-harness.sh                  ハーネス自己SAST・危険skillブロック（PreToolUse）
│   │   ├── user-prompt-submit.sh            機密パターン検出（UserPromptSubmit）
│   │   ├── session-start.sh                 セッション開始チェック・コンパクト後の再注入（SessionStart）
│   │   ├── session-end.sh                   セッション終了記録（SessionEnd）
│   │   ├── commit-quality.sh                コミット品質チェック（PostToolUse）
│   │   ├── console-warn.sh                  デバッグコード検出（PostToolUse）
│   │   ├── verify-gate.sh                   検証ゲート: 編集後の未検証終了・完了マークを検知（PostToolUse/Stop/TaskCompleted）
│   │   ├── permission-denied-log.sh         auto mode の拒否記録（PermissionDenied）
│   │   ├── config-guard.sh                  防御層を弱める設定変更の阻止・記録（ConfigChange）
│   │   ├── scope-guard.sh                   書込可能 agent の書込範囲を強制（agent frontmatter）
│   │   ├── post-failure-log.sh              ツール失敗ログ記録（PostToolUseFailure）
│   │   ├── subagent-audit.sh                サブエージェント実行監査（SubagentStart/Stop）
│   │   ├── pre-compact-backup.sh            コンパクト前トランスクリプト退避（PreCompact）
│   │   ├── post-compact-restore.sh          コンパクト後の要約保全（PostCompact）
│   │   ├── notify-claude.sh                 完了・確認プッシュ通知（Stop/Notification）
│   │   └── ntfy-topic.txt                   notify-claude.sh の通知先トピック（要書き換え）
│   │
│   ├── scripts/                           ← [汎用] 観測の集計
│   │   └── harness-stats.sh                 testreport/ の JSONL（拒否・失敗・設定変更・rule の load・subagent）を 1 枚に集計
│   │
│   ├── skills/                            ← [汎用] 17スキル定義（各 SKILL.md + evals/evals.json + 必要に応じて references/）
│   │   ├── brainstorm/SKILL.md              前提整理（/prd前段）
│   │   ├── prd/SKILL.md                     PRD生成
│   │   ├── architecture/SKILL.md            アーキテクチャ設計
│   │   ├── plan/SKILL.md                    設計・計画
│   │   ├── adr/SKILL.md                     設計判断記録（ADR）
│   │   ├── implementing-features/SKILL.md   TDD実装
│   │   ├── ui-ux-design/SKILL.md            UI/UX設計
│   │   ├── hig-compliance/SKILL.md          HIG準拠チェック
│   │   ├── design-system-audit/             デザイントークン監査
│   │   │   ├── SKILL.md
│   │   │   └── references/                    監査チェックリスト・比率参照
│   │   ├── e2e-testing/SKILL.md             E2Eテスト
│   │   ├── code-review/SKILL.md             コードレビュー
│   │   ├── security-scan/                   セキュリティスキャン
│   │   │   ├── SKILL.md
│   │   │   └── SETUP_GUIDE.md                 ツール導入ガイド
│   │   ├── legal-check/SKILL.md             IT法務チェック
│   │   ├── performance/SKILL.md             パフォーマンス最適化
│   │   ├── refactoring/SKILL.md             リファクタリング
│   │   ├── review-fix/SKILL.md              PRレビュー指摘自動修正
│   │   └── harness-refine/SKILL.md          ハーネス自己点検・補正
│   │
│   └── tasks/                             ← [汎用] タスクテンプレート
│       ├── TASK_TEMPLATE.md                 機能開発指示書
│       ├── TASK_REVIEW_TEMPLATE.md          レビュー指示書
│       ├── LESSONS_TEMPLATE.md              学びの記録テンプレート
│       └── PROGRESS_TEMPLATE.md             複数セッションの進捗引き継ぎノート
│
├── .claude/                               ← [汎用] Claude Code 用アダプタ（skills/ と rules/ は setup.sh が .agents/ へリンクする）
│   ├── CLAUDE.md                          ← [汎用] 開発ガイド（Claude Code 固有。@AGENTS.md を取り込む）
│   ├── settings.json                      ← [汎用] プラグイン・フック設定
│   ├── settings.local.json.template       ← [カスタマイズ] 権限設定テンプレート（setup.sh が自動生成）
│   ├── managed-settings.example.json      ← [参照用] 組織ポリシー（deny / sandbox / OTel）の例
│   ├── settings.minimal.json              ← [汎用] minimal プロファイル用設定（setup.sh が差し替え）
│   ├── statusline.sh                      ← [汎用] 現在の出力スタイルとフェーズを表示
│   ├── permissions-guide.md               ← [汎用] 権限設計・auto mode の指針
│   ├── agents/                            ← [汎用] サブエージェント 9 種 + README.md（使い分け）
│   │                                        explorer / researcher / planner / security-reviewer /
│   │                                        performance-analyst / doc-synchronizer / doc-writer / test-writer
│   │
│   ├── output-styles/                     ← [汎用] フェーズ別出力スタイル 4 種（phase-prd / design / implementation / review）
│   ├── teams/                             ← [汎用] 6チーム定義
│   │   ├── README.md                        チーム利用ガイド
│   │   ├── TEAM_PJM.md                      フルライフサイクル管理
│   │   ├── TEAM_FEATURE.md                  機能開発
│   │   ├── TEAM_QA.md                       品質保証
│   │   ├── TEAM_PLANNING.md                 設計フェーズ
│   │   ├── TEAM_REFACTOR.md                 リファクタリング
│   │   └── TEAM_DESIGN.md                   デザインチーム
│   │
│   └── workflows/                         ← [汎用] saved workflow（full プロファイルのみ）
│       ├── review-sweep.js                  4 観点並列レビュー + MUST 指摘の反証検証
│       └── skill-eval.js                    skill の evals を with / without で実行
│
├── .codex/                                ← [汎用] Codex 用アダプタ
│   ├── config.toml                        ← [汎用] 承認方式・権限プロファイル（シークレットの読取禁止）・Codex 向けの読み替え
│   ├── hooks.json                         ← [汎用] 共有フックの登録（lib/codex-adapter.sh 経由）
│   ├── hooks.minimal.json                 ← [汎用] minimal プロファイル用（setup.sh が差し替え）
│   ├── rules/default.rules                ← [汎用] 禁止・確認するコマンド（.claude/settings.json の deny / ask に対応）
│   └── agents/                            ← [生成物] サブエージェント 9 種（.claude/agents/*.md から生成。直接編集しない）
│
└── docs/                                  ← [AI生成] 技術ドキュメント
    ├── project.md                           ルーティング・ストア・コマンド
    ├── architecture.md                      ディレクトリ構成・テスト
    ├── data-model.md                        スキーマ・バリデーション
    └── development-patterns.md              コード規約・落とし穴
```

### 人間 vs AIの責任分担

| 領域 | 人間が作成 | AIが生成 |
| ---- | ---------- | --------- |
| 要求・要件 | `input/requirements/` に配置 | `output/prd/` にPRD生成 |
| 技術選定・ポリシー | `project-config.md` に記入 | バージョン変更時に自動更新 |
| アーキテクチャ設計 | — | `output/design/` に生成 |
| タスク分解 | — | `output/tasks/` に生成 |
| 実装 | — | ソースコードを直接変更 |
| 品質レポート | — | `output/reports/` に生成 |
| ツール直接出力 | — | `testreport/` に出力（.gitignore対象） |
| 技術ドキュメント | — | `docs/` に自動生成 |

---

## チームとスキル

### チーム一覧

| テンプレート | 用途 | メンバー | スキル数 |
| --- | --- | --- | --- |
| **`TEAM_PJM.md`** | **フルライフサイクル管理（推奨）** | **6名** | **13/17** |
| `TEAM_FEATURE.md` | 機能開発・バグ修正 | 5名 | 5 |
| `TEAM_QA.md` | 品質保証・監査 | 5名 | 5 |
| `TEAM_PLANNING.md` | 設計フェーズ | 4名 | 3 |
| `TEAM_REFACTOR.md` | リファクタリング | 4名 | 5 |
| `TEAM_DESIGN.md` | デザイン・UI一貫性 | 5名 | 4 |

チーム選定ガイド・ワークフロー詳細・起動パターン・スキルカバレッジは `.claude/teams/README.md` を参照。

### スキル一覧（全17スキル）

全スキルは引数を省略可能。省略時はユーザーに対話的に確認する。
読み取り専用スキルは`context: fork`（会話コンテキストのコピーで実行）かつ`allowed-tools`でツール制限済み。

| スキル | コマンド | モード | project-config.md更新 |
| ------ | -------- | ------ | ---------------------- |
| Brainstorm | `/brainstorm <要求メモ>` | 読み取り専用 | — |
| PRD | `/prd <ファイルパス>` | 読み取り専用 | — |
| Architecture | `/architecture <ファイルパス>` | 読み取り専用 | — |
| Plan | `/plan <説明 or ファイルパス>` | 読み取り専用 | §11を更新可 |
| ADR | `/adr <判断タイトル or 指示>` | 読み書き | — |
| Implementing Features | `/implementing-features <タスクファイル or 指示>` | 読み書き | §2, §3, §11を更新 |
| UI/UX Design | `/ui-ux-design <対象ファイル or 指示>` | レビュー/実装 | — |
| HIG Compliance | `/hig-compliance <対象ディレクトリ or 指示>` | 読み書き | — |
| Design System Audit | `/design-system-audit <対象ディレクトリ or 指示>` | 読み書き | — |
| E2E Testing | `/e2e-testing <対象機能 or 指示>` | 読み書き | — |
| Code Review | `/code-review <対象ファイル or 指示>` | 読み取り専用 | — |
| Security Scan | `/security-scan <対象範囲 or 指示>` | 読み取り専用 | — |
| Legal Check | `/legal-check <対象範囲 or 指示>` | 読み取り専用 | — |
| Performance | `/performance <対象コンポーネント or 指示>` | 読み書き | §11を更新 |
| Refactoring | `/refactoring <対象ディレクトリ or 指示>` | 読み書き | — |
| Review Fix | `/review-fix <PR番号>` | 読み書き | — |
| Harness Refine | `/harness-refine <対象ディレクトリ or 指示>` | 読み書き（`.claude/`骨格のみ） | — |

スキルパイプライン: `/brainstorm` → `/prd` → `/architecture` → `/plan` → `/implementing-features` → `/code-review` + `/security-scan` + `/legal-check` + `/e2e-testing` + `/performance` + `/refactoring`

補助スキル（パイプライン外・オンデマンド起動）: `/ui-ux-design`, `/hig-compliance`, `/design-system-audit`, `/adr`, `/review-fix`, `/harness-refine`

---

## 品質ゲート

| ゲート | タイミング | 提示内容 |
| --- | --- | --- |
| ゲート1 | PRD生成後 | 要件の網羅性・曖昧さの解消 |
| ゲート2 | 設計完了後 | 技術選定・構成の妥当性 |
| ゲート3 | タスク分解後 | 粒度・依存関係の正確性 |
| ゲート4 | 実装完了後 | テスト結果・カバレッジ・静的解析 |
| ゲート5 | 検証完了後 | 全品質レポートの集約 |

通過基準: テスト全パス + カバレッジ目標以上 + 静的解析エラー0件

各ゲートでの人間レビューは任意の介入ポイントであり、必須の承認手続きではない(`constitution.md` 原則③)。ゲート自体を省略・削減することは不可。

---

## 設計思想

### 人間は「何を作るか」を決め、AIは「どう作るか」を担う

- **人間が決定**: 要求、技術スタック、品質基準、ポリシー
- **AIが管理**: PRD、設計、実装、テスト、レビュー、ドキュメント同期
- **双方向同期**: AIは開発中に`project-config.md`も更新する

### インプットとアウトプットを明確に分離する

- `input/` は人間が書く場所（AIは読み取り専用）
- `output/` はAIが生成する場所（人間がレビュー）
- 各ゲートポイントで人間が確認・承認できる

### プロジェクト固有 vs 汎用を分離する

- `.claude/` 配下は**汎用**（プロジェクトを問わず再利用可能）
- `docs/` 配下は**プロジェクト固有**（AIが生成・メンテナンス）
- `input/` `output/` は**プロジェクト固有**（実行ごとの成果物）

---

## 既存プロジェクトへの導入

すでにソースコードがあるプロジェクトにブループリントを導入する手順。

### 1. ファイルをコピー

`setup.sh` は既存プロジェクトにそのまま使える。既存の `docs/`・`project-config.md`・`AGENTS.md` などは上書きせず、
既存の `.agents/` `.claude/` `.codex/` は `<名前>.bak/` に退避してから配置する:

```bash
bash setup.sh /path/to/existing-project
bash setup.sh /path/to/existing-project --agent codex --profile minimal   # Codex だけ・軽量構成にしたい場合
```

Project Blueprint 0.x を導入済みのプロジェクトは `setup.sh` ではなく `migrate.sh` を使う(上記「0.x からの移行」)。

### 2. project-config.md を既存プロジェクトから記入

既存プロジェクトの `package.json`・設定ファイルを参考にセクションを記入する:

| セクション | 記入元 |
| --- | --- |
| §1 基本情報 | `package.json` の name / description |
| §2 技術スタック | `package.json` の dependencies / devDependencies |
| §3 コマンド | `package.json` の scripts |
| §4 アーキテクチャ | `src/` のディレクトリ構成を確認 |
| §6 品質基準 | 既存のテスト設定・CI設定から |
| §9 Gitポリシー | `.husky/` や `lint-staged` の設定から |

### 3. docs/ を自動生成

`project-config.md` の記入後、以下のいずれかで `docs/` を初期生成する:

```text
# 方法A: アーキテクチャスキルで一括生成（推奨）
/architecture 既存プロジェクトのアーキテクチャをドキュメント化

# 方法B: 実装スキルで段階的に生成
/implementing-features docs/ の初期生成
```

### 4. 既存の設定からの引き継ぎ

バックアップされた `.claude.bak/` `.agents.bak/` `.codex.bak/` に固有の設定がある場合:

- `settings.local.json` → 新しい `.claude/settings.local.json` にマージ
- カスタムスキル → `.agents/skills/` にコピーし、`bash setup.sh <dir> --relink`
- Codex の独自設定 → `.codex/config.toml` にマージ(個人の許可は `~/.codex/` に置く)
- memory/ → `.claude/` 外のユーザーレベル設定のため影響なし
