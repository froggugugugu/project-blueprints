#!/usr/bin/env python3
"""Deterministic validator for the .claude/ harness.

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
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

try:
    import yaml  # type: ignore
except ImportError:  # pragma: no cover - CI images often lack PyYAML
    yaml = None

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
AGENT_COLORS = {"red", "blue", "green", "yellow", "purple", "orange", "pink", "cyan"}
MODEL_ALIASES = {"opus", "sonnet", "haiku", "fable", "inherit"}
EFFORT_LEVELS = {"low", "medium", "high", "xhigh", "max"}
PERMISSION_MODES = {"default", "acceptEdits", "auto", "dontAsk", "bypassPermissions", "plan", "manual"}
MEMORY_SCOPES = {"user", "project", "local"}
# project / local settings からは読まれない(公式仕様)。書いても無視される。
PROJECT_IGNORED_DEFAULT_MODES = {"auto", "bypassPermissions"}

# ファイルパス権限は Edit(path) / Read(path) だけが参照される。
# 下記ツールにパス指定を書いても一切参照されず、起動時に警告が出る。
NEVER_CONSULTED_PATH_TOOLS = {"Write", "NotebookEdit", "Glob", "MultiEdit"}

CLAUDE_MD_SOFT_LIMIT = 200   # constitution §6 目安
CLAUDE_MD_HARD_LIMIT = 220   # constitution §6 ハード上限
SKILL_DESC_LIMIT = 1536      # description + when_to_use はこの文字数で切り詰められる
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
        m = re.match(r"^([A-Za-z_][\w]*)\((.+)\)$", rule.strip())
        if not m:
            continue
        tool, spec = m.group(1), m.group(2)
        if tool in NEVER_CONSULTED_PATH_TOOLS and ":" not in spec:
            rep.error(
                where,
                f"`{rule}` は参照されません — ファイルパス権限は Edit(path)/Read(path) "
                f"のみ評価されます。`Edit({spec})` に書き換えてください",
            )


def check_settings(root: Path, rep: Report) -> set[str]:
    """Validate settings*.json. Returns the set of hook scripts referenced."""
    referenced: set[str] = set()
    hooks_dir = root / ".claude/hooks"

    for name in ("settings.json", "settings.minimal.json"):
        p = root / ".claude" / name
        if not p.exists():
            continue
        cfg = json.loads(p.read_text(encoding="utf-8"))
        where = str(p)

        perms = cfg.get("permissions", {})
        for bucket in ("allow", "deny", "ask"):
            check_permission_rules(f"{where} [permissions.{bucket}]", perms.get(bucket, []), rep)
        check_project_scope_keys(where, cfg, rep)

        for event, groups in cfg.get("hooks", {}).items():
            if event not in HOOK_EVENTS:
                rep.error(where, f"`{event}` は公式のフックイベント名ではありません")
            for group in groups:
                for hook in group.get("hooks", []):
                    check_hook_handler(f"{where} [hooks.{event}]", hook, rep)
                    cmd = hook.get("command", "")
                    m = re.search(r"/\.claude/hooks/([\w.-]+\.sh)", cmd)
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
        check_project_scope_keys(str(local), cfg, rep)
        for event, groups in cfg.get("hooks", {}).items():
            if event not in HOOK_EVENTS:
                rep.error(str(local), f"`{event}` は公式のフックイベント名ではありません")
            for group in groups:
                for hook in group.get("hooks", []):
                    check_hook_handler(f"{local} [hooks.{event}]", hook, rep)

    return referenced


def check_hook_handler(where: str, hook: dict, rep: Report) -> None:
    """Validate one hook handler object against the official field list."""
    htype = hook.get("type")
    if htype not in HOOK_TYPES:
        rep.error(where, f"`type: {htype}` は公式のフックタイプではありません ({', '.join(sorted(HOOK_TYPES))})")
        return
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


def check_hook_scripts(root: Path, referenced: set[str], rep: Report) -> None:
    hooks_dir = root / ".claude/hooks"
    if not hooks_dir.is_dir():
        return
    for p in sorted(hooks_dir.glob("*.sh")):
        if not p.stat().st_mode & 0o111:
            rep.error(str(p), "実行権限がありません (chmod +x)")
        proc = subprocess.run(["bash", "-n", str(p)], capture_output=True, text=True)
        if proc.returncode != 0:
            rep.error(str(p), f"シェル構文エラー: {proc.stderr.strip()[:120]}")
        if p.name not in referenced:
            rep.warn(str(p), "settings.json のどのイベントにも登録されていません")


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

        for skill in fm.get("skills") or []:
            if str(skill).strip() not in skill_names:
                rep.error(where, f"`skills:` が参照する `{skill}` が .claude/skills/ に存在しません")


def check_skills(root: Path, rep: Report) -> set[str]:
    skills_dir = root / ".claude/skills"
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

        desc = str(fm.get("description", "")) + str(fm.get("when_to_use", ""))
        if not desc.strip():
            rep.error(where, "`description` が未設定です")
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
    rules_dir = root / ".claude/rules"
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

    if claude_md.exists():
        n = len(claude_md.read_text(encoding="utf-8").splitlines())
        if n > CLAUDE_MD_HARD_LIMIT:
            rep.error(str(claude_md), f"{n} 行 — constitution §6 のハード上限 {CLAUDE_MD_HARD_LIMIT} 行を超えています")
        elif n > CLAUDE_MD_SOFT_LIMIT:
            rep.warn(str(claude_md), f"{n} 行 — 目安の {CLAUDE_MD_SOFT_LIMIT} 行を超えています")


def check_constitution(root: Path, rep: Report) -> None:
    con = root / "constitution.md"
    digest_file = root / ".claude/.constitution.sha256"
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


def check_npm_packages(root: Path, rep: Report) -> None:
    tmpl = root / ".mcp.json.template"
    if not tmpl.exists():
        return
    cfg = json.loads(tmpl.read_text(encoding="utf-8"))
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
        if active and not ver:
            rep.warn(
                str(tmpl),
                f"有効な MCP サーバーの npm パッケージ `{name}` がバージョン固定されていません"
                " — サプライチェーン対策として `name@<version>` で固定してください",
            )
        target = f"{name}@{ver}" if ver else name
        res = subprocess.run(["npm", "view", target, "version"], capture_output=True, text=True)
        if res.returncode != 0 or not res.stdout.strip():
            rep.error(str(tmpl), f"npm パッケージ `{target}` が解決できません")
            continue
        dep = subprocess.run(["npm", "view", name, "deprecated"], capture_output=True, text=True)
        if dep.stdout.strip():
            rep.warn(str(tmpl), f"npm パッケージ `{name}` は deprecated です: {dep.stdout.strip()[:70]}")


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


def validate_root(root: Path, online: bool, rep: Report) -> None:
    check_json_files(root, rep)
    skill_names = check_skills(root, rep)
    check_agents(root, skill_names, rep)
    referenced = check_settings(root, rep)
    check_hook_scripts(root, referenced, rep)
    check_output_styles(root, rep)
    check_rules(root, rep)
    check_imports_and_limits(root, rep)
    check_constitution(root, rep)
    if online:
        check_npm_packages(root, rep)


def main() -> int:
    ap = argparse.ArgumentParser(description="`.claude/` ハーネスの静的検証")
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
