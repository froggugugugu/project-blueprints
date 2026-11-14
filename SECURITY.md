# Security Policy / セキュリティポリシー

> 日本語は前半、English follows below.

## 対象(スコープ)

このリポジトリは Claude Code と Codex 用の開発ハーネス(指示・skill・subagent・フック・権限ルール・検証ゲート)のテンプレートです。
アプリケーションコードは含みません。次に該当するものを脆弱性として扱います。

| 分類 | 例 |
| --- | --- |
| ガードレールの迂回 | `safety-check.sh` / `protect-files.sh` / `config-guard.sh` / `scope-guard.sh`、Codex 側の `lib/codex-adapter.sh`・`.codex/rules/`・権限プロファイルを通り抜けて破壊的操作・秘密情報の読取・設定の弱体化ができる(`guardrails.md` に「同じ保証にならない点」として明記した差は対象外) |
| 検証ゲートの見逃し | `scripts/validate_harness.py` / `test_hooks.sh` が公式仕様に反する構成(参照されない権限ルール、フェイルオープンなフック、Claude Code と Codex の禁止ルールのずれ等)を通してしまう |
| 導入・移行スクリプトによる破壊 | `setup.sh` / `migrate.sh` が利用者のファイルを確認なく上書き・削除する、または `--rollback` で戻せない状態を作る |
| テンプレート経由の情報漏洩 | 同梱ファイル・ワークフローテンプレート・MCP テンプレートが秘密情報を記録・送信する、または安全でない既定値を持つ |
| サプライチェーン | `.mcp.json.template` が固定していない・deprecated な・乗っ取られたパッケージを参照する |
| プロンプトインジェクション | 同梱の指示・skill が外部入力(ツール結果、PR コメント、取得した Web ページ)を指示として実行する経路になっている |

対象外: Claude Code 本体・Anthropic API の問題(Anthropic の [責任ある開示](https://www.anthropic.com/responsible-disclosure-policy) へ)、Codex 本体・OpenAI API の問題(OpenAI へ)、
利用者がテンプレートを改変した結果、`output/` `docs/` などプロジェクト側が生成した内容。

## 報告方法

- GitHub の **Private vulnerability reporting**(リポジトリの Security タブ → Report a vulnerability)で報告してください。公開 Issue に書かないでください
- 再現手順(どのフック・ルールを、どの入力で迂回できたか)、影響、修正案があれば添えてください
- 受領の返信は 7 日以内、修正または判断の共有は 30 日以内を目標にします。修正はパッチリリース(`x.y.z`)として `CHANGELOG.md` の **Security** 節に記載します

## サポートするバージョン

| バージョン | 状態 |
| --- | --- |
| 最新のマイナー(`VERSION` ファイルの値、GitHub Releases の最新) | 修正を提供する |
| それ以前 | `setup.sh --upgrade` で最新へ更新する |

## 防御モデル(利用者向け)

1. **Layer 1 フック**(`.agents/hooks/`、`--dangerously-skip-permissions` でも有効): ブロック系 4 本は `onFailure: block` でフェイルクローズ。`config-guard.sh` が防御層を弱める設定変更をセッションに適用させない
2. **Layer 2 deny / ask**(Claude Code は `.claude/settings.json`、Codex は `.codex/rules/default.rules` と `.codex/config.toml` の権限プロファイル): 破壊的シェル操作・秘密ファイルの読取を拒否、外向き・不可逆操作は毎回確認
3. **検証ゲート**(`scripts/validate-harness.sh` と CI): 仕様乖離・フェイルオープン化・未固定パッケージを決定論的に落とす
4. **組織展開**: `managed-settings.example.json`(`requiredMinimumVersion`、`blockReads/WritesOutsideWorkingDirectories`、`disableBypassPermissionsMode`)

詳細は `project-blueprint/.agents/guardrails.md`。

---

## Scope

This repository is a template of a development harness for Claude Code and Codex (instructions, skills, subagents, hooks,
permission rules and a validation gate). It ships no application code. The following count as vulnerabilities:

| Class | Examples |
| --- | --- |
| Guardrail bypass | A destructive command, secret read or settings weakening gets past `safety-check.sh` / `protect-files.sh` / `config-guard.sh` / `scope-guard.sh`, or on the Codex side `lib/codex-adapter.sh`, `.codex/rules/` and the permission profile (differences already listed under "Where Codex does not give the same guarantee" in `guardrails.md` are out of scope) |
| Validation-gate miss | `scripts/validate_harness.py` / `test_hooks.sh` accept a configuration that violates the official spec (unreferenced permission rules, fail-open hooks, drift between the Claude Code and Codex deny rules, …) |
| Damage by the install / migration scripts | `setup.sh` / `migrate.sh` overwrite or delete user files without notice, or leave a state `--rollback` cannot restore |
| Leak through the template | A bundled file, workflow template or MCP template records or sends secrets, or ships an unsafe default |
| Supply chain | `.mcp.json.template` references an unpinned, deprecated or hijacked package |
| Prompt injection | A bundled instruction or skill turns untrusted input (tool results, PR comments, fetched pages) into instructions |

Out of scope: Claude Code itself and the Anthropic API (report to Anthropic's
[responsible disclosure program](https://www.anthropic.com/responsible-disclosure-policy)), Codex itself and the OpenAI API (report to OpenAI), user modifications of the
template, and content generated on the project side (`output/`, `docs/`).

## Reporting

- Use GitHub **Private vulnerability reporting** (Security tab → Report a vulnerability). Do not open a public issue
- Include reproduction steps (which hook or rule, which input), impact and a fix proposal if you have one
- We aim to acknowledge within 7 days and to ship a fix or a decision within 30 days. Fixes ship as patch releases
  (`x.y.z`) and are listed under **Security** in `CHANGELOG.md`

## Supported versions

| Version | Status |
| --- | --- |
| Latest minor (the value in `VERSION`, the latest GitHub Release) | Receives fixes |
| Older | Update with `setup.sh --upgrade` |

## Defense model (for adopters)

1. **Layer 1 hooks** (`.agents/hooks/`, active even under `--dangerously-skip-permissions`): the 4 blocking hooks fail closed with `onFailure: block`; `config-guard.sh` refuses settings changes that weaken the guardrails
2. **Layer 2 deny / ask** (`.claude/settings.json` for Claude Code; `.codex/rules/default.rules` and the permission profile in `.codex/config.toml` for Codex): destructive shell operations and secret-file reads are denied; outbound, irreversible operations ask every time
3. **Validation gate** (`scripts/validate-harness.sh` and CI): spec drift, fail-open changes and unpinned packages fail deterministically
4. **Organization rollout**: `managed-settings.example.json` (`requiredMinimumVersion`, `blockReads/WritesOutsideWorkingDirectories`, `disableBypassPermissionsMode`)

Details: `project-blueprint-en/.agents/guardrails.md`.
