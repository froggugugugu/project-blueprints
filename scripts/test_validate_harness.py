#!/usr/bin/env python3
"""Negative tests for scripts/validate_harness.py.

A validator that passes everything is worthless, so every check gets a case that
must fail. Each case runs against a throwaway copy of the JP mirror with one
defect injected — all of them are defects that were actually found in this
repository at some point.

    python3 scripts/test_validate_harness.py
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "project-blueprint"
VALIDATOR = REPO / "scripts" / "validate_harness.py"


def run(root: Path) -> str:
    proc = subprocess.run(
        [sys.executable, str(VALIDATOR), "--root", str(root), "--no-parity"],
        capture_output=True, text=True,
    )
    return proc.stdout + proc.stderr


def case(name: str, mutate, expect: str) -> bool:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td) / "harness"
        shutil.copytree(SRC, root, symlinks=True)
        mutate(root)
        out = run(root)
        ok = expect in out
        print(f"  [{'PASS' if ok else 'FAIL'}] {name}")
        if not ok:
            print(f"        期待した文字列: {expect}")
            for line in out.splitlines():
                if "ERROR" in line or "WARN" in line:
                    print("        got:", line.strip()[:150])
        return ok


def repo_case(name: str, mutate, expect: str) -> bool:
    """Like case(), but for repository-level checks (VERSION ↔ CHANGELOG): copies both
    mirrors plus the validator so it runs in auto-detect mode."""
    with tempfile.TemporaryDirectory() as td:
        root = Path(td) / "repo"
        root.mkdir()
        for item in ("project-blueprint", "project-blueprint-en"):
            shutil.copytree(REPO / item, root / item, symlinks=True)
        (root / "scripts").mkdir()
        shutil.copy2(VALIDATOR, root / "scripts" / "validate_harness.py")
        shutil.copy2(VALIDATOR.parent / "sync_codex_agents.py", root / "scripts" / "sync_codex_agents.py")
        for f in ("VERSION", "CHANGELOG.md"):
            shutil.copy2(REPO / f, root / f)
        mutate(root)
        proc = subprocess.run([sys.executable, str(root / "scripts" / "validate_harness.py")],
                              capture_output=True, text=True)
        out = proc.stdout + proc.stderr
        ok = expect in out
        print(f"  [{'PASS' if ok else 'FAIL'}] {name}")
        if not ok:
            print(f"        期待した文字列: {expect}")
            for line in out.splitlines():
                if "ERROR" in line or "WARN" in line:
                    print("        got:", line.strip()[:150])
        return ok


# ── 注入する不具合(すべて実際にこのリポジトリで発生したもの) ──────────
def m_color(root: Path) -> None:
    p = root / ".claude/agents/explorer.md"
    p.write_text(p.read_text().replace("color: blue", "color: magenta"))


def m_write_rule(root: Path) -> None:
    p = root / ".agents/skills/prd/SKILL.md"
    p.write_text(p.read_text().replace("Edit(output/**)", "Write(output/**)"))


def m_bad_yaml(root: Path) -> None:
    p = root / ".agents/skills/adr/SKILL.md"
    t = re.sub(r"(?m)^description: >\n(  .*\n)+",
               "description: Records decisions. Triggers: adr, decision-log.\n",
               p.read_text(), count=1)
    p.write_text(t)


def m_missing_hook(root: Path) -> None:
    (root / ".agents/hooks/post-compact-restore.sh").unlink()


def m_bad_event(root: Path) -> None:
    p = root / ".claude/settings.json"
    cfg = json.loads(p.read_text())
    cfg["hooks"]["PostToolUseFailed"] = cfg["hooks"].pop("PostToolUseFailure")
    p.write_text(json.dumps(cfg, indent=2))


def m_constitution(root: Path) -> None:
    p = root / "constitution.md"
    p.write_text(p.read_text() + "\n<!-- tampered -->\n")


def m_bad_import(root: Path) -> None:
    p = root / ".claude/CLAUDE.md"
    p.write_text(p.read_text() + "\n@docs/does-not-exist.md\n")


def m_context_main(root: Path) -> None:
    p = root / ".agents/skills/refactoring/SKILL.md"
    p.write_text(p.read_text().replace("allowed-tools:", "context: main\nallowed-tools:", 1))


def m_fork_askuser(root: Path) -> None:
    p = root / ".agents/skills/brainstorm/SKILL.md"
    p.write_text(p.read_text().replace("argument-hint:", "context: fork\nargument-hint:", 1))


def m_local_deny(root: Path) -> None:
    p = root / ".claude/settings.local.json.template"
    cfg = json.loads(p.read_text())
    cfg["permissions"]["deny"] = []
    p.write_text(json.dumps(cfg, indent=2, ensure_ascii=False))


def m_nonexec_hook(root: Path) -> None:
    (root / ".agents/hooks/safety-check.sh").chmod(0o644)


def m_shell_syntax(root: Path) -> None:
    p = root / ".agents/hooks/console-warn.sh"
    p.write_text(p.read_text() + "\nif [[ 1 -eq 1 ]]; then\n")


def m_bad_json(root: Path) -> None:
    (root / ".mcp.json.template").write_text("{ not json")


def m_bad_skill_ref(root: Path) -> None:
    p = root / ".claude/agents/planner.md"
    p.write_text(p.read_text().replace("  - adr", "  - nonexistent-skill"))


def m_bad_effort(root: Path) -> None:
    p = root / ".claude/agents/planner.md"
    p.write_text(p.read_text().replace("effort: high", "effort: highest"))


def m_bad_memory(root: Path) -> None:
    p = root / ".claude/agents/explorer.md"
    p.write_text(p.read_text().replace("memory: project", "memory: global"))


def m_claude_md_too_long(root: Path) -> None:
    p = root / ".claude/CLAUDE.md"
    p.write_text(p.read_text() + "\n<!-- pad -->" * 0 + "\n".join(["- pad"] * 120) + "\n")


def m_bad_hook_type(root: Path) -> None:
    p = root / ".claude/settings.json"
    cfg = json.loads(p.read_text())
    cfg["hooks"]["PreToolUse"][0]["hooks"][0]["type"] = "shell"
    p.write_text(json.dumps(cfg, indent=2))


def m_prompt_hook_without_prompt(root: Path) -> None:
    p = root / ".claude/settings.json"
    cfg = json.loads(p.read_text())
    cfg["hooks"]["Stop"] = [{"matcher": "", "hooks": [{"type": "prompt", "timeout": 30}]}]
    p.write_text(json.dumps(cfg, indent=2))


def m_project_default_mode_auto(root: Path) -> None:
    p = root / ".claude/settings.json"
    cfg = json.loads(p.read_text())
    cfg["permissions"]["defaultMode"] = "auto"
    p.write_text(json.dumps(cfg, indent=2))


def m_output_style_drops_coding(root: Path) -> None:
    p = root / ".claude/output-styles/phase-prd.md"
    p.write_text(p.read_text().replace("keep-coding-instructions: true\n", "", 1))


def m_bad_disable_model_invocation(root: Path) -> None:
    p = root / ".agents/skills/review-fix/SKILL.md"
    p.write_text(p.read_text().replace("disable-model-invocation: true", "disable-model-invocation: yes", 1))


def m_skill_at_attachment(root: Path) -> None:
    p = root / ".agents/skills/code-review/SKILL.md"
    p.write_text(p.read_text() + "\n@.agents/pitfalls.md\n")


def m_desc_first_person(root: Path) -> None:
    p = root / ".agents/skills/adr/SKILL.md"
    p.write_text(p.read_text().replace("description: >\n  ", "description: >\n  私が", 1))


def m_desc_over_spec(root: Path) -> None:
    p = root / ".agents/skills/prd/SKILL.md"
    p.write_text(p.read_text().replace("description: >\n", "description: >\n  " + "要求" * 520 + "\n", 1))


def m_evals_skill_name(root: Path) -> None:
    p = root / ".agents/skills/plan/evals/evals.json"
    data = json.loads(p.read_text())
    data["skill_name"] = "plans"
    p.write_text(json.dumps(data, ensure_ascii=False))


def m_evals_missing(root: Path) -> None:
    (root / ".agents/skills/brainstorm/evals/evals.json").unlink()


def m_reference_no_toc(root: Path) -> None:
    p = root / ".agents/skills/security-scan/references/scan-categories.md"
    p.write_text(re.sub(r"(?ms)^## 目次\n.*?(?=^## )", "", p.read_text(), count=1))


def m_workflow_date_now(root: Path) -> None:
    p = root / ".claude/workflows/review-sweep.js"
    p.write_text(p.read_text() + "\nconst stamp = Date.now()\n")


def m_workflow_meta_variable(root: Path) -> None:
    p = root / ".claude/workflows/review-sweep.js"
    p.write_text(p.read_text().replace("name: 'review-sweep',", "name: NAME,", 1))


def m_writable_agent_no_guard(root: Path) -> None:
    p = root / ".claude/agents/doc-writer.md"
    p.write_text(re.sub(r"(?ms)^hooks:\n.*?(?=^color: )", "", p.read_text(), count=1))


def m_scope_guard_unknown(root: Path) -> None:
    p = root / ".claude/agents/doc-synchronizer.md"
    p.write_text(p.read_text().replace("scope-guard.sh docs", "scope-guard.sh doc", 1))


def m_orphan_reference(root: Path) -> None:
    (root / ".agents/skills/prd/references/unused.md").write_text("# 使われていない参照\n")


def m_broken_reference_link(root: Path) -> None:
    p = root / ".agents/skills/code-review/SKILL.md"
    p.write_text(p.read_text().replace("references/report-template.md)", "references/missing.md)", 1))


def m_skill_body_too_long(root: Path) -> None:
    p = root / ".agents/skills/brainstorm/SKILL.md"
    p.write_text(p.read_text() + "\n".join(["- pad"] * 320) + "\n")


def m_agents_md_not_imported(root: Path) -> None:
    p = root / ".claude/CLAUDE.md"
    p.write_text(p.read_text().replace("@AGENTS.md\n", "", 1))


def m_agents_md_import_in_fence(root: Path) -> None:
    p = root / ".claude/CLAUDE.md"
    p.write_text(p.read_text().replace("@AGENTS.md\n", "```text\n@AGENTS.md\n```\n", 1))


def m_agents_md_at_import(root: Path) -> None:
    p = root / "AGENTS.md"
    p.write_text(p.read_text() + "\n@docs/project.md\n")


def m_agents_md_too_long(root: Path) -> None:
    p = root / "AGENTS.md"
    p.write_text(p.read_text() + "\n".join(["- pad"] * 30) + "\n")


def m_config_section_missing(root: Path) -> None:
    p = root / "project-config.md"
    p.write_text(p.read_text().replace("### 13.7 ", "### 13.8 ", 1))


def m_if_on_stop(root: Path) -> None:
    p = root / ".claude/settings.json"
    cfg = json.loads(p.read_text())
    cfg["hooks"]["Stop"][0]["hooks"][0]["if"] = "Bash(git *)"
    p.write_text(json.dumps(cfg, indent=2))


def m_agent_hook_on_permission_request(root: Path) -> None:
    p = root / ".claude/settings.json"
    cfg = json.loads(p.read_text())
    cfg["hooks"]["PermissionRequest"] = [{"matcher": "Bash", "hooks": [{"type": "agent", "prompt": "Decide"}]}]
    p.write_text(json.dumps(cfg, indent=2))


def m_rule_trailing_text(root: Path) -> None:
    p = root / ".claude/settings.json"
    cfg = json.loads(p.read_text())
    cfg["permissions"]["deny"].append("Bash(sudo *) # never")
    p.write_text(json.dumps(cfg, indent=2))


def m_rule_wildcard_before_sub(root: Path) -> None:
    p = root / ".claude/settings.local.json.template"
    cfg = json.loads(p.read_text())
    cfg["permissions"]["allow"].append("Bash(git * main)")
    p.write_text(json.dumps(cfg, indent=2, ensure_ascii=False))


def m_otel_env_in_project(root: Path) -> None:
    p = root / ".claude/settings.json"
    cfg = json.loads(p.read_text())
    cfg.setdefault("env", {})["CLAUDE_CODE_ENABLE_TELEMETRY"] = "1"
    p.write_text(json.dumps(cfg, indent=2))


def m_reserved_skill_name(root: Path) -> None:
    d = root / ".agents/skills/claude-ai"
    d.mkdir()
    (d / "SKILL.md").write_text("---\nname: claude-ai\ndescription: Reserved-name skill that must not load.\n---\n# x\n")


def m_skill_name_too_long(root: Path) -> None:
    name = "a" * 70
    d = root / ".agents/skills" / name
    d.mkdir()
    (d / "SKILL.md").write_text(f"---\nname: {name}\ndescription: Skill whose name exceeds the 64 character limit.\n---\n# x\n")


def m_skill_name_not_spec(root: Path) -> None:
    d = root / ".agents/skills/My_Skill"
    d.mkdir()
    (d / "SKILL.md").write_text("---\nname: My_Skill\ndescription: Skill whose name is outside the Agent Skills spec.\n---\n# x\n")


def m_skill_when_to_use_only(root: Path) -> None:
    d = root / ".agents/skills/no-description"
    d.mkdir()
    (d / "SKILL.md").write_text("---\nname: no-description\nwhen_to_use: Use when checking that a description is required.\n---\n# x\n")


def m_bad_omit_claude_md(root: Path) -> None:
    p = root / ".claude/agents/explorer.md"
    p.write_text(p.read_text().replace("omitClaudeMd: true", "omitClaudeMd: yes", 1))


def m_bad_on_failure(root: Path) -> None:
    p = root / ".claude/settings.json"
    p.write_text(p.read_text().replace('"onFailure": "block"', '"onFailure": "ignore"', 1))


def m_on_failure_on_prompt_hook(root: Path) -> None:
    p = root / ".claude/settings.local.json.template"
    cfg = json.loads(p.read_text())
    cfg["hooks"] = {"Stop": [{"hooks": [{"type": "prompt", "prompt": "Evaluate: $ARGUMENTS", "onFailure": "block"}]}]}
    p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2))


def m_unknown_permissions_key(root: Path) -> None:
    p = root / ".claude/settings.json"
    cfg = json.loads(p.read_text())
    cfg["permissions"]["blockReadOutsideWorkingDirectory"] = True
    p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2))


def m_user_only_key_in_project(root: Path) -> None:
    p = root / ".claude/settings.json"
    cfg = json.loads(p.read_text())
    cfg["permissions"]["denyInsteadOfPrompting"] = True
    p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2))


def m_managed_only_key_in_project(root: Path) -> None:
    p = root / ".claude/settings.local.json.template"
    cfg = json.loads(p.read_text())
    cfg["sandbox"] = {"enabled": True, "network": {"allowManagedDomainsOnly": True}}
    p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2))


def m_removed_setting(root: Path) -> None:
    p = root / ".claude/settings.json"
    cfg = json.loads(p.read_text())
    cfg["subagentStatusLine"] = {"type": "command", "command": "echo x"}
    p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2))


def m_removed_setting_task_output(root: Path) -> None:
    p = root / ".claude/settings.local.json.template"
    cfg = json.loads(p.read_text())
    cfg["taskOutputMaxChars"] = 20000
    p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2))


def m_noeffect_setting_keybinding(root: Path) -> None:
    p = root / ".claude/settings.json"
    cfg = json.loads(p.read_text())
    cfg["keybindingFlavor"] = "emacs"
    p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2))


def m_bash_allow_var_wildcard(root: Path) -> None:
    p = root / ".claude/settings.local.json.template"
    cfg = json.loads(p.read_text())
    cfg["permissions"]["allow"].append("Bash(PORT=* npm run dev)")
    p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2))


def m_legacy_emphasis(root: Path) -> None:
    p = root / ".agents/skills/plan/SKILL.md"
    p.write_text(p.read_text() + "\nIMPORTANT: タスクは必ず 5 件以内にする\n")


def m_legacy_think(root: Path) -> None:
    p = root / ".claude/agents/planner.md"
    p.write_text(p.read_text() + "\nBefore answering, think harder about edge cases.\n")


def m_safety_check_fail_open(root: Path) -> None:
    p = root / ".claude/settings.json"
    cfg = json.loads(p.read_text())
    for group in cfg["hooks"]["PreToolUse"]:
        for h in group["hooks"]:
            if "safety-check.sh" in h["command"]:
                h.pop("onFailure", None)
    p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2))


def m_filechanged_regex_matcher(root: Path) -> None:
    p = root / ".claude/settings.json"
    cfg = json.loads(p.read_text())
    cfg["hooks"]["FileChanged"][0]["matcher"] = "^constitution\\.md$"
    p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2))


def m_scope_guard_fail_open(root: Path) -> None:
    p = root / ".claude/agents/doc-writer.md"
    p.write_text(p.read_text().replace("          onFailure: block\n", "", 1))


def m_mcp_unpinned_active(root: Path) -> None:
    p = root / ".mcp.json.template"
    p.write_text(p.read_text().replace('"@upstash/context7-mcp@4.4.4"', '"@upstash/context7-mcp"'))


def m_mcp_unpinned_example(root: Path) -> None:
    p = root / ".mcp.json.template"
    p.write_text(p.read_text().replace('"@sentry/mcp-server@0.42.0"', '"@sentry/mcp-server@^0.42"'))


def m_version_mismatch(root: Path) -> None:
    (root / "VERSION").write_text("9.9.9\n")


# ── Codex アダプタ(.codex/)と共通の核(.agents/)────────────────────────────

def _codex_hooks(root: Path, fn) -> None:
    p = root / ".codex/hooks.json"
    cfg = json.loads(p.read_text())
    fn(cfg)
    p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2))


def _codex_config(root: Path, old: str, new: str) -> None:
    p = root / ".codex/config.toml"
    text = p.read_text()
    assert old in text, old
    p.write_text(text.replace(old, new, 1))


def m_codex_bad_event(root: Path) -> None:
    def fn(cfg):
        cfg["hooks"]["ConfigChange"] = cfg["hooks"]["Stop"]
    _codex_hooks(root, fn)


def m_codex_no_fail_closed(root: Path) -> None:
    def fn(cfg):
        for group in cfg["hooks"]["PreToolUse"]:
            for h in group["hooks"]:
                h["command"] = h["command"].replace("--fail-closed ", "")
    _codex_hooks(root, fn)


def m_codex_blocking_hook_unregistered(root: Path) -> None:
    def fn(cfg):
        cfg["hooks"]["PreToolUse"] = [g for g in cfg["hooks"]["PreToolUse"] if g.get("matcher") != "apply_patch"]
    _codex_hooks(root, fn)


def m_codex_hook_bypasses_adapter(root: Path) -> None:
    def fn(cfg):
        cfg["hooks"]["Stop"][0]["hooks"][0]["command"] = '"$(git rev-parse --show-toplevel)/.agents/hooks/verify-gate.sh" gate'
    _codex_hooks(root, fn)


def m_codex_hook_missing_script(root: Path) -> None:
    def fn(cfg):
        h = cfg["hooks"]["SessionStart"][0]["hooks"][0]
        h["command"] = h["command"].replace("session-start.sh", "no-such-hook.sh")
    _codex_hooks(root, fn)


def m_codex_claude_only_hook_key(root: Path) -> None:
    def fn(cfg):
        cfg["hooks"]["PreToolUse"][0]["hooks"][0]["onFailure"] = "block"
    _codex_hooks(root, fn)


def m_codex_adapter_missing(root: Path) -> None:
    (root / ".agents/hooks/lib/codex-adapter.sh").unlink()


def m_codex_approval_never(root: Path) -> None:
    _codex_config(root, 'approval_policy = "on-request"', 'approval_policy = "never"')


def m_codex_sandbox_mode_with_profile(root: Path) -> None:
    _codex_config(root, 'default_permissions = "blueprint"', 'default_permissions = "blueprint"\nsandbox_mode = "workspace-write"')


def m_codex_harness_writable(root: Path) -> None:
    _codex_config(root, '".agents" = "read"\n', "")


def m_codex_secret_readable(root: Path) -> None:
    _codex_config(root, '"**/*.pem" = "deny"\n', "")


def m_codex_ignored_key(root: Path) -> None:
    _codex_config(root, 'approval_policy = "on-request"', 'approval_policy = "on-request"\nmodel_provider = "custom"')


def m_codex_rule_missing_prompt(root: Path) -> None:
    p = root / ".codex/rules/default.rules"
    text = p.read_text()
    start = text.index('prefix_rule(\n    pattern = ["git", "push"],')
    end = text.index("\n)\n", start) + 3
    p.write_text(text[:start] + text[end:])


def m_claude_deny_without_codex_rule(root: Path) -> None:
    p = root / ".claude/settings.json"
    cfg = json.loads(p.read_text())
    cfg["permissions"]["deny"].append("Bash(shutdown *)")
    p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2))


def m_codex_agent_edited(root: Path) -> None:
    p = root / ".codex/agents/verifier.toml"
    p.write_text(p.read_text() + "\n# hand edit\n")


def m_codex_agent_missing(root: Path) -> None:
    (root / ".codex/agents/planner.toml").unlink()


def m_skill_duplicated_in_claude(root: Path) -> None:
    shutil.copytree(root / ".agents/skills/plan", root / ".claude/skills/plan")


def m_hooks_left_in_claude(root: Path) -> None:
    (root / ".claude/hooks").mkdir()
    shutil.copy2(root / ".agents/hooks/safety-check.sh", root / ".claude/hooks/safety-check.sh")


def m_manual_skill_without_codex_policy(root: Path) -> None:
    (root / ".agents/skills/review-fix/agents/openai.yaml").unlink()


def m_setup_mirror_drift(root: Path) -> None:
    p = root / "project-blueprint-en" / "setup.sh"
    p.write_text(p.read_text() + "\n# drift\n")


CASES = [
    ("color が公式 8 色外", m_color, "公式の 8 色外"),
    ("Write(path) の権限ルール", m_write_rule, "は参照されません"),
    ("frontmatter が YAML パース不能", m_bad_yaml, "パース不能"),
    ("hook の参照先が存在しない", m_missing_hook, "が存在しません"),
    ("不正な hook イベント名", m_bad_event, "公式のフックイベント名ではありません"),
    ("constitution hash 不一致", m_constitution, "hash 不一致"),
    ("@import 先が存在しない", m_bad_import, "import 先が存在しません"),
    ("context: main (無効値)", m_context_main, "`context: main` は不正"),
    ("context: fork + AskUserQuestion", m_fork_askuser, "両立しません"),
    ("local template が deny を定義", m_local_deny, "弱体化"),
    ("hook に実行権限が無い", m_nonexec_hook, "実行権限がありません"),
    ("hook のシェル構文エラー", m_shell_syntax, "シェル構文エラー"),
    ("JSON 破損", m_bad_json, "JSON パース失敗"),
    ("agent の skills 参照切れ", m_bad_skill_ref, "存在しません"),
    ("不正な effort 値", m_bad_effort, "`effort: highest` は不正"),
    ("不正な memory スコープ", m_bad_memory, "`memory: global` は不正"),
    ("CLAUDE.md がハード上限超過", m_claude_md_too_long, "ハード上限"),
    ("不正な hook type", m_bad_hook_type, "公式のフックタイプではありません"),
    ("prompt 型 hook に prompt が無い", m_prompt_hook_without_prompt, "`prompt` が必要"),
    ("project settings の defaultMode: auto", m_project_default_mode_auto, "project settings では無視"),
    ("output style が coding instructions を落とす", m_output_style_drops_coding, "keep-coding-instructions"),
    ("disable-model-invocation の非 boolean 値", m_bad_disable_model_invocation, "true / false のみ"),
    ("skill の行頭 @ 添付", m_skill_at_attachment, "起動時にファイル全文が添付"),
    ("description が一人称", m_desc_first_person, "三人称"),
    ("description が標準上限超過", m_desc_over_spec, "Agent Skills 標準の上限"),
    ("evals.json の skill_name 不一致", m_evals_skill_name, "がディレクトリ名 `plan` と一致しません"),
    ("evals.json が無い", m_evals_missing, "`evals/evals.json` がありません"),
    ("100 行超の参照に目次が無い", m_reference_no_toc, "目次がありません"),
    ("workflow で Date.now()", m_workflow_date_now, "Date.now()"),
    ("workflow meta に変数", m_workflow_meta_variable, "変数参照"),
    ("書込 agent に scope-guard が無い", m_writable_agent_no_guard, "scope-guard.sh)がありません"),
    ("scope-guard の未知スコープ", m_scope_guard_unknown, "未知のスコープ"),
    ("参照ファイルが未リンク", m_orphan_reference, "SKILL.md からリンクされていません"),
    ("references へのリンク切れ", m_broken_reference_link, "へのリンクが壊れています"),
    ("SKILL.md 本文が長すぎる", m_skill_body_too_long, "本文が"),
    ("CLAUDE.md が AGENTS.md を取り込まない", m_agents_md_not_imported, "`@AGENTS.md` の取り込みがありません"),
    ("@AGENTS.md がコードブロック内にしか無い", m_agents_md_import_in_fence, "`@AGENTS.md` の取り込みがありません"),
    ("AGENTS.md に行頭 @", m_agents_md_at_import, "import を解釈しません"),
    ("CLAUDE.md + AGENTS.md の合計がハード上限超過", m_agents_md_too_long, "CLAUDE.md + AGENTS.md の合計"),
    ("AGENTS.md が指す project-config の節が無い", m_config_section_missing, "§13.7 の見出しが存在しません"),
    ("hook の if をツールイベント以外に書く", m_if_on_stop, "フックが一切走りません"),
    ("PermissionRequest に agent 型フック", m_agent_hook_on_permission_request, "agent 型フックは登録できません"),
    ("権限ルールの閉じ括弧の後にテキスト", m_rule_trailing_text, "閉じ括弧の後にテキスト"),
    ("Bash ルールでサブコマンドの前に *", m_rule_wildcard_before_sub, "サブコマンドの前の"),
    ("project settings の env に OTel 変数", m_otel_env_in_project, "project / local settings では読まれません"),
    ("予約名前空間の skill", m_reserved_skill_name, "予約された名前空間"),
    ("skill の name が 64 字超", m_skill_name_too_long, "文字を超える skill を読み込みません"),
    ("skill の name が Agent Skills 標準の形でない", m_skill_name_not_spec, "Agent Skills 標準の形ではありません"),
    ("skill に description が無く when_to_use だけ", m_skill_when_to_use_only, "`when_to_use` だけでは足りません"),
    ("omitClaudeMd の非 boolean 値", m_bad_omit_claude_md, "true / false のみ"),
    ("onFailure に不正な値", m_bad_on_failure, "continue / block のみ"),
    ("prompt 型フックに onFailure", m_on_failure_on_prompt_hook, "command / http 型のフックでしか効きません"),
    ("safety-check.sh に onFailure: block が無い", m_safety_check_fail_open, "`onFailure: block` がありません"),
    ("FileChanged の matcher が正規表現", m_filechanged_regex_matcher, "リテラルなファイル名"),
    ("scope-guard.sh に onFailure: block が無い", m_scope_guard_fail_open, "scope-guard.sh に `onFailure: block` がありません"),
    ("permissions に未知キー", m_unknown_permissions_key, "公式の permissions キーではありません"),
    ("user / managed 専用キーを project settings に書く", m_user_only_key_in_project, "`permissions.denyInsteadOfPrompting` は ~/.claude/settings.json"),
    ("managed 専用キーを local settings に書く", m_managed_only_key_in_project, "managed settings でしか効きません"),
    ("削除済みの settings キー", m_removed_setting, "v2.1.323 で削除"),
    ("削除済みの taskOutputMaxChars", m_removed_setting_task_output, "v2.1.277 で TaskOutput"),
    ("効果の無い keybindingFlavor", m_noeffect_setting_keybinding, "v2.1.261 で deprecated"),
    ("Bash allow ルールの変数の値に *", m_bash_allow_var_wildcard, "変数の値に `*`"),
    ("指示ファイルに IMPORTANT", m_legacy_emphasis, "`IMPORTANT` は現行モデル"),
    ("agent に think harder", m_legacy_think, "推論量を上げません"),
    ("有効な MCP サーバーの npm パッケージが未固定", m_mcp_unpinned_active, "有効な MCP サーバーの npm パッケージ"),
    ("例示ブロックの npm パッケージが範囲指定", m_mcp_unpinned_example, "例示ブロックの npm パッケージ"),
    ("Codex: 存在しないフックイベント名", m_codex_bad_event, "は Codex のフックイベント名ではありません"),
    ("Codex: ブロック系フックに --fail-closed が無い", m_codex_no_fail_closed, "`--fail-closed` がありません"),
    ("Codex: ブロック系フックが未登録", m_codex_blocking_hook_unregistered, "PreToolUse に protect-files.sh が登録されていません"),
    ("Codex: フックがアダプタを通していない", m_codex_hook_bypasses_adapter, "アダプタ(lib/codex-adapter.sh)を通していません"),
    ("Codex: フックの参照先が存在しない", m_codex_hook_missing_script, "が参照する no-such-hook.sh が存在しません"),
    ("Codex: Claude Code 専用のフックキー", m_codex_claude_only_hook_key, "`onFailure` は Claude Code 専用のキー"),
    ("Codex: アダプタが無い", m_codex_adapter_missing, "Codex 用アダプタがありません"),
    ("Codex: approval_policy = never", m_codex_approval_never, "確認なしで実行します"),
    ("Codex: 権限プロファイルと sandbox_mode の併用", m_codex_sandbox_mode_with_profile, "両方あります"),
    ("Codex: ハーネスが書込可能", m_codex_harness_writable, "`.agents` が読取専用になっていません"),
    ("Codex: シークレットの読取禁止が Claude Code 側とずれる", m_codex_secret_readable, "`*.pem` が Codex の権限プロファイルで deny になっていません"),
    ("Codex: プロジェクト設定で無視されるキー", m_codex_ignored_key, "`model_provider` はプロジェクトの config.toml では無視されます"),
    ("Codex: ask に対応する prompt 規則が無い", m_codex_rule_missing_prompt, "Claude Code の ask `Bash(git push *)` に対応する prompt 規則がありません"),
    ("Claude Code の deny に対応する Codex 規則が無い", m_claude_deny_without_codex_rule, "Claude Code の deny `Bash(shutdown *)` に対応する forbidden 規則がありません"),
    ("Codex: エージェント定義を直接編集", m_codex_agent_edited, "原本(.claude/agents/)とずれています"),
    ("Codex: エージェント定義が欠けている", m_codex_agent_missing, "対応する Codex 用エージェントがありません"),
    ("skill が .claude/ と .agents/ で二重", m_skill_duplicated_in_claude, "二重になっています"),
    ("フックが .claude/ に残っている", m_hooks_left_in_claude, "1.0 の配置では `.agents/hooks` に置きます"),
    ("手動起動限定の skill に Codex 用の設定が無い", m_manual_skill_without_codex_policy, "agents/openai.yaml"),
]

# リポジトリ水準のチェック(--root では走らない)
REPO_CASES = [
    ("VERSION と CHANGELOG の最新リリース見出しが不一致", m_version_mismatch, "一致しません"),
    ("setup.sh が日英ミラーで不一致", m_setup_mirror_drift, "setup.sh が日英ミラーで一致しません"),
]


def main() -> int:
    print("負のテスト: 既知の不具合を注入して検出を確認")
    results = [case(n, m, e) for n, m, e in CASES] + [repo_case(n, m, e) for n, m, e in REPO_CASES]
    print()
    print(f"結果: {sum(results)}/{len(results)} 検出")
    if not all(results):
        print("バリデータが検出できない不具合があります。")
        return 1
    print("全ケース検出。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
