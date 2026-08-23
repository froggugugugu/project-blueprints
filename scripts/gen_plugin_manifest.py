#!/usr/bin/env python3
"""Generate the plugin manifests for both mirrors from the existing harness.

The blueprint's primary distribution stays `setup.sh` + clone. The plugin
manifests are additive: they let the same tree be installed with
`/plugin install`, without duplicating a single skill, agent, or hook script.

Everything is derived, so nothing can drift:
  .claude-plugin/plugin.json   points at .claude/skills, .claude/agents, ...
  .claude-plugin/hooks.json    is settings.json's hooks block with
                               $CLAUDE_PROJECT_DIR rewritten to ${CLAUDE_PLUGIN_ROOT}

scripts/validate_harness.py re-derives both and fails when the committed files
differ, so regenerating is the only supported way to change them.

    python3 scripts/gen_plugin_manifest.py          # write
    python3 scripts/gen_plugin_manifest.py --check  # verify only (used by the validator)
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

PROJECT_DIR_REF = '"$CLAUDE_PROJECT_DIR"/.claude/hooks/'
PLUGIN_ROOT_REF = '"${CLAUDE_PLUGIN_ROOT}"/.claude/hooks/'

MIRRORS = {
    "project-blueprint": {
        "name": "project-blueprint",
        "displayName": "Project Blueprint (日本語)",
        "description": (
            "Claude Code 協働開発のフルライフサイクル・ハーネス（日本語）。"
            "17 skills / 8 agents / 13 hooks / 5 品質ゲート / 多層防御。"
        ),
        "keywords": ["workflow", "spec-driven", "quality-gates", "japanese", "harness"],
    },
    "project-blueprint-en": {
        "name": "project-blueprint-en",
        "displayName": "Project Blueprint (English)",
        "description": (
            "Full-lifecycle harness for AI-collaborative development with Claude Code (English). "
            "17 skills / 8 agents / 13 hooks / 5 quality gates / defense in depth."
        ),
        "keywords": ["workflow", "spec-driven", "quality-gates", "english", "harness"],
    },
}

AUTHOR = {"name": "froggugugugu", "url": "https://github.com/froggugugugu"}
REPOSITORY = "https://github.com/froggugugugu/project-blueprints"
LICENSE = "MIT"


def read_version() -> str:
    """Take the version from the newest CHANGELOG heading, falling back to 0.0.0."""
    changelog = REPO / "CHANGELOG.md"
    if changelog.exists():
        import re

        m = re.search(r"^#+\s*\[?(\d+\.\d+\.\d+)\]?", changelog.read_text(encoding="utf-8"), re.M)
        if m:
            return m.group(1)
    return "0.0.0"


def build_hooks(mirror: Path) -> dict:
    """Rewrite settings.json's hooks block for plugin execution."""
    settings = json.loads((mirror / ".claude/settings.json").read_text(encoding="utf-8"))
    hooks = json.loads(json.dumps(settings["hooks"]))  # deep copy
    for groups in hooks.values():
        for group in groups:
            for hook in group.get("hooks", []):
                if "command" in hook:
                    hook["command"] = hook["command"].replace(PROJECT_DIR_REF, PLUGIN_ROOT_REF)
    return {"hooks": hooks}


def build_manifest(mirror: Path, meta: dict, version: str) -> dict:
    agents_dir = mirror / ".claude/agents"
    # `agents` replaces the default scan, so name the files explicitly.
    # A bare directory would also pull in README.md, which is documentation, not an agent.
    agent_files = sorted(
        f"./.claude/agents/{p.name}" for p in agents_dir.glob("*.md") if p.name != "README.md"
    )
    manifest = {
        "$schema": "https://json.schemastore.org/claude-code-plugin.json",
        "name": meta["name"],
        "displayName": meta["displayName"],
        "version": version,
        "description": meta["description"],
        "author": AUTHOR,
        "repository": REPOSITORY,
        "license": LICENSE,
        "keywords": meta["keywords"],
        "skills": "./.claude/skills/",
        "agents": agent_files,
        "outputStyles": "./.claude/output-styles/",
        "hooks": "./.claude-plugin/hooks.json",
    }
    return manifest


def build_marketplace(version: str) -> dict:
    return {
        "$schema": "https://json.schemastore.org/claude-code-marketplace.json",
        "name": "project-blueprints",
        "description": (
            "Claude Code AI 協働開発ブループリント。日本語版と英語版を同一構成でミラー提供する。"
        ),
        "version": version,
        "owner": AUTHOR,
        "plugins": [
            {
                "name": meta["name"],
                "source": f"./{mirror}",
                "displayName": meta["displayName"],
                "description": meta["description"],
                "version": version,
                "category": "workflow",
                "tags": meta["keywords"],
            }
            for mirror, meta in MIRRORS.items()
        ],
    }


def dump(path: Path, data: dict, check: bool, diffs: list[str]) -> None:
    text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    if check:
        current = path.read_text(encoding="utf-8") if path.exists() else ""
        if current != text:
            diffs.append(str(path.relative_to(REPO)))
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    print(f"  wrote {path.relative_to(REPO)}")


def main() -> int:
    ap = argparse.ArgumentParser(description="プラグインマニフェストの生成 / 検証")
    ap.add_argument("--check", action="store_true", help="書き込まず、生成物と一致するかだけ確認する")
    args = ap.parse_args()

    version = read_version()
    diffs: list[str] = []

    for mirror_name, meta in MIRRORS.items():
        mirror = REPO / mirror_name
        if not mirror.is_dir():
            continue
        dump(mirror / ".claude-plugin/plugin.json", build_manifest(mirror, meta, version), args.check, diffs)
        dump(mirror / ".claude-plugin/hooks.json", build_hooks(mirror), args.check, diffs)

    dump(REPO / ".claude-plugin/marketplace.json", build_marketplace(version), args.check, diffs)

    if args.check:
        if diffs:
            print("生成物と一致しないファイル:")
            for d in diffs:
                print(f"  {d}")
            print("`python3 scripts/gen_plugin_manifest.py` で再生成してください。")
            return 1
        print("プラグインマニフェストは生成物と一致しています。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
