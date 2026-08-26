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


# ── 注入する不具合(すべて実際にこのリポジトリで発生したもの) ──────────
def m_color(root: Path) -> None:
    p = root / ".claude/agents/explorer.md"
    p.write_text(p.read_text().replace("color: blue", "color: magenta"))


def m_write_rule(root: Path) -> None:
    p = root / ".claude/skills/prd/SKILL.md"
    p.write_text(p.read_text().replace("Edit(output/**)", "Write(output/**)"))


def m_bad_yaml(root: Path) -> None:
    p = root / ".claude/skills/adr/SKILL.md"
    t = re.sub(r"(?m)^description: >\n(  .*\n)+",
               "description: Records decisions. Triggers: adr, decision-log.\n",
               p.read_text(), count=1)
    p.write_text(t)


def m_missing_hook(root: Path) -> None:
    (root / ".claude/hooks/post-compact-restore.sh").unlink()


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
    p = root / ".claude/skills/refactoring/SKILL.md"
    p.write_text(p.read_text().replace("allowed-tools:", "context: main\nallowed-tools:", 1))


def m_fork_askuser(root: Path) -> None:
    p = root / ".claude/skills/brainstorm/SKILL.md"
    p.write_text(p.read_text().replace("argument-hint:", "context: fork\nargument-hint:", 1))


def m_local_deny(root: Path) -> None:
    p = root / ".claude/settings.local.json.template"
    cfg = json.loads(p.read_text())
    cfg["permissions"]["deny"] = []
    p.write_text(json.dumps(cfg, indent=2, ensure_ascii=False))


def m_nonexec_hook(root: Path) -> None:
    (root / ".claude/hooks/safety-check.sh").chmod(0o644)


def m_shell_syntax(root: Path) -> None:
    p = root / ".claude/hooks/console-warn.sh"
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
]


def main() -> int:
    print("負のテスト: 既知の不具合を注入して検出を確認")
    results = [case(n, m, e) for n, m, e in CASES]
    print()
    print(f"結果: {sum(results)}/{len(results)} 検出")
    if not all(results):
        print("バリデータが検出できない不具合があります。")
        return 1
    print("全ケース検出。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
