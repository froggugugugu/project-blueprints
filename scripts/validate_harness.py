#!/usr/bin/env python3
"""Deterministic validator for the harness (.agents/ shared core + .claude/ and .codex/ adapters).

Catches the class of defect that only a human reading the spec would otherwise
notice: frontmatter fields with values outside the official enums, permission
rules the runtime never consults, hook registrations pointing at missing files,
and drift between the JP and EN mirrors.

Stdlib only. PyYAML is used when importable, but every check has a fallback so
the script runs on a bare CI image.

Usage (see validate-harness.sh for the wrapper):
    python3 scripts/validate_harness.py                 # both mirrors + parity
    python3 scripts/validate_harness.py --root <dir>    # one harness root
    python3 scripts/validate_harness.py --online        # also resolve npm packages

Layout (1.0): `.agents/` holds what Claude Code and Codex share (skills, hooks, rules, gates);
`.claude/` and `.codex/` are thin adapters. The Codex-side checks (`check_codex_*`) verify that the
adapter registers the shared hooks, mirrors the Claude Code deny / ask rules, and that the generated
agent definitions are in sync with their source.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import yaml  # type: ignore
except ImportError:  # pragma: no cover - CI images often lack PyYAML
    yaml = None

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sync_codex_agents  # noqa: E402 - .claude/agents/*.md → .codex/agents/*.toml の生成器(同期検査に使う)

# ── 公式仕様の enum(docs.claude.com 準拠) ──────────────────────────────
HOOK_EVENTS = {
    "SessionStart", "Setup", "InstructionsLoaded", "UserPromptSubmit",
    "UserPromptExpansion", "MessageDisplay", "PreToolUse", "PermissionRequest",
    "PostToolUse", "PostToolUseFailure", "PostToolBatch", "PermissionDenied",
    "Notification", "SubagentStart", "SubagentStop", "TaskCreated",
    "TaskCompleted", "Stop", "StopFailure", "TeammateIdle", "ConfigChange",
    "CwdChanged", "DirectoryAdded", "FileChanged", "WorktreeCreate",
    "WorktreeRemove", "PreCompact", "PostCompact", "PreModelSwitch",
    "PostModelSwitch", "SessionEnd", "Elicitation", "ElicitationResult",
}
HOOK_TYPES = {"command", "http", "mcp_tool", "prompt", "agent"}
# `if`(権限ルール構文でフックの発火を絞る)が効くのはツール系イベントだけ。他に書くとフックが一切走らない。
HOOK_IF_EVENTS = {"PreToolUse", "PostToolUse", "PostToolUseFailure", "PermissionRequest", "PermissionDenied"}
# Layer 1 のブロック系フック。起動失敗・タイムアウトで操作が素通りしないよう `onFailure: block`(v2.1.295)を要求する
FAIL_CLOSED_SCRIPTS = {"safety-check.sh", "protect-files.sh", "config-guard.sh", "scope-guard.sh"}
FAIL_CLOSED_EVENTS = {"PreToolUse", "ConfigChange"}
ON_FAILURE_VALUES = {"continue", "block"}
# skill / agent / workflow のフォルダ名として予約されている名前空間(v2.1.282)。置いても読み込まれない。
RESERVED_NAMESPACES = {"anthropic-skills", "claude-ai"}
# project / local settings の env から読まれない変数(v2.1.251 / v2.1.282)。書いても効かない。
PROJECT_IGNORED_ENV = {"CLAUDE_CONFIG_DIR", "CLAUDE_CODE_TMPDIR", "TMPDIR", "CLAUDE_CODE_ENABLE_TELEMETRY"}
CACHE_TTLS = {"5m", "1h"}
LOOP_MD_MAX_CHARS = 25_000     # .claude/loop.md はこれを超えた分が読まれない
AGENT_COLORS = {"red", "blue", "green", "yellow", "purple", "orange", "pink", "cyan"}
MODEL_ALIASES = {"opus", "sonnet", "haiku", "fable", "inherit"}
EFFORT_LEVELS = {"low", "medium", "high", "xhigh", "max"}
PERMISSION_MODES = {"default", "acceptEdits", "auto", "dontAsk", "bypassPermissions", "plan", "manual"}
MEMORY_SCOPES = {"user", "project", "local"}
# project / local settings からは読まれない(公式仕様)。書いても無視される。
PROJECT_IGNORED_DEFAULT_MODES = {"auto", "bypassPermissions"}
# settings-reference `permissions` の閉じた集合(未知キーは黙って無視される)。blockWrites は v2.1.314
PERMISSION_KEYS = {
    "allow", "ask", "deny", "additionalDirectories", "defaultMode",
    "disableBypassPermissionsMode", "disableAutoMode",
    "blockReadsOutsideWorkingDirectories", "blockWritesOutsideWorkingDirectories",
    "denyInsteadOfPrompting",  # v2.1.319。ただし user / managed / --settings でしか効かない(下の表)
}

# settings-reference の「Where it's honored」列(2026-11-14 時点, v2.1.325)。project の settings.json /
# settings.local.json に書いても黙って無視されるキー。autoMode / pluginConfigs / sandbox.ripgrep は
# check_project_scope_keys が個別の文言で警告するのでここには載せない。
USER_OR_MANAGED_KEYS = {
    "askUserQuestionTimeout", "appendPlugins", "autoContinueAtUsageLimit", "autoMode.classifyAllShell",
    "axScreenReader", "bashEditDiffEnabled", "desktopSessionCleanupPeriodDays", "dialogExpiry",
    "feedbackDrafts", "footerLinksRegexes", "forceLoginGatewayUrl", "modelPicker",
    "permissions.denyInsteadOfPrompting", "prependPlugins", "processWrapper",
    "sandbox.allowAppleEvents", "sandbox.allowNestedUserNamespaces", "sandbox.credentials.allowPlaintextInject",
    "sandbox.credentials.awsPairs", "sandbox.credentials.sigv4", "sandbox.filesystem.disabled",
    "sandbox.network.strictAllowlist", "sandbox.network.tlsTerminate", "skipAutoPermissionPrompt",
    "spellcheck", "sshConfigs", "sshHostCommands", "vimInsertModeRemaps", "worktree.location",
}
# local(settings.local.json)では効くが、共有 settings.json では効かないキー
USER_LOCAL_OR_MANAGED_KEYS = {
    "skipDangerousModePermissionPrompt", "syncClaudeAiPlugins", "syncClaudeAiSkills", "useAutoModeDuringPlan",
}
MANAGED_ONLY_KEYS = {
    "allowAllClaudeAiMcps", "allowClaudeInChromeWithManagedMcp", "allowedChannelPlugins", "allowedProviders",
    "allowManagedHooksOnly", "allowManagedMcpServersOnly", "allowManagedPermissionRulesOnly",
    "availableModelsMatch", "blockedMarketplaces", "browserExternalPageTools", "channelsEnabled", "claudeMd",
    "deniedModels", "disableBrowserExternalNavigation", "disableCommandPluginSources",
    "disableDesktopLocalSessions", "disableMobileSimulatorTools", "disableRemotePreviewScripts",
    "disableSideloadFlags", "forceRemoteSettingsRefresh", "gatewayInternalNetworks", "managedMcpServers",
    "managedSourcesBehavior", "modelPricing", "parentSettingsBehavior", "pluginSuggestionMarketplaces",
    "pluginTrustMessage", "policyHelper", "requiredMaximumVersion", "requiredMinimumVersion",
    "sandbox.bwrapPath", "sandbox.filesystem.allowManagedReadPathsOnly", "sandbox.network.allowManagedDomainsOnly",
    "sandbox.socatPath", "sshHostAllowlist", "strictKnownMarketplaces", "strictPluginOnlyCustomization",
    "wslInheritsWindowsSettings",
}
# ~/.claude.json(global config)のキー。settings*.json に書いても読まれない
GLOBAL_CONFIG_KEYS = {
    "autoConnectIde", "autoInstallIdeExtension", "claudeInChromeDefaultEnabled", "copyFullResponse",
    "copyOnSelect", "defaultToAgentsView", "diffTool", "externalEditorContext", "leftArrowOpensAgents",
    "permissionExplainerEnabled", "prStatusFooterEnabled", "teammateDefaultModel",
}
# 削除済み・無視されるようになったキー(書いても効かない)
REMOVED_SETTINGS = {
    "subagentStatusLine": "v2.1.323 で削除されました(subagent の行は常に既定の表示)",
    "pluginDigests": "v2.1.325 で deprecated になり無視されます",
    # settings-reference の索引で「効果なし / 削除済み」とされているキー(2026-11-19 時点, v2.1.328)
    "keybindingFlavor": "v2.1.261 で deprecated になり効果がありません(単語編集のキーは常に readline の流儀)",
    "taskOutputMaxChars": "v2.1.277 で TaskOutput ツールとともに削除されました",
}
# 旧世代モデル向けの書き方(公式 best-practices「What you can stop doing」)。コードスパン・コードブロックの中は数えない
# (`CRITICAL` は脆弱性・ライセンスの重大度ラベルとして正当に使うので対象外)
LEGACY_EMPHASIS_RE = re.compile(r"\b(IMPORTANT|YOU MUST)\b")
LEGACY_THINK_RE = re.compile(r"(?i)\b(think hard(?:er)?|be thorough)\b")

# ファイルパス権限は Edit(path) / Read(path) だけが参照される。
# 下記ツールにパス指定を書いても一切参照されず、起動時に警告が出る。
# ── Codex 側の仕様(developers.openai.com/codex の hooks / config-reference / rules。2026-11-14 / codex-cli 0.162。
#    2026-11-19 に 0.170.0 のソースと実機で再確認: イベント 14 種・ハーネスが使う config キーに変更なし)──
CODEX_HOOK_EVENTS = {
    "SessionStart", "SessionEnd", "SubagentStart", "SubagentStop", "PreToolUse", "PermissionRequest",
    "PostToolUse", "PreModelRequest", "PostModelRequest", "PreCompact", "PostCompact",
    "UserPromptSubmit", "Stop", "Interrupt",
}
CODEX_HOOK_TYPES = {"command", "mcp_tool"}      # prompt / agent は解釈されるが実行されない
CODEX_NO_MATCHER_EVENTS = {"UserPromptSubmit", "Stop", "Interrupt", "PreModelRequest", "PostModelRequest"}
CODEX_BLOCKING_SCRIPTS = {"safety-check.sh", "protect-files.sh"}
CODEX_CLAUDE_ONLY_HOOK_KEYS = {"onFailure", "if", "continueOnBlock", "once"}
CODEX_SESSION_END_MAX_TIMEOUT = 3               # SessionEnd / Interrupt は既定 1 秒・上限 3 秒
# プロジェクトの .codex/config.toml に書いても無視されるキー(ユーザー設定にだけ効く)
CODEX_PROJECT_IGNORED_KEYS = {
    "openai_base_url", "chatgpt_base_url", "apps_mcp_product_sku", "model_provider", "model_providers",
    "notify", "profile", "profiles", "experimental_realtime_ws_base_url", "otel",
}
# 権限プロファイルで読取専用にしておくパス(`extends = ":workspace"` だけでは、codex-cli 0.162.1 の実測で保護が継がれなかった。
# 0.170.0 の実測では継がれたが、対応する最小の版が 0.162 なので明示を要求し続ける)
CODEX_PROTECTED_PATHS = (".git", ".agents", ".codex", ".claude/settings.json")
CODEX_ADAPTER_REL = ".agents/hooks/lib/codex-adapter.sh"
CODEX_ADAPTER_RE = re.compile(r"/\.agents/hooks/lib/codex-adapter\.sh\"?\s+(--fail-closed\s+)?([\w.-]+\.sh)")
# .claude/ に実体を置かないもの(原本は .agents/。Claude Code 用には setup.sh がリンクする)
SHARED_VIA_LINK = ("skills", "rules")
MOVED_OUT_OF_CLAUDE = ("hooks", "scripts", "learnings", "tasks", "guardrails.md", "quality-gates.md", "pitfalls.md")

NEVER_CONSULTED_PATH_TOOLS = {"Write", "NotebookEdit", "Glob", "MultiEdit"}

CLAUDE_MD_SOFT_LIMIT = 200   # constitution §6 目安
CLAUDE_MD_HARD_LIMIT = 220   # constitution §6 ハード上限
SKILL_DESC_LIMIT = 1536      # description + when_to_use はこの文字数で切り詰められる
SPEC_DESC_LIMIT = 1024       # Agent Skills 標準(agentskills.io)の description 上限
# Agent Skills 標準の name: 小文字の英数字とハイフンだけ、先頭・末尾・連続のハイフンは不可、64 字以内。
# Codex は 64 字を超える name と、description の無い skill を読み込まない(codex-rs/skills/src/parser.rs。0.171.0 で実測)
SPEC_NAME_LIMIT = 64
SPEC_NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
REFERENCE_TOC_LINES = 100    # これを超える参照ファイルは冒頭に目次を置く(skill authoring best practices)
SKILL_BODY_WARN_LINES = 300  # 公式上限は 500 行。詳細は references/ に分けて 300 行以内を目安にする
SCOPE_GUARD_SCOPES = {"docs", "output", "tests"}
ALWAYS_ON_RULE_WARN_LINES = 60


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, where: str, msg: str) -> None:
        self.errors.append(f"{where}: {msg}")

    def warn(self, where: str, msg: str) -> None:
        self.warnings.append(f"{where}: {msg}")


# ── frontmatter ────────────────────────────────────────────────────────
FM_RE = re.compile(r"\A---\n(.*?)\n---\n", re.S)


def split_top_level(text: str) -> list[str]:
    """Split on commas that are not inside parentheses.

    `Bash(ls *, find *, git *)` is one rule, not three.
    """
    out, depth, buf = [], 0, []
    for ch in text:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth = max(0, depth - 1)
        if ch == "," and depth == 0:
            out.append("".join(buf).strip())
            buf = []
        else:
            buf.append(ch)
    if buf:
        out.append("".join(buf).strip())
    return [x for x in out if x]


def parse_frontmatter(path: Path, rep: Report) -> dict | None:
    """Return the frontmatter mapping, or None when it is missing/unparseable."""
    text = path.read_text(encoding="utf-8")
    m = FM_RE.match(text)
    if not m:
        rep.error(str(path), "frontmatter (--- で囲まれた YAML) がありません")
        return None
    block = m.group(1)

    # PyYAML の有無に関わらず、最も多い事故を明示的に検出する:
    # 引用符なしスカラーの中に `: ` があると YAML 全体がパース不能になる。
    for line in block.split("\n"):
        mm = re.match(r"^([A-Za-z][\w-]*):[ \t]+(?![>|])(.*)$", line)
        if mm and ": " in mm.group(2) and not re.match(r'^["\']', mm.group(2).strip()):
            rep.error(
                str(path),
                f"`{mm.group(1)}` の値に引用符なしの `: ` が含まれ YAML がパース不能です"
                " — ブロックスカラー(`>`)にするか引用符で囲んでください",
            )

    if yaml is not None:
        try:
            data = yaml.safe_load(block)
        except Exception as exc:  # noqa: BLE001 - report any YAML failure verbatim
            rep.error(str(path), f"frontmatter の YAML パースに失敗: {str(exc)[:120]}")
            return None
        if not isinstance(data, dict):
            rep.error(str(path), "frontmatter がマッピングではありません")
            return None
        return data

    # フォールバック: このハーネスの frontmatter はフラットなので簡易解析で足りる。
    data: dict = {}
    key = None
    for line in block.split("\n"):
        if re.match(r"^\s*-\s+", line) and key:
            data.setdefault(key, [])
            if isinstance(data[key], list):
                data[key].append(re.sub(r"^\s*-\s+", "", line).strip())
        elif line.startswith((" ", "\t")) and key:
            if isinstance(data.get(key), str):
                data[key] = (data[key] + " " + line.strip()).strip()
        else:
            mm = re.match(r"^([A-Za-z][\w-]*):\s*(.*)$", line)
            if mm:
                key = mm.group(1)
                val = mm.group(2).strip()
                data[key] = "" if val in (">", "|") else val
    return data


# ── 個別チェック ───────────────────────────────────────────────────────
def check_json_files(root: Path, rep: Report) -> None:
    for p in sorted(root.rglob("*.json")) + sorted(root.rglob("*.json.template")):
        try:
            json.loads(p.read_text(encoding="utf-8"))
        except Exception as exc:  # noqa: BLE001
            rep.error(str(p), f"JSON パース失敗: {str(exc)[:120]}")


def check_permission_rules(where: str, rules: list[str], rep: Report) -> None:
    for rule in rules:
        # 閉じ括弧の後ろに文字が続くルールは無効として弾かれる(v2.1.260)
        if re.match(r"^[A-Za-z_][\w]*\(.*\)\s*\S", rule.strip()):
            rep.error(where, f"`{rule}` — 閉じ括弧の後にテキストがあるため無効なルールとして扱われます")
            continue
        m = re.match(r"^([A-Za-z_][\w]*)\((.+)\)$", rule.strip())
        if not m:
            continue
        tool, spec = m.group(1), m.group(2)
        # `Bash(git * main)` のようにサブコマンドの前にワイルドカードを置くと意図と違う一致になり、起動時に警告される(v2.1.246)
        if tool == "Bash" and re.match(r"^\S+\s+\*\s+\S", spec):
            rep.warn(where, f"`{rule}` — サブコマンドの前の `*` は起動時に警告されます。`Bash({spec.split()[0]} <sub> *)` の形にしてください")
        # `Bash(PORT=* npm run dev)` は変数の値に任意のコマンド片を許してしまい、起動時に警告される(v2.1.323)
        if tool == "Bash" and "[permissions.allow]" in where and re.match(r"^\w+=\S*\*", spec):
            rep.warn(where, f"`{rule}` — 変数の値に `*` を含む allow ルールは起動時に警告されます。値を固定するか変数を外してください")
        if tool in NEVER_CONSULTED_PATH_TOOLS and ":" not in spec:
            rep.error(
                where,
                f"`{rule}` は参照されません — ファイルパス権限は Edit(path)/Read(path) "
                f"のみ評価されます。`Edit({spec})` に書き換えてください",
            )


def check_settings(root: Path, rep: Report) -> set[str]:
    """Validate settings*.json. Returns the set of hook scripts referenced."""
    referenced: set[str] = set()
    hooks_dir = root / ".agents/hooks"

    for name in ("settings.json", "settings.minimal.json"):
        p = root / ".claude" / name
        if not p.exists():
            continue
        cfg = json.loads(p.read_text(encoding="utf-8"))
        where = str(p)

        perms = cfg.get("permissions", {})
        for bucket in ("allow", "deny", "ask"):
            check_permission_rules(f"{where} [permissions.{bucket}]", perms.get(bucket, []), rep)
        check_permission_keys(where, cfg, rep)
        check_project_scope_keys(where, cfg, rep)
        check_enabled_plugins(where, cfg, rep)

        for event, groups in cfg.get("hooks", {}).items():
            if event not in HOOK_EVENTS:
                rep.error(where, f"`{event}` は公式のフックイベント名ではありません")
            for group in groups:
                if event == "FileChanged" and re.search(r"[\\^$*?\[\]()+]", str(group.get("matcher", ""))):
                    rep.warn(where, "FileChanged の matcher はリテラルなファイル名を `|` で並べます — 正規表現として解釈されず、その名前のファイルを監視してしまいます")
                for hook in group.get("hooks", []):
                    check_hook_handler(f"{where} [hooks.{event}]", hook, rep, event)
                    cmd = hook.get("command", "")
                    if event in FAIL_CLOSED_EVENTS and any(s in cmd for s in FAIL_CLOSED_SCRIPTS) and hook.get("onFailure") != "block":
                        rep.warn(where, f"{event} のブロック系フック({cmd.split('/')[-1].split()[0]})に `onFailure: block` がありません — フックが起動できない・タイムアウトしたとき操作が素通りします(v2.1.295)")
                    m = re.search(r"/\.agents/hooks/([\w.-]+\.sh)", cmd)
                    if not m:
                        continue
                    script = m.group(1)
                    referenced.add(script)
                    if not (hooks_dir / script).exists():
                        rep.error(where, f"{event} が参照する {script} が存在しません")

    local = root / ".claude/settings.local.json.template"
    if local.exists():
        cfg = json.loads(local.read_text(encoding="utf-8"))
        perms = cfg.get("permissions", {})
        for bucket in ("allow", "deny", "ask"):
            check_permission_rules(f"{local} [permissions.{bucket}]", perms.get(bucket, []), rep)
        if "deny" in perms:
            rep.error(str(local), "permissions.deny を定義しています — 共有 settings.json の deny を弱体化させます")
        check_permission_keys(str(local), cfg, rep)
        check_project_scope_keys(str(local), cfg, rep)
        for event, groups in cfg.get("hooks", {}).items():
            if event not in HOOK_EVENTS:
                rep.error(str(local), f"`{event}` は公式のフックイベント名ではありません")
            for group in groups:
                for hook in group.get("hooks", []):
                    check_hook_handler(f"{local} [hooks.{event}]", hook, rep, event)

    return referenced


def check_hook_handler(where: str, hook: dict, rep: Report, event: str = "") -> None:
    """Validate one hook handler object against the official field list."""
    htype = hook.get("type")
    if htype not in HOOK_TYPES:
        rep.error(where, f"`type: {htype}` は公式のフックタイプではありません ({', '.join(sorted(HOOK_TYPES))})")
        return
    cond = hook.get("if")
    if cond is not None:
        if not isinstance(cond, str) or not cond.strip():
            rep.error(where, "`if` は権限ルール構文の文字列 1 つで指定します(例 `Bash(git *)`)")
        elif event and event not in HOOK_IF_EVENTS:
            rep.error(where, f"`if` は {', '.join(sorted(HOOK_IF_EVENTS))} でしか効きません — {event} に書くとフックが一切走りません")
        elif "&&" in cond or "||" in cond:
            rep.error(where, "`if` に `&&` / `||` は使えません。条件ごとに handler を分けてください")
    on_failure = hook.get("onFailure")
    if on_failure is not None:
        if on_failure not in ON_FAILURE_VALUES:
            rep.error(where, f"`onFailure: {on_failure}` は continue / block のみ指定できます(v2.1.295)")
        elif htype not in ("command", "http"):
            rep.error(where, f"`onFailure` は command / http 型のフックでしか効きません({htype} 型に書いても無視されます)")
    if htype == "agent" and event == "PermissionRequest":
        rep.error(where, "PermissionRequest に agent 型フックは登録できません(v2.1.280 以降エラー)。command / http 型にしてください")
    if htype == "command" and not str(hook.get("command", "")).strip():
        rep.error(where, "`type: command` のフックに `command` がありません")
    if htype in ("prompt", "agent") and not str(hook.get("prompt", "")).strip():
        rep.error(where, f"`type: {htype}` のフックには `prompt` が必要です")
    if htype == "http" and not str(hook.get("url", "")).strip():
        rep.error(where, "`type: http` のフックには `url` が必要です")
    for key in ("async", "asyncRewake", "once"):
        val = hook.get(key)
        if val is not None and not isinstance(val, bool):
            rep.error(where, f"`{key}: {val}` は true / false のみ指定できます")
    timeout = hook.get("timeout")
    if timeout is not None and (not isinstance(timeout, (int, float)) or timeout <= 0):
        rep.error(where, f"`timeout: {timeout}` は正の秒数である必要があります")
    if hook.get("async") and htype in ("prompt", "agent"):
        rep.warn(where, f"`async: true` の {htype} フックは decision を返せません")


def check_permission_keys(where: str, cfg: dict, rep: Report) -> None:
    """`permissions` の未知キーは黙って無視される(settings-reference の閉じた集合と突合)."""
    for key in cfg.get("permissions", {}):
        if key not in PERMISSION_KEYS:
            rep.error(where, f"`permissions.{key}` は公式の permissions キーではありません — 黙って無視されます")


def flatten_keys(cfg: dict, prefix: str = "", depth: int = 3) -> set[str]:
    """`{"sandbox": {"network": {"x": 1}}}` → {"sandbox", "sandbox.network", "sandbox.network.x"}."""
    keys: set[str] = set()
    for k, v in cfg.items():
        path = f"{prefix}{k}"
        keys.add(path)
        if isinstance(v, dict) and depth > 1:
            keys |= flatten_keys(v, path + ".", depth - 1)
    return keys


def check_project_scope_keys(where: str, cfg: dict, rep: Report) -> None:
    """Keys the runtime ignores in project / local settings (repo-borne privilege escalation guard)."""
    mode = cfg.get("permissions", {}).get("defaultMode")
    if mode in PROJECT_IGNORED_DEFAULT_MODES:
        rep.warn(
            where,
            f"`permissions.defaultMode: {mode}` は project settings では無視されます"
            " — ~/.claude/settings.json か managed settings に置いてください",
        )
    if "autoMode" in cfg:
        rep.warn(where, "`autoMode` は project settings から読まれません — ~/.claude/settings.json か managed settings に置いてください")
    if "pluginConfigs" in cfg:
        rep.warn(where, "`pluginConfigs` は project settings から読まれません(v2.1.207) — ~/.claude/settings.json に置いてください")
    if cfg.get("remoteControlAtStartup") is True:
        rep.warn(where, "`remoteControlAtStartup: true` は project / local settings では効きません(v2.1.222)")
    if isinstance(cfg.get("sandbox"), dict) and "ripgrep" in cfg["sandbox"]:
        rep.warn(where, "`sandbox.ripgrep` は user / managed / --settings からしか読まれません(v2.1.232)")
    is_local = "settings.local" in where
    for key in sorted(flatten_keys(cfg)):
        top = key.split(".")[0]
        if top.startswith("_comment") or top in ("hooks", "env", "enabledPlugins", "mcpServers"):
            continue
        if key in REMOVED_SETTINGS:
            rep.warn(where, f"`{key}` は {REMOVED_SETTINGS[key]}")
        elif key in USER_OR_MANAGED_KEYS:
            rep.warn(where, f"`{key}` は ~/.claude/settings.json・managed settings・--settings でしか効きません — project settings では無視されます")
        elif key in USER_LOCAL_OR_MANAGED_KEYS and not is_local:
            rep.warn(where, f"`{key}` は共有の settings.json では無視されます — settings.local.json か ~/.claude/settings.json に置いてください")
        elif key in MANAGED_ONLY_KEYS:
            rep.warn(where, f"`{key}` は managed settings でしか効きません — project settings では無視されます")
        elif key in GLOBAL_CONFIG_KEYS:
            rep.warn(where, f"`{key}` は ~/.claude.json(global config)のキーです — settings*.json に書いても読まれません")
    for key in sorted(cfg.get("env", {}) or {}):
        if key in PROJECT_IGNORED_ENV or key.startswith("OTEL_"):
            rep.warn(
                where,
                f"`env.{key}` は project / local settings では読まれません(OpenTelemetry と一時ディレクトリは"
                " ~/.claude/settings.json・managed settings・シェル環境で設定する)",
            )


def check_enabled_plugins(where: str, cfg: dict, rep: Report) -> None:
    """`enabledPlugins` が指すプラグインがその marketplace に存在するか。
    ローカルの marketplace キャッシュ(~/.claude/plugins/marketplaces/)があるときだけ検査し、
    CI のように無い環境では黙って通す(存在しないプラグインは起動時に黙って無視されるため)。"""
    plugins = cfg.get("enabledPlugins") or {}
    if not isinstance(plugins, dict):
        return
    cache_root = Path(os.environ.get("CLAUDE_CONFIG_DIR", Path.home() / ".claude")) / "plugins" / "marketplaces"
    for key in sorted(plugins):
        if "@" not in key:
            rep.error(where, f"`enabledPlugins.{key}` は `<plugin>@<marketplace>` の形で書きます")
            continue
        name, market = key.rsplit("@", 1)
        manifest = cache_root / market / ".claude-plugin" / "marketplace.json"
        if not manifest.exists():
            continue
        try:
            known = {p.get("name") for p in json.loads(manifest.read_text(encoding="utf-8")).get("plugins", [])}
        except Exception:  # noqa: BLE001
            continue
        if name not in known:
            rep.warn(where, f"`enabledPlugins.{key}` — marketplace `{market}` に `{name}` が存在しません(起動時に黙って無視されます)")


def check_hook_scripts(root: Path, referenced: set[str], rep: Report) -> None:
    hooks_dir = root / ".agents/hooks"
    if not hooks_dir.is_dir():
        return
    for p in sorted(hooks_dir.glob("*.sh")):
        if not p.stat().st_mode & 0o111:
            rep.error(str(p), "実行権限がありません (chmod +x)")
        proc = subprocess.run(["bash", "-n", str(p)], capture_output=True, text=True)
        if proc.returncode != 0:
            rep.error(str(p), f"シェル構文エラー: {proc.stderr.strip()[:120]}")
        if p.name not in referenced:
            rep.warn(str(p), "settings.json にも agent / skill の frontmatter にも登録されていません")


def check_agents(root: Path, skill_names: set[str], rep: Report) -> None:
    agents_dir = root / ".claude/agents"
    if not agents_dir.is_dir():
        return
    seen_colors: dict[str, str] = {}
    for p in sorted(agents_dir.glob("*.md")):
        if p.name == "README.md":
            continue
        fm = parse_frontmatter(p, rep)
        if fm is None:
            continue
        where = str(p)

        name = str(fm.get("name", "")).strip()
        if not name:
            rep.error(where, "`name` が未設定です")
        elif ":" in name:
            rep.error(where, f"`name: {name}` に `:` が含まれます — プラグイン用に予約されており読み込まれません")
        elif not re.fullmatch(r"[a-z0-9-]+", name):
            rep.error(where, f"`name: {name}` は小文字英数字とハイフンのみ使えます")
        if name in RESERVED_NAMESPACES or p.stem in RESERVED_NAMESPACES:
            rep.error(where, f"`{name}` は claude.ai 同期用に予約された名前空間です(v2.1.282)。ローカル定義は読み込まれません")

        if not str(fm.get("description", "")).strip():
            rep.error(where, "`description` が未設定です")
        elif len(str(fm["description"])) > 400:
            rep.warn(where, "`description` が長すぎます — 発動条件が曖昧になります (1〜2 文推奨)")

        color = fm.get("color")
        if color is not None:
            if color not in AGENT_COLORS:
                rep.error(where, f"`color: {color}` は公式の 8 色外です ({', '.join(sorted(AGENT_COLORS))})")
            elif color in seen_colors:
                rep.warn(where, f"`color: {color}` は {seen_colors[color]} と重複しています")
            else:
                seen_colors[color] = p.name

        model = fm.get("model")
        if model is not None and model not in MODEL_ALIASES and not re.fullmatch(r"claude-[\w.-]+", str(model)):
            rep.error(where, f"`model: {model}` は不正です — エイリアス({'/'.join(sorted(MODEL_ALIASES))})か claude-* の ID を指定してください")

        for key, allowed in (
            ("effort", EFFORT_LEVELS),
            ("permissionMode", PERMISSION_MODES),
            ("memory", MEMORY_SCOPES),
        ):
            val = fm.get(key)
            if val is not None and val not in allowed:
                rep.error(where, f"`{key}: {val}` は不正です (許容値: {', '.join(sorted(allowed))})")

        if fm.get("isolation") is not None and fm["isolation"] != "worktree":
            rep.error(where, f"`isolation: {fm['isolation']}` は不正です (`worktree` のみ)")

        max_turns = fm.get("maxTurns")
        if max_turns is not None and not str(max_turns).isdigit():
            rep.error(where, f"`maxTurns: {max_turns}` は整数である必要があります")

        # YAML 1.1 パーサは `yes` / `on` も真と解釈するため、生テキストで厳密に検査する。
        raw_fm = FM_RE.match(p.read_text(encoding="utf-8"))
        raw_fm_text = raw_fm.group(1) if raw_fm else ""
        for key in ("omitClaudeMd", "background"):
            mm = re.search(rf"(?m)^{key}:[ \t]*(.*?)[ \t]*$", raw_fm_text)
            if mm and mm.group(1).strip('"\'') not in ("true", "false"):
                rep.error(where, f"`{key}: {mm.group(1)}` は true / false のみ指定できます")
        exp = fm.get("experimental")
        if isinstance(exp, dict) and exp.get("cacheTtl") is not None and str(exp["cacheTtl"]) not in CACHE_TTLS:
            rep.error(where, f"`experimental.cacheTtl: {exp['cacheTtl']}` は 5m / 1h のみ指定できます")

        tools_raw = fm.get("tools")
        tool_list = tools_raw if isinstance(tools_raw, list) else split_top_level(str(tools_raw or ""))
        tool_names = {re.sub(r"\(.*\)$", "", str(t)).strip() for t in tool_list}
        writable = tools_raw is None or bool(tool_names & {"Edit", "Write", "NotebookEdit"})
        if writable and "scope-guard.sh" not in FM_RE.match(p.read_text(encoding="utf-8")).group(1):
            rep.warn(
                where,
                "書込可能な agent に書込範囲のフック(scope-guard.sh)がありません — "
                "範囲制限を本文の散文だけにせず frontmatter の hooks.PreToolUse で強制してください",
            )

        for skill in fm.get("skills") or []:
            if str(skill).strip() not in skill_names:
                rep.error(where, f"`skills:` が参照する `{skill}` が .agents/skills/ に存在しません")


def check_skills(root: Path, rep: Report) -> set[str]:
    skills_dir = root / ".agents/skills"
    names: set[str] = set()
    if not skills_dir.is_dir():
        return names

    for p in sorted(skills_dir.glob("*/SKILL.md")):
        names.add(p.parent.name)
        fm = parse_frontmatter(p, rep)
        if fm is None:
            continue
        where = str(p)

        name = str(fm.get("name", p.parent.name)).strip()
        if name and name != p.parent.name:
            rep.warn(where, f"`name: {name}` がディレクトリ名 `{p.parent.name}` と異なります")
        if p.parent.name in RESERVED_NAMESPACES:
            rep.error(where, f"`{p.parent.name}` は claude.ai 同期用に予約された名前空間です(v2.1.282)。この skill は読み込まれません")

        if len(name) > SPEC_NAME_LIMIT:
            rep.error(where, f"`name` が {len(name)} 文字です — Codex は {SPEC_NAME_LIMIT} 文字を超える skill を読み込みません"
                             "(Agent Skills 標準の上限。Claude Code でだけ動く skill になります)")
        elif name and not SPEC_NAME_RE.match(name):
            rep.warn(where, f"`name: {name}` が Agent Skills 標準の形ではありません"
                            "(小文字の英数字とハイフンだけ。先頭・末尾・連続のハイフンは不可)")

        desc = str(fm.get("description", "")) + str(fm.get("when_to_use", ""))
        if not desc.strip():
            rep.error(where, "`description` が未設定です")
        elif not str(fm.get("description") or "").strip():
            rep.error(where, "`description` がありません(`when_to_use` だけでは足りません) — Codex は description の無い skill を読み込みません"
                             "(Claude Code でだけ動く skill になります)")
        elif len(desc) > SKILL_DESC_LIMIT:
            rep.warn(where, f"description + when_to_use が {len(desc)} 文字 — 一覧では {SKILL_DESC_LIMIT} 文字で切り詰められます")

        for key in ("allowed-tools", "disallowed-tools"):
            raw = fm.get(key)
            if raw:
                rules = raw if isinstance(raw, list) else split_top_level(str(raw))
                check_permission_rules(f"{where} [{key}]", rules, rep)

        effort = fm.get("effort")
        if effort is not None and effort not in EFFORT_LEVELS:
            rep.error(where, f"`effort: {effort}` は不正です (許容値: {', '.join(sorted(EFFORT_LEVELS))})")

        model = fm.get("model")
        if model is not None and model not in MODEL_ALIASES and not re.fullmatch(r"claude-[\w.-]+", str(model)):
            rep.error(where, f"`model: {model}` は不正です")

        # YAML 1.1 パーサは `yes` / `on` も真と解釈してしまうため、生テキストで厳密に検査する。
        raw_block = FM_RE.match(p.read_text(encoding="utf-8"))
        for key in ("disable-model-invocation", "user-invocable"):
            mm = re.search(rf"(?m)^{re.escape(key)}:[ \t]*(.*?)[ \t]*$", raw_block.group(1) if raw_block else "")
            if mm and mm.group(1).strip('"\'') not in ("true", "false"):
                rep.error(where, f"`{key}: {mm.group(1)}` は true / false のみ指定できます")

        check_skill_writing(p, fm, rep)
        check_skill_evals(p.parent, rep)

        ctx = fm.get("context")
        if ctx is not None and ctx != "fork":
            rep.error(where, f"`context: {ctx}` は不正です (`fork` のみ。既定の main 実行は行を書かない)")
        if fm.get("agent") is not None and ctx != "fork":
            rep.error(where, "`agent:` は `context: fork` とセットでのみ有効です")
        if fm.get("background") is not None and ctx != "fork":
            rep.warn(where, "`background:` は `context: fork` のときだけ意味を持ちます")

        # fork した skill は subagent として動くため、subagent から除去されるツールは使えない。
        tool_names = set()
        for key in ("allowed-tools", "disallowed-tools"):
            raw = fm.get(key)
            if raw:
                rules = raw if isinstance(raw, list) else split_top_level(str(raw))
                tool_names |= {re.sub(r"\(.*\)$", "", str(r)).strip() for r in rules}
        if ctx == "fork":
            # AskUserQuestion は前景・背景を問わず全 subagent から除去される。
            if "AskUserQuestion" in tool_names:
                rep.error(
                    where,
                    "`context: fork` と `AskUserQuestion` は両立しません — "
                    "AskUserQuestion は全 subagent から除去されます。対話が必要なら fork をやめてください",
                )
            # fork 内の Agent は spawn せずエラーを返す。
            if "Agent" in tool_names:
                rep.error(where, "`context: fork` の skill は `Agent` で subagent を spawn できません")
            if fm.get("background") is None:
                rep.warn(
                    where,
                    "`context: fork` は既定で背景実行され、組み込みツールも絞られます — "
                    "同一ターンで結果が必要なら `background: false` を明示してください",
                )

    return names


def strip_fences(text: str) -> str:
    """Blank out fenced code blocks so examples inside them are not treated as instructions."""
    out, fence = [], False
    for line in text.splitlines():
        if line.strip().startswith("```"):
            fence = not fence
            out.append("")
            continue
        out.append("" if fence else line)
    return "\n".join(out)


def check_skill_writing(p: Path, fm: dict, rep: Report) -> None:
    """Authoring rules from the official skill docs that are cheap to check deterministically."""
    where = str(p)
    text = p.read_text(encoding="utf-8")
    m = FM_RE.match(text)
    body = strip_fences(text[m.end():] if m else text)

    desc = str(fm.get("description", ""))
    if len(desc) > SPEC_DESC_LIMIT:
        rep.warn(where, f"`description` が {len(desc)} 文字 — Agent Skills 標準の上限 {SPEC_DESC_LIMIT} 文字を超えています")
    if re.match(r"^\s*(I |I'm |I can |You |You can |We |私|僕|あなた)", desc):
        rep.warn(where, "`description` は三人称で書いてください(一人称・二人称は発見性を下げます)")

    for line in body.splitlines():
        if re.match(r"^@[\w./~-]+", line):
            rep.warn(
                where,
                f"行頭の `{line.strip()[:60]}` は起動時にファイル全文が添付されます — "
                "「パス — 読む条件」の箇条書きにして必要時に Read させてください",
            )
    if re.search(r"\b20\d\d-\d\d(?:-\d\d)?\b", body):
        rep.warn(where, "日付つきの記述があります — 変わりうる事項は「旧方式」節に分けてください")

    if len(body.splitlines()) > SKILL_BODY_WARN_LINES:
        rep.warn(
            where,
            f"本文が {len(body.splitlines())} 行 — 公式上限は 500 行。出力テンプレートなどの詳細を "
            f"references/ に分け、{SKILL_BODY_WARN_LINES} 行以内を目安にしてください",
        )

    linked = set(re.findall(r"\]\((?:\./)?references/([\w.-]+\.md)\)", body))
    for name in sorted(linked):
        if not (p.parent / "references" / name).exists():
            rep.error(where, f"`references/{name}` へのリンクが壊れています")

    ref_dir = p.parent / "references"
    if ref_dir.is_dir():
        for ref in sorted(ref_dir.glob("*.md")):
            if ref.name not in linked:
                rep.warn(str(ref), "SKILL.md からリンクされていません — 参照は SKILL.md から 1 階層で直接リンクしてください")
        for ref in sorted(ref_dir.glob("*.md")):
            rt = ref.read_text(encoding="utf-8")
            if len(rt.splitlines()) > REFERENCE_TOC_LINES and not re.search(r"(?im)^#+\s*(目次|contents|table of contents)\s*$", rt):
                rep.warn(str(ref), f"{REFERENCE_TOC_LINES} 行を超える参照ファイルに目次がありません — 部分読みでも全体が見えるよう冒頭に置いてください")
            if re.search(r"\]\((?:\./)?(?:references/)?[\w.-]+\.md\)", strip_fences(rt)):
                rep.warn(str(ref), "参照ファイルから別の参照ファイルへリンクしています — SKILL.md から 1 階層で直接リンクしてください")


def check_skill_evals(skill_dir: Path, rep: Report) -> None:
    """evals/evals.json in the agentskills.io format (used by the skill-creator plugin)."""
    ev = skill_dir / "evals" / "evals.json"
    if not ev.exists():
        rep.warn(str(skill_dir / "SKILL.md"), "`evals/evals.json` がありません — 典型と境界の 2 ケース以上を agentskills.io 形式で置いてください")
        return
    where = str(ev)
    try:
        data = json.loads(ev.read_text(encoding="utf-8"))
    except Exception:  # noqa: BLE001 - check_json_files reports the parse error
        return
    if not isinstance(data, dict):
        rep.error(where, "トップレベルはオブジェクトである必要があります")
        return
    if data.get("skill_name") != skill_dir.name:
        rep.error(where, f"`skill_name: {data.get('skill_name')}` がディレクトリ名 `{skill_dir.name}` と一致しません")
    evals = data.get("evals")
    if not isinstance(evals, list) or not evals:
        rep.error(where, "`evals` が空、または配列ではありません")
        return
    ids: set[int] = set()
    for i, case in enumerate(evals):
        loc = f"{where} [evals[{i}]]"
        if not isinstance(case, dict):
            rep.error(loc, "テストケースはオブジェクトである必要があります")
            continue
        cid = case.get("id")
        if not isinstance(cid, int) or isinstance(cid, bool):
            rep.error(loc, "`id` は整数である必要があります")
        elif cid in ids:
            rep.error(loc, f"`id: {cid}` が重複しています")
        else:
            ids.add(cid)
        for key in ("prompt", "expected_output"):
            if not str(case.get(key, "")).strip():
                rep.error(loc, f"`{key}` が空です")
        for key in ("files", "assertions"):
            val = case.get(key)
            if val is not None and (not isinstance(val, list) or not all(isinstance(x, str) and x.strip() for x in val)):
                rep.error(loc, f"`{key}` は空でない文字列の配列である必要があります")
        for f in case.get("files") or []:
            if isinstance(f, str) and f.strip() and not (skill_dir / f).exists():
                rep.error(loc, f"`files` の `{f}` が skill ディレクトリ内に存在しません")
    if len(evals) < 2:
        rep.warn(where, "テストケースは 2 件以上(典型 + 境界)を推奨します")


def check_frontmatter_hooks(root: Path, rep: Report) -> set[str]:
    """Hooks declared in agent / skill frontmatter. Returns the hook scripts they reference."""
    referenced: set[str] = set()
    files = [p for p in sorted((root / ".claude/agents").glob("*.md")) if p.name != "README.md"]
    files += sorted((root / ".agents/skills").glob("*/SKILL.md"))
    for p in files:
        m = FM_RE.match(p.read_text(encoding="utf-8"))
        if not m:
            continue
        block = m.group(1)
        for sm in re.finditer(r"/\.agents/hooks/([\w.-]+\.sh)(?:[ \t]+([\w-]+))?", block):
            script, arg = sm.group(1), sm.group(2)
            referenced.add(script)
            if not (root / ".agents/hooks" / script).exists():
                rep.error(str(p), f"frontmatter の hooks が参照する {script} が存在しません")
            if script == "scope-guard.sh" and arg not in SCOPE_GUARD_SCOPES:
                rep.error(str(p), f"scope-guard.sh の未知のスコープ `{arg}` です (許容値: {', '.join(sorted(SCOPE_GUARD_SCOPES))})")
        if yaml is None:
            continue
        try:
            fm = yaml.safe_load(block)
        except Exception:  # noqa: BLE001 - parse_frontmatter reports YAML errors
            continue
        hooks = fm.get("hooks") if isinstance(fm, dict) else None
        if hooks is None:
            continue
        if not isinstance(hooks, dict):
            rep.error(str(p), "frontmatter の `hooks` はイベント名をキーにしたマップである必要があります")
            continue
        for event, groups in hooks.items():
            if event not in HOOK_EVENTS:
                rep.error(str(p), f"frontmatter の hooks の `{event}` は公式のフックイベント名ではありません")
            for group in groups or []:
                for hook in (group or {}).get("hooks", []) if isinstance(group, dict) else []:
                    check_hook_handler(f"{p} [hooks.{event}]", hook, rep)
                    if "scope-guard.sh" in str(hook.get("command", "")) and hook.get("onFailure") != "block":
                        rep.warn(str(p), "scope-guard.sh に `onFailure: block` がありません — フックが起動できないとき範囲外の書込が素通りします(v2.1.295)")
    return referenced


def check_workflows(root: Path, rep: Report) -> None:
    """Saved dynamic workflows (.claude/workflows/*.js): meta literal, phases, determinism, syntax."""
    wf_dir = root / ".claude/workflows"
    if not wf_dir.is_dir():
        return
    for p in sorted(wf_dir.glob("*.js")):
        where = str(p)
        text = p.read_text(encoding="utf-8")
        if not re.match(r"\Aexport const meta = \{", text):
            rep.error(where, "先頭の文が `export const meta = {` ではありません")
            continue
        start = text.index("{")
        depth, end, quote, esc = 0, None, None, False
        for i in range(start, len(text)):
            ch = text[i]
            if quote:
                if esc:
                    esc = False
                elif ch == "\\":
                    esc = True
                elif ch == quote:
                    quote = None
                continue
            if ch in "'\"":
                quote = ch
            elif ch == "`":
                rep.error(where, "`meta` にテンプレート文字列があります — 純粋なリテラルにしてください")
                break
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    end = i
                    break
        if end is None:
            rep.error(where, "`meta` のオブジェクトリテラルが閉じていません")
            continue
        meta = text[start:end + 1]
        bare = re.sub(r"'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"", "''", meta)
        if re.search(r"\.\.\.|[\w)\]]\s*\(", bare):
            rep.error(where, "`meta` に関数呼び出しまたはスプレッドがあります — 純粋なリテラルにしてください")
        for vm in re.finditer(r":\s*([A-Za-z_$][\w$]*)", bare):
            if vm.group(1) not in ("true", "false", "null"):
                rep.error(where, f"`meta` の値 `{vm.group(1)}` が変数参照です — リテラルにしてください")
                break
        nm = re.search(r"\bname:\s*(?:'([^']*)'|\"([^\"]*)\")", meta)
        name = (nm.group(1) or nm.group(2)) if nm else ""
        if not name:
            rep.error(where, "`meta.name` がありません")
        elif name != p.stem:
            rep.warn(where, f"`meta.name: {name}` がファイル名 `{p.stem}` と異なります")
        if not re.search(r"\bdescription:\s*['\"]", meta):
            rep.error(where, "`meta.description` がありません")
        titles = set(re.findall(r"\btitle:\s*'([^']*)'", meta)) | set(re.findall(r'\btitle:\s*"([^"]*)"', meta))
        body = text[end + 1:]
        used = set(re.findall(r"\bphase\(\s*['\"]([^'\"]*)['\"]\s*\)", body)) | set(re.findall(r"\bphase:\s*['\"]([^'\"]*)['\"]", body))
        for t in sorted(used - titles):
            rep.warn(where, f"phase `{t}` が `meta.phases` にありません")
        code = "\n".join(l for l in body.splitlines() if not l.strip().startswith("//"))
        for pat, what in (
            (r"\bDate\.now\s*\(", "Date.now()"),
            (r"\bMath\.random\s*\(", "Math.random()"),
            (r"\bnew Date\s*\(\s*\)", "引数なしの new Date()"),
            (r"\bimport\s*\(|^\s*import\s", "import"),
            (r"\brequire\s*\(", "require()"),
        ):
            if re.search(pat, code, re.M):
                rep.error(where, f"workflow では {what} を使えません(再開時の決定性 / モジュール読込不可)")
        node = shutil.which("node")
        if node:
            with tempfile.NamedTemporaryFile("w", suffix=".cjs", delete=False, encoding="utf-8") as tf:
                tf.write("const meta = " + meta + ";\n(async () => {\n" + body + "\n})();\n")
                tmp = tf.name
            try:
                proc = subprocess.run([node, "--check", tmp], capture_output=True, text=True)
            finally:
                os.unlink(tmp)
            if proc.returncode != 0:
                err = [l for l in proc.stderr.strip().splitlines() if l.strip()]
                rep.error(where, f"JavaScript 構文エラー: {(err[-1] if err else proc.stderr)[:120]}")


def check_output_styles(root: Path, rep: Report) -> None:
    """A custom output style replaces Claude Code's coding instructions unless it opts to keep them."""
    styles_dir = root / ".claude/output-styles"
    if not styles_dir.is_dir():
        return
    for p in sorted(styles_dir.glob("*.md")):
        fm = parse_frontmatter(p, rep)
        if fm is None:
            continue
        if not str(fm.get("name", "")).strip():
            rep.error(str(p), "`name` が未設定です")
        keep = str(fm.get("keep-coding-instructions", "")).strip().lower()
        if keep != "true":
            rep.warn(
                str(p),
                "`keep-coding-instructions: true` がありません — カスタム出力スタイルは"
                " Claude Code 標準のソフトウェアエンジニアリング指示(変更スコープ・検証習慣等)を丸ごと落とします",
            )


def check_rules(root: Path, rep: Report) -> None:
    rules_dir = root / ".agents/rules"
    if not rules_dir.is_dir():
        return
    for p in sorted(list(rules_dir.glob("*.md")) + list(rules_dir.glob("*.md.example"))):
        if p.name == "README.md":
            continue
        text = p.read_text(encoding="utf-8")
        m = FM_RE.match(text)
        n_lines = len(text.splitlines())
        if not m:
            if n_lines > ALWAYS_ON_RULE_WARN_LINES:
                rep.warn(
                    str(p),
                    f"`paths:` が無いため全セッションで常時 load されます ({n_lines} 行)"
                    " — 汎用でなければ `paths:` でスコープしてください",
                )
            continue
        fm = parse_frontmatter(p, rep)
        if fm and "paths" in fm and not fm["paths"]:
            rep.error(str(p), "`paths:` が空です")


def check_imports_and_limits(root: Path, rep: Report) -> None:
    claude_md = root / ".claude/CLAUDE.md"
    targets = [claude_md] if claude_md.exists() else []
    targets += sorted((root / ".claude").rglob("*.md"))

    for p in targets:
        try:
            text = p.read_text(encoding="utf-8")
        except (UnicodeDecodeError, PermissionError):
            continue
        for m in re.finditer(r"(?m)^@([\w./-]+)", text):
            target = m.group(1)
            # CLAUDE.md はターゲットプロジェクトのルートに置かれる前提で書かれている。
            candidates = [root / target, root / ".claude" / target, p.parent / target]
            if not any(c.exists() for c in candidates):
                rep.error(str(p), f"`@{target}` の import 先が存在しません")

    # AGENTS.md はツール共通ルール。Claude Code 以外は @import を解釈しないため行頭 `@` を禁じ、
    # CLAUDE.md が取り込み忘れると Claude Code からは読まれない(CLAUDE.md があると直接は読まない)。
    agents_md = root / "AGENTS.md"
    agents_lines = 0
    if agents_md.exists():
        agents_text = agents_md.read_text(encoding="utf-8")
        agents_lines = len(agents_text.splitlines())
        for m in re.finditer(r"(?m)^@([\w./-]+)", strip_fences(agents_text)):
            rep.error(str(agents_md), f"行頭の `@{m.group(1)}` — Claude Code 以外は import を解釈しません。パスを本文で示してください")
        # コードブロック内の `@AGENTS.md` は import として展開されないため数えない
        if claude_md.exists() and not re.search(r"(?m)^@AGENTS\.md\s*$", strip_fences(claude_md.read_text(encoding="utf-8"))):
            rep.error(str(claude_md), "`@AGENTS.md` の取り込みがありません — CLAUDE.md があると Claude Code は AGENTS.md を読みません")

    # 常時 load される指示ファイルが指す `project-config.md` の §番号は見出しとして実在しなければならない
    # (AGENTS.md は他エージェントを §13.7 へ誘導するため、番号ずれは権限の取り違えになる)。
    config = root / "project-config.md"
    if config.exists():
        headings = set(re.findall(r"(?m)^#{2,3} (\d+(?:\.\d+[a-z]?)?)[. ]", config.read_text(encoding="utf-8")))
        for p in (agents_md, claude_md):
            if not p.exists():
                continue
            for sec in sorted(set(re.findall(r"§(\d+(?:\.\d+)?)", p.read_text(encoding="utf-8")))):
                if sec not in headings:
                    rep.error(str(p), f"`project-config.md` §{sec} の見出しが存在しません")

    if claude_md.exists():
        n = len(claude_md.read_text(encoding="utf-8").splitlines()) + agents_lines
        label = "CLAUDE.md + AGENTS.md の合計" if agents_lines else "CLAUDE.md"
        if n > CLAUDE_MD_HARD_LIMIT:
            rep.error(str(claude_md), f"{label} {n} 行 — constitution §6 のハード上限 {CLAUDE_MD_HARD_LIMIT} 行を超えています")
        elif n > CLAUDE_MD_SOFT_LIMIT:
            rep.warn(str(claude_md), f"{label} {n} 行 — 目安の {CLAUDE_MD_SOFT_LIMIT} 行を超えています")


def check_instruction_phrasing(root: Path, rep: Report) -> None:
    """Claude が読む指示ファイルに残った旧世代向けの強調・思考誘導(公式 best-practices「What you can stop doing」)。
    現行モデルは平叙文に従い、強調は過剰適用を、`think hard` は effort と無関係な文字列として扱われる。"""
    c, shared = root / ".claude", root / ".agents"
    targets = [c / "CLAUDE.md", root / "AGENTS.md", c / "loop.md"]
    for sub in ("agents", "output-styles"):
        targets += sorted((c / sub).glob("*.md"))
    targets += sorted((shared / "rules").glob("*.md"))
    targets += sorted((shared / "skills").glob("*/SKILL.md"))
    for p in targets:
        if not p.is_file() or p.name == "README.md":
            continue
        text = re.sub(r"`[^`\n]*`", "", strip_fences(p.read_text(encoding="utf-8")))
        for rx, msg in (
            (LEGACY_EMPHASIS_RE, "は現行モデルで規則の過剰適用を招きます — 平叙文にし、例外の無い規則はフック / deny にしてください"),
            (LEGACY_THINK_RE, "は推論量を上げません(effort が制御します) — 消すか、その 1 ターンだけなら ultrathink にしてください"),
        ):
            m = rx.search(text)
            if m:
                rep.warn(str(p), f"`{m.group(0)}` {msg}")


def check_loop_md(root: Path, rep: Report) -> None:
    """`.claude/loop.md`(bare `/loop` の既定プロンプト)は 25,000 文字を超えた分が読まれない。"""
    p = root / ".claude/loop.md"
    if p.exists() and len(p.read_text(encoding="utf-8")) > LOOP_MD_MAX_CHARS:
        rep.warn(str(p), f"{LOOP_MD_MAX_CHARS:,} 文字を超えています — 超過分は /loop に読まれません")


def check_constitution(root: Path, rep: Report) -> None:
    con = root / "constitution.md"
    digest_file = root / ".agents/.constitution.sha256"
    if not con.exists() or not digest_file.exists():
        return
    import hashlib

    actual = hashlib.sha256(con.read_bytes()).hexdigest()
    expected = digest_file.read_text(encoding="utf-8").strip()
    if actual != expected:
        rep.error(
            str(digest_file),
            f"constitution.md の hash 不一致 (期待 {expected[:12]}… / 実際 {actual[:12]}…)"
            " — 同じ PR で hash を再計算してください",
        )


NPM_SPEC_RE = re.compile(r"^(@?[\w.-]+(?:/[\w.-]+)?)(?:@([\w.^~<>=*-]+))?$")
EXACT_VERSION_RE = re.compile(r"^\d+\.\d+\.\d+(?:[-+][\w.-]+)?$")


def collect_npx_specs(obj, active: bool, out: dict) -> None:
    """Walk the MCP template and collect `npx -y <spec>` package specs.

    Servers under the top-level `mcpServers` are *active* (must be version-pinned);
    everything else (`_example` blocks) only has to resolve.
    """
    if isinstance(obj, dict):
        args = obj.get("args")
        if isinstance(args, list) and "-y" in args:
            idx = args.index("-y")
            if idx + 1 < len(args) and isinstance(args[idx + 1], str):
                spec = args[idx + 1]
                out[spec] = out.get(spec, False) or active
        for k, v in obj.items():
            collect_npx_specs(v, active and not str(k).startswith("_"), out)
    elif isinstance(obj, list):
        for v in obj:
            collect_npx_specs(v, active, out)


def check_mcp_template(root: Path, rep: Report, online: bool) -> None:
    """`.mcp.json.template`: every `npx -y <pkg>` must be pinned to an exact version
    (ERROR for active servers, WARN for `_example` blocks); with --online the packages
    must also resolve on the registry and not be deprecated."""
    tmpl = root / ".mcp.json.template"
    if not tmpl.exists():
        return
    try:
        cfg = json.loads(tmpl.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return   # check_json_files already reported it
    specs: dict = {}
    collect_npx_specs(cfg.get("mcpServers", {}), True, specs)
    for k, v in cfg.items():
        if k != "mcpServers":
            collect_npx_specs(v, False, specs)

    for spec, active in sorted(specs.items()):
        m = NPM_SPEC_RE.match(spec)
        if not m:
            continue
        name, ver = m.group(1), m.group(2)
        if not ver or not EXACT_VERSION_RE.match(ver):
            msg = (f"npm パッケージ `{name}` がバージョン固定されていません"
                   " — サプライチェーン対策として `name@x.y.z` で固定してください")
            if active:
                rep.error(str(tmpl), "有効な MCP サーバーの " + msg)
            else:
                rep.warn(str(tmpl), "例示ブロックの " + msg)
        if not online:
            continue
        target = f"{name}@{ver}" if ver else name
        res = subprocess.run(["npm", "view", target, "version"], capture_output=True, text=True)
        if res.returncode != 0 or not res.stdout.strip():
            rep.error(str(tmpl), f"npm パッケージ `{target}` が解決できません")
            continue
        dep = subprocess.run(["npm", "view", name, "deprecated"], capture_output=True, text=True)
        if dep.stdout.strip():
            rep.warn(str(tmpl), f"npm パッケージ `{name}` は deprecated です: {dep.stdout.strip()[:70]}")


RELEASE_HEADING_RE = re.compile(r"^## \[(\d+\.\d+\.\d+)\]", re.M)


def check_release_version(repo: Path, rep: Report) -> None:
    """`VERSION` must be x.y.z and equal the newest release heading in CHANGELOG.md
    (both are bumped together by scripts/release.sh; setup.sh stamps the value into
    the target project's manifest, so a stale VERSION breaks `--upgrade` reporting)."""
    vf, cl = repo / "VERSION", repo / "CHANGELOG.md"
    if not vf.exists() or not cl.exists():
        return
    version = vf.read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        rep.error("VERSION", f"`{version}` は x.y.z 形式ではありません")
        return
    text = cl.read_text(encoding="utf-8")
    m = RELEASE_HEADING_RE.search(text)
    if m and m.group(1) != version:
        rep.error("VERSION", f"VERSION `{version}` と CHANGELOG.md の最新リリース見出し `{m.group(1)}` が一致しません"
                  " — `bash scripts/release.sh prepare <version>` で同時に更新する")
    if "## [Unreleased]" not in text:
        rep.warn("CHANGELOG.md", "`## [Unreleased]` 節がありません(Keep a Changelog)")


# ── Codex アダプタ(.codex/)と共通の核(.agents/)────────────────────────────

def parse_toml_light(text: str) -> dict[str, dict[str, object]]:
    """`.codex/config.toml` を {テーブル名: {キー: 値}} に読む(最上位は "")。

    Python 3.11 未満には tomllib が無いため、ここで使う範囲(文字列・真偽値・数値のスカラーと
    複数行文字列)だけを解釈する。配列やインラインテーブルの値は生の文字列のまま返す。
    """
    tables: dict[str, dict[str, object]] = {"": {}}
    current = ""
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        i += 1
        if not line or line.startswith("#"):
            continue
        m = re.match(r"^\[\[?(.+?)\]\]?\s*(#.*)?$", line)
        if m:
            current = m.group(1).strip()
            tables.setdefault(current, {})
            continue
        m = re.match(r'^(?:"([^"]+)"|\'([^\']+)\'|([A-Za-z0-9_.-]+))\s*=\s*(.*)$', line)
        if not m:
            continue
        key = m.group(1) or m.group(2) or m.group(3)
        raw = m.group(4).strip()
        if raw.startswith('"""') or raw.startswith("'" * 3):
            quote = raw[:3]
            body = raw[3:]
            while quote not in body and i < len(lines):
                body += "\n" + lines[i]
                i += 1
            tables[current][key] = body.split(quote)[0]
            continue
        sm = re.match(r'^"((?:[^"\\]|\\.)*)"', raw) or re.match(r"^'([^']*)'", raw)
        if sm:
            tables[current][key] = sm.group(1)
        elif re.match(r"^(true|false)\b", raw):
            tables[current][key] = raw.startswith("true")
        else:
            tables[current][key] = re.sub(r"\s+#.*$", "", raw)
    return tables


def check_codex_hooks(root: Path, rep: Report) -> set[str]:
    """`.codex/hooks*.json`: 共有フックをアダプタ経由で登録しているか。参照されたフックの集合を返す。"""
    referenced: set[str] = set()
    codex = root / ".codex"
    if not codex.is_dir():
        return referenced
    hooks_dir = root / ".agents/hooks"
    adapter = root / CODEX_ADAPTER_REL
    if not adapter.is_file():
        rep.error(str(adapter), "Codex 用アダプタがありません — .codex/hooks.json が共有フックを呼べません")
    elif not adapter.stat().st_mode & 0o111:
        rep.error(str(adapter), "実行権限がありません (chmod +x)")
    else:
        proc = subprocess.run(["bash", "-n", str(adapter)], capture_output=True, text=True)
        if proc.returncode != 0:
            rep.error(str(adapter), f"シェル構文エラー: {proc.stderr.strip()[:120]}")

    for name in ("hooks.json", "hooks.minimal.json"):
        p = codex / name
        if not p.exists():
            continue
        where = str(p)
        try:
            cfg = json.loads(p.read_text(encoding="utf-8"))
        except Exception:  # noqa: BLE001 - check_json_files が報告する
            continue
        blocking_seen: set[str] = set()
        for event, groups in (cfg.get("hooks") or {}).items():
            if event not in CODEX_HOOK_EVENTS:
                rep.error(where, f"`{event}` は Codex のフックイベント名ではありません(Claude Code 専用のイベントは .claude/settings.json に書く)")
            for group in groups or []:
                if event in CODEX_NO_MATCHER_EVENTS and group.get("matcher"):
                    rep.warn(where, f"{event} の matcher は Codex では無視されます")
                for hook in group.get("hooks", []):
                    htype = hook.get("type")
                    if htype not in CODEX_HOOK_TYPES:
                        rep.error(where, f"{event} のフック type `{htype}` は Codex では実行されません(command / mcp_tool のみ)")
                    for key in sorted(CODEX_CLAUDE_ONLY_HOOK_KEYS & set(hook)):
                        rep.warn(where, f"{event} のフックにある `{key}` は Claude Code 専用のキーです(Codex は解釈しません)")
                    timeout = hook.get("timeout")
                    if event in ("SessionEnd", "Interrupt") and isinstance(timeout, (int, float)) and timeout > CODEX_SESSION_END_MAX_TIMEOUT:
                        rep.warn(where, f"{event} の timeout {timeout} 秒は上限({CODEX_SESSION_END_MAX_TIMEOUT} 秒)を超えています")
                    cmd = str(hook.get("command", ""))
                    if htype != "command":
                        continue
                    m = CODEX_ADAPTER_RE.search(cmd)
                    if not m:
                        rep.warn(where, f"{event} のフックがアダプタ(lib/codex-adapter.sh)を通していません — apply_patch の入力が変換されず、共有フックがファイルパスを読めません")
                        continue
                    script = m.group(2)
                    referenced.add(script)
                    if not (hooks_dir / script).exists():
                        rep.error(where, f"{event} が参照する {script} が存在しません")
                    if event == "PreToolUse" and script in CODEX_BLOCKING_SCRIPTS:
                        blocking_seen.add(script)
                        if not m.group(1):
                            rep.warn(where, f"PreToolUse のブロック系フック({script})に `--fail-closed` がありません — フック本体が無いとき操作が素通りします(Codex には onFailure: block が無い)")
        for script in sorted(CODEX_BLOCKING_SCRIPTS - blocking_seen):
            rep.error(where, f"PreToolUse に {script} が登録されていません — Layer 1 のブロック系フックは Codex 側にも必要です(constitution ⑤)")
    return referenced


def check_codex_config(root: Path, rep: Report) -> dict[str, object]:
    """`.codex/config.toml`: 防御層を弱める設定・効かないキー・権限プロファイルの穴。deny エントリを返す。"""
    p = root / ".codex/config.toml"
    if not p.exists():
        if (root / ".codex").is_dir():
            rep.error(str(p), ".codex/ がありますが config.toml がありません")
        return {}
    where = str(p)
    tables = parse_toml_light(p.read_text(encoding="utf-8"))
    top = tables.get("", {})

    if top.get("approval_policy") == "never":
        rep.error(where, '`approval_policy = "never"` は確認なしで実行します — 共有設定では使えません(constitution ⑤)')
    for key in sorted(CODEX_PROJECT_IGNORED_KEYS & (set(top) | {t.split(".")[0] for t in tables if t})):
        rep.warn(where, f"`{key}` はプロジェクトの config.toml では無視されます(~/.codex/config.toml に書く)")
    if tables.get("features", {}).get("hooks") is False:
        rep.error(where, "`[features] hooks = false` はフックを一括で止めます(constitution ⑤)")

    profile = top.get("default_permissions")
    has_legacy = "sandbox_mode" in top or "sandbox_workspace_write" in tables
    if profile and has_legacy:
        rep.error(where, "`default_permissions` と `sandbox_mode` / `[sandbox_workspace_write]` が両方あります — Codex は旧来の設定を使い、権限プロファイル(シークレットの読取禁止)が効かなくなります")
    if not profile:
        rep.warn(where, "`default_permissions` がありません — シークレットの読取禁止(Claude Code の Read() deny に当たる層)が Codex 側にありません")
        return {}
    if profile == ":danger-full-access":
        rep.error(where, "`default_permissions = \":danger-full-access\"` はサンドボックスを外します(constitution ⑤)")
        return {}
    if str(profile).startswith(":"):
        rep.warn(where, f"組み込みプロファイル `{profile}` を使っています — シークレットの読取禁止を足すには独自プロファイルが必要です")
        return {}
    if f"permissions.{profile}" not in tables:
        rep.error(where, f"`default_permissions = \"{profile}\"` に対応する `[permissions.{profile}]` がありません")
        return {}
    roots_table = tables.get(f'permissions.{profile}.filesystem.":workspace_roots"', {})
    for path in CODEX_PROTECTED_PATHS:
        if roots_table.get(path) not in ("read", "deny"):
            rep.error(where, f"権限プロファイルで `{path}` が読取専用になっていません — Codex がハーネス自体を書き換えられます"
                             "(`extends = \":workspace\"` だけでは、codex-cli 0.162 系で保護が継がれません。0.162.1 実測)")
    if tables.get(f"permissions.{profile}.network", {}).get("enabled") is True:
        rep.warn(where, "権限プロファイルがネットワークを常時許可しています — 外向き通信は都度の確認に任せるのが既定です")
    return {k: v for k, v in roots_table.items() if v == "deny"}


def parse_codex_rules(path: Path, rep: Report) -> list[tuple[list, str]]:
    """`.rules`(Starlark)から (pattern, decision) を取り出す。pattern のリスト記法は Python と同じ。"""
    import ast

    out: list[tuple[list, str]] = []
    for block in re.findall(r"prefix_rule\((.*?)\n\)", path.read_text(encoding="utf-8"), flags=re.S):
        pm = re.search(r"pattern\s*=\s*(\[.*?\]),\s*\n", block, flags=re.S)
        if not pm:
            rep.error(str(path), "prefix_rule に `pattern` がありません")
            continue
        try:
            pattern = ast.literal_eval(pm.group(1))
        except Exception:  # noqa: BLE001
            rep.error(str(path), f"prefix_rule の pattern を解釈できません: {pm.group(1)[:60]}")
            continue
        dm = re.search(r'decision\s*=\s*"([^"]*)"', block)
        decision = dm.group(1) if dm else "allow"
        if decision not in ("allow", "prompt", "forbidden"):
            rep.error(str(path), f"prefix_rule の decision `{decision}` は不正です(allow / prompt / forbidden)")
            continue
        if decision == "allow":
            rep.warn(str(path), f"共有の rules に allow があります({pattern})— サンドボックスの外で確認なしに実行されます。個人の許可は ~/.codex/rules/ に置く")
        if not re.search(r"match\s*=\s*\[", block):
            rep.warn(str(path), f"prefix_rule({pattern})に `match` の例がありません — 読み込み時の自己テストが効きません")
        out.append((pattern, decision))
    return out


def claude_rule_head(rule: str) -> tuple[list[str], bool] | None:
    """`Bash(git push --force *)` → (["git", "push", "--force"], False)。先頭が `*` の規則は None(prefix で書けない)。

    2 番目の値は「先頭トークンが前方一致」(`mkfs*` など)であることを示す。
    """
    m = re.match(r"^Bash\((.*)\)$", rule)
    if not m:
        return None
    tokens = m.group(1).replace(":*", " *").split()
    if not tokens or tokens[0].startswith("*"):
        return None
    head: list[str] = []
    for tok in tokens:
        if "*" in tok:
            lit = tok.split("*")[0]
            if not head and lit and "=" not in lit:
                return [lit], True
            break
        head.append(tok)
    return (head, False) if head else None


def codex_rule_covers(rules: list[tuple[list, str]], head: list[str], prefix: bool, decisions: set[str]) -> bool:
    for pattern, decision in rules:
        if decision not in decisions or len(pattern) != len(head):
            continue
        ok = True
        for i, tok in enumerate(head):
            alts = pattern[i] if isinstance(pattern[i], list) else [pattern[i]]
            if prefix and i == 0:
                ok = any(str(a).startswith(tok) for a in alts)
            else:
                ok = tok in alts
            if not ok:
                break
        if ok:
            return True
    return False


def check_codex_parity(root: Path, codex_deny: dict[str, object], rep: Report) -> None:
    """Claude Code の deny / ask と Codex の rules / 権限プロファイルが同じ意図になっているか。"""
    settings = root / ".claude/settings.json"
    rules_file = root / ".codex/rules/default.rules"
    if not (root / ".codex").is_dir():
        return
    if not rules_file.exists():
        rep.error(str(rules_file), "Codex のコマンド規則がありません — Claude Code の deny / ask に当たる層が Codex 側にありません")
        return
    rules = parse_codex_rules(rules_file, rep)
    if not settings.exists():
        return
    perms = json.loads(settings.read_text(encoding="utf-8")).get("permissions", {})
    for bucket, decisions, label in (("deny", {"forbidden"}, "forbidden"), ("ask", {"prompt", "forbidden"}, "prompt")):
        for rule in perms.get(bucket, []):
            parsed = claude_rule_head(rule)
            if parsed is None:
                continue
            head, prefix = parsed
            if not codex_rule_covers(rules, head, prefix, decisions):
                rep.error(str(rules_file), f"Claude Code の {bucket} `{rule}` に対応する {label} 規則がありません(pattern = {head})")

    def claude_key(rule: str) -> str | None:
        m = re.match(r"^Read\((.*)\)$", rule)
        if not m:
            return None
        key = m.group(1)
        key = key[2:] if key.startswith("./") else key
        return key[:-3] if key.endswith("/**") else key

    def codex_key(key: str) -> str:
        return key[3:] if key.startswith("**/") else key

    claude_keys = {k for k in (claude_key(r) for r in perms.get("deny", [])) if k}
    codex_keys = {codex_key(k) for k in codex_deny}
    config = str(root / ".codex/config.toml")
    for key in sorted(claude_keys - codex_keys):
        rep.error(config, f"Claude Code が読取を禁じている `{key}` が Codex の権限プロファイルで deny になっていません")
    for key in sorted(codex_keys - claude_keys):
        rep.error(str(settings), f"Codex が読取を禁じている `{key}` に対応する `Read()` deny が Claude Code 側にありません")


def check_codex_agents(root: Path, rep: Report) -> None:
    """`.codex/agents/*.toml` が原本(`.claude/agents/*.md`)から生成し直した内容と一致するか。"""
    if not (root / ".codex").is_dir() or not (root / ".claude/agents").is_dir():
        return
    try:
        want = sync_codex_agents.expected_files(root)
    except ValueError as exc:
        rep.error(str(root / ".claude/agents"), f"Codex 用エージェントを生成できません: {exc}")
        return
    for path, content in want.items():
        if not path.is_file():
            rep.error(str(path), f"原本 .claude/agents/{path.stem}.md に対応する Codex 用エージェントがありません(python3 scripts/sync_codex_agents.py)")
        elif path.read_text(encoding="utf-8") != content:
            rep.error(str(path), "原本(.claude/agents/)とずれています — 直接編集せず、python3 scripts/sync_codex_agents.py で再生成してください")
    for extra in sorted((root / ".codex/agents").glob("*.toml")):
        if extra not in want:
            rep.error(str(extra), "原本(.claude/agents/)に無いエージェントです — 原本を足して再生成するか、このファイルを消してください")


def check_shared_layout(root: Path, rep: Report) -> None:
    """共通の核は .agents/ に 1 つだけ置く。.claude/ 側に実体が残っていれば二重管理になる。"""
    claude = root / ".claude"
    if not claude.is_dir() or not (root / ".agents").is_dir():
        return
    for name in MOVED_OUT_OF_CLAUDE:
        if (claude / name).exists():
            rep.error(str(claude / name), f"1.0 の配置では `.agents/{name}` に置きます(.claude/ は Claude Code 専用のアダプタ)")
    for name in SHARED_VIA_LINK:
        d = claude / name
        if not d.is_dir():
            continue
        for entry in sorted(d.iterdir()):
            if entry.is_symlink() and os.readlink(entry).startswith("../../.agents/"):
                continue
            if (root / ".agents" / name / entry.name).exists():
                rep.error(str(entry), f"`.agents/{name}/{entry.name}` と二重になっています — 原本は .agents/ 側だけに置き、.claude/ 側は setup.sh のリンクに任せます")
            else:
                rep.warn(str(entry), f"`.claude/{name}/` に実体があります — Codex からは見えません。`.agents/{name}/` へ移して setup.sh --relink してください")
    for skill in sorted((root / ".agents/skills").glob("*/SKILL.md")):
        m = FM_RE.match(skill.read_text(encoding="utf-8"))
        if not m or not re.search(r"^disable-model-invocation:\s*true\s*$", m.group(1), flags=re.M):
            continue
        meta = skill.parent / "agents/openai.yaml"
        if not meta.exists() or not re.search(r"allow_implicit_invocation:\s*false", meta.read_text(encoding="utf-8")):
            rep.error(str(skill), "`disable-model-invocation: true` の skill に `agents/openai.yaml`(`policy.allow_implicit_invocation: false`)がありません"
                                  " — Codex ではプロンプトから自動起動されます")


def check_mirror_parity(a: Path, b: Path, rep: Report) -> None:
    def tree(root: Path) -> set[str]:
        return {
            str(p.relative_to(root))
            for p in root.rglob("*")
            if p.is_file() and "output/reports" not in str(p.relative_to(root))
        }

    only_a, only_b = tree(a) - tree(b), tree(b) - tree(a)
    for f in sorted(only_a):
        rep.error("mirror parity", f"{a.name} にのみ存在: {f}")
    for f in sorted(only_b):
        rep.error("mirror parity", f"{b.name} にのみ存在: {f}")
    # 導入・移行スクリプトは日英で同一のファイル(メッセージだけ言語で切り替える)。片方だけ直すと挙動がずれる
    for name in ("setup.sh", "migrate.sh"):
        fa, fb = a / name, b / name
        if fa.is_file() and fb.is_file() and fa.read_bytes() != fb.read_bytes():
            rep.error("mirror parity", f"{name} が日英ミラーで一致しません(同一ファイルとして保守する。片方を直したらもう片方へコピーする)")


def validate_root(root: Path, online: bool, rep: Report) -> None:
    check_json_files(root, rep)
    skill_names = check_skills(root, rep)
    check_agents(root, skill_names, rep)
    referenced = check_settings(root, rep) | check_frontmatter_hooks(root, rep) | check_codex_hooks(root, rep)
    check_hook_scripts(root, referenced, rep)
    check_codex_parity(root, check_codex_config(root, rep), rep)
    check_codex_agents(root, rep)
    check_shared_layout(root, rep)
    check_output_styles(root, rep)
    check_workflows(root, rep)
    check_rules(root, rep)
    check_imports_and_limits(root, rep)
    check_loop_md(root, rep)
    check_instruction_phrasing(root, rep)
    check_constitution(root, rep)
    check_mcp_template(root, rep, online)


def main() -> int:
    ap = argparse.ArgumentParser(description="ハーネス(.agents/ + .claude/ + .codex/)の静的検証")
    ap.add_argument("--root", action="append", default=None,
                    help="検証するハーネスのルート (省略時は日英ミラーを自動検出)")
    ap.add_argument("--online", action="store_true",
                    help="npm レジストリへの問い合わせも行う (.mcp.json.template の実在確認)")
    ap.add_argument("--no-parity", action="store_true", help="日英ミラーの構成一致チェックを省く")
    args = ap.parse_args()

    repo = Path(__file__).resolve().parent.parent
    if args.root:
        roots = [Path(r).resolve() for r in args.root]
        parity = False
    else:
        roots = [p for p in (repo / "project-blueprint", repo / "project-blueprint-en") if p.is_dir()]
        parity = len(roots) == 2 and not args.no_parity
        if not roots:
            print("ハーネスのルートが見つかりません。--root で指定してください。", file=sys.stderr)
            return 2

    rep = Report()
    for root in roots:
        if not root.is_dir():
            rep.error(str(root), "ディレクトリが存在しません")
            continue
        print(f"検証中: {root}")
        validate_root(root, args.online, rep)
    if parity:
        print("日英ミラー構成の一致を検証中")
        check_mirror_parity(roots[0], roots[1], rep)
    if not args.root:
        check_release_version(repo, rep)

    print()
    for w in rep.warnings:
        print(f"  WARN  {w}")
    for e in rep.errors:
        print(f"  ERROR {e}")

    print()
    print(f"結果: ERROR {len(rep.errors)} 件 / WARN {len(rep.warnings)} 件")
    if rep.errors:
        print("検証失敗。上記 ERROR を修正してください。")
        return 1
    print("検証成功。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
