#!/usr/bin/env python3
"""Run the skills' `evals/evals.json` headlessly and grade them (with / without the skill).

The LLM-driven counterpart of `validate_harness.py`: the validator proves the harness is
*well-formed*, this proves it *changes behaviour*. Every case is executed twice in a
throwaway workspace built by `setup.sh` — once with the skill installed, once with the
skill directory removed — and an independent grader (a separate `claude -p` call with no
tools, in an empty directory) judges each assertion. Pass rates, skill-trigger rates,
cost and duration are written as JSON plus a Markdown summary.

    python3 scripts/run_skill_evals.py --skill prd --skill plan
    python3 scripts/run_skill_evals.py --all --parallel 3 --out evals/results/2026-11-01
    python3 scripts/run_skill_evals.py --skill prd --baseline evals/baseline/latest.json

Requirements: the `claude` CLI (logged in, or ANTHROPIC_API_KEY), bash, git, jq.
Each run is capped by --max-turns and --max-budget-usd. Exit code 0 = finished
(1 = at least one skill regressed against --baseline, 2 = environment problem).
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ARMS = ("with", "without")
SKIP_DIRS = {".claude", ".git", "testreport", "node_modules", ".claude.bak"}
DEFAULT_ALLOWED_TOOLS = ",".join([
    "Read", "Edit", "Write", "MultiEdit", "NotebookEdit", "Glob", "Grep", "Skill", "Agent", "TodoWrite",
    "Bash(git *)", "Bash(ls *)", "Bash(cat *)", "Bash(head *)", "Bash(tail *)", "Bash(wc *)",
    "Bash(find *)", "Bash(grep *)", "Bash(rg *)", "Bash(mkdir *)", "Bash(touch *)", "Bash(cp *)",
    "Bash(mv *)", "Bash(diff *)", "Bash(echo *)", "Bash(printf *)", "Bash(pwd)", "Bash(date *)",
    "Bash(tree *)", "Bash(npm *)", "Bash(npx *)", "Bash(node *)", "Bash(python3 *)", "Bash(bash *)",
    "Bash(sh *)", "Bash(sed *)", "Bash(awk *)", "Bash(sort *)", "Bash(uniq *)", "Bash(jq *)",
    "Bash(test *)", "Bash(true)",
])
ARTIFACT_FILE_CAP = 6_000      # chars per file handed to the grader
ARTIFACT_TOTAL_CAP = 60_000    # chars in total

GRADE_SCHEMA = {
    "type": "object",
    "required": ["results"],
    "properties": {
        "results": {
            "type": "array",
            "items": {
                "type": "object",
                "required": ["assertion", "pass", "evidence"],
                "properties": {
                    "assertion": {"type": "string"},
                    "pass": {"type": "boolean"},
                    "evidence": {"type": "string"},
                },
            },
        }
    },
}

GRADER_PROMPT = """You are grading one run of a Claude Code skill evaluation.
Judge each assertion ONLY from the evidence below (the agent's final message, the list of
files it created or modified, and their contents). If the evidence does not clearly show
the assertion is satisfied, mark it FAIL. Do not give credit for intentions or promises.
Quote the evidence (file path, line or sentence) for every verdict.

Return JSON: {{"results": [{{"assertion": "<verbatim>", "pass": true|false, "evidence": "<short quote>"}}]}}
Keep the assertions in the given order and verbatim.

## Task given to the agent
{prompt}

## Expected output (author's description)
{expected}

## Assertions
{assertions}

## Agent's final message
{final}

## Files created or modified by the agent (relative to the project root)
{files}

## File contents (truncated)
{contents}
"""


def log(msg: str) -> None:
    print(f"[{dt.datetime.now().strftime('%H:%M:%S')}] {msg}", flush=True)


def sh(cmd: list[str], cwd: Path | None = None, env: dict | None = None,
       timeout: int | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True, timeout=timeout)


def clean_env() -> dict:
    """Environment for nested `claude` calls: drop the markers of the outer session."""
    env = dict(os.environ)
    for k in ("CLAUDECODE", "CLAUDE_CODE_ENTRYPOINT", "CLAUDE_PROJECT_DIR"):
        env.pop(k, None)
    return env


# ── workspace ──────────────────────────────────────────────────────────────────
def build_workspace(mirror: Path, fixtures: Path | None, skill: str, arm: str, ws: Path) -> None:
    if ws.exists():
        shutil.rmtree(ws)
    ws.mkdir(parents=True)
    res = sh(["bash", str(mirror / "setup.sh"), str(ws), "--profile", "full"])
    if res.returncode != 0:
        raise RuntimeError(f"setup.sh failed: {res.stderr[-400:]}")
    second_commit: Path | None = None
    if fixtures and fixtures.is_dir():
        common = fixtures / "common"
        if common.is_dir():
            copy_tree(common, ws)
        repl = fixtures / "common" / "project-config.replacements.json"
        if repl.exists():
            apply_replacements(ws / "project-config.md", json.loads(repl.read_text(encoding="utf-8")))
        per_skill = fixtures / skill
        if per_skill.is_dir():
            copy_tree(per_skill, ws, skip={"_second_commit"})
            if (per_skill / "_second_commit").is_dir():
                second_commit = per_skill / "_second_commit"
    if arm == "without":
        shutil.rmtree(ws / ".claude" / "skills" / skill, ignore_errors=True)
    git = {"GIT_AUTHOR_NAME": "eval", "GIT_AUTHOR_EMAIL": "eval@example.invalid",
           "GIT_COMMITTER_NAME": "eval", "GIT_COMMITTER_EMAIL": "eval@example.invalid"}
    env = {**os.environ, **git}
    sh(["git", "init", "-q", "-b", "main"], cwd=ws, env=env)
    sh(["git", "add", "-A"], cwd=ws, env=env)
    sh(["git", "commit", "-q", "-m", "chore: project scaffold (harness + fixtures)"], cwd=ws, env=env)
    if second_commit:
        copy_tree(second_commit, ws)
        sh(["git", "add", "-A"], cwd=ws, env=env)
        sh(["git", "commit", "-q", "-m", "feat: add login handler"], cwd=ws, env=env)


def copy_tree(src: Path, dst: Path, skip: set[str] | None = None) -> None:
    for p in src.rglob("*"):
        rel = p.relative_to(src)
        if skip and rel.parts and rel.parts[0] in skip:
            continue
        if p.name == "project-config.replacements.json":
            continue
        target = dst / rel
        if p.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, target)


def apply_replacements(path: Path, pairs: list[list[str]]) -> None:
    text = path.read_text(encoding="utf-8")
    for old, new in pairs:
        text = text.replace(old, new)
    path.write_text(text, encoding="utf-8")


def snapshot(ws: Path) -> dict[str, float]:
    out: dict[str, float] = {}
    for p in ws.rglob("*"):
        rel = p.relative_to(ws)
        if rel.parts and rel.parts[0] in SKIP_DIRS:
            continue
        if str(rel).startswith("output/reports/sessions/"):   # written by session-end.sh, not by the task
            continue
        if p.is_file():
            out[str(rel)] = p.stat().st_mtime
    return out


def changed_files(ws: Path, before: dict[str, float]) -> list[str]:
    after = snapshot(ws)
    return sorted(f for f, m in after.items() if f not in before or m > before[f] + 1e-6)


# ── running ────────────────────────────────────────────────────────────────────
def run_agent(ws: Path, prompt: str, args: argparse.Namespace, stream_path: Path) -> dict:
    cmd = [
        "claude", "-p", prompt,
        "--output-format", "stream-json", "--verbose",
        "--model", args.model,
        "--max-turns", str(args.max_turns),
        "--max-budget-usd", str(args.max_budget_usd),
        "--no-session-persistence",
        "--setting-sources", "project,local",
        # Same shape as .github/workflows/claude-skills-ci.yml.template: an explicit
        # allowlist under dontAsk. Everything else is auto-denied (and logged by the
        # workspace's own permission-denied-log.sh), and the workspace's deny rules
        # and PreToolUse hooks stay active.
        "--permission-mode", args.permission_mode,
        "--allowedTools", args.allowed_tools,
    ]
    if args.effort:
        cmd += ["--effort", args.effort]
    t0 = time.time()
    try:
        proc = subprocess.run(cmd, cwd=ws, env=clean_env(), capture_output=True, text=True,
                              timeout=args.timeout)
        raw = proc.stdout
        stderr = proc.stderr
    except subprocess.TimeoutExpired as e:
        raw = (e.stdout or b"").decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
        stderr = f"timeout after {args.timeout}s"
    stream_path.write_text(raw, encoding="utf-8")
    info = {"tool_uses": [], "skills_invoked": [], "final": "", "num_turns": 0,
            "cost_usd": 0.0, "duration_ms": int((time.time() - t0) * 1000),
            "is_error": False, "stderr": stderr[-800:], "stop_reason": ""}
    for line in raw.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        t = msg.get("type")
        if t == "assistant":
            for block in (msg.get("message") or {}).get("content", []) or []:
                if block.get("type") == "tool_use":
                    name = block.get("name", "")
                    info["tool_uses"].append(name)
                    if name == "Skill":
                        info["skills_invoked"].append(str((block.get("input") or {}).get("skill", "")))
        elif t == "result":
            info["final"] = msg.get("result") or ""
            info["num_turns"] = msg.get("num_turns", 0)
            info["cost_usd"] = msg.get("total_cost_usd", 0.0) or 0.0
            info["duration_ms"] = msg.get("duration_ms", info["duration_ms"])
            info["is_error"] = bool(msg.get("is_error"))
            info["stop_reason"] = msg.get("stop_reason") or msg.get("subtype") or ""
    return info


def read_artifacts(ws: Path, files: list[str]) -> str:
    chunks, total = [], 0
    for f in files:
        p = ws / f
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if len(text) > ARTIFACT_FILE_CAP:
            text = text[:ARTIFACT_FILE_CAP] + f"\n… (truncated, {len(text)} chars)"
        chunk = f"\n### {f}\n```\n{text}\n```\n"
        if total + len(chunk) > ARTIFACT_TOTAL_CAP:
            chunks.append(f"\n### {f}\n(omitted: total cap reached)\n")
            continue
        chunks.append(chunk)
        total += len(chunk)
    return "".join(chunks) or "(no files changed)"


def grade(case: dict, run: dict, ws: Path, files: list[str], args: argparse.Namespace,
          scratch: Path) -> dict:
    prompt = GRADER_PROMPT.format(
        prompt=case["prompt"],
        expected=case.get("expected_output", ""),
        assertions="\n".join(f"- {a}" for a in case["assertions"]),
        final=run["final"] or "(empty)",
        files="\n".join(f"- {f}" for f in files) or "(none)",
        contents=read_artifacts(ws, files),
    )
    cmd = ["claude", "-p", prompt, "--output-format", "json", "--model", args.grader_model,
           "--max-turns", "1", "--tools", "", "--no-session-persistence",
           "--setting-sources", "project", "--json-schema", json.dumps(GRADE_SCHEMA)]
    proc = subprocess.run(cmd, cwd=scratch, env=clean_env(), capture_output=True, text=True,
                          timeout=600)
    results: list[dict] = []
    try:
        data = json.loads(proc.stdout)
        structured = data.get("structured_output")
        if structured is None:
            m = re.search(r"\{.*\}", data.get("result", ""), re.S)
            structured = json.loads(m.group(0)) if m else {}
        results = structured.get("results", [])
    except (json.JSONDecodeError, AttributeError):
        pass
    verdicts = []
    for i, a in enumerate(case["assertions"]):
        r = results[i] if i < len(results) else {}
        verdicts.append({"assertion": a, "pass": bool(r.get("pass", False)),
                         "evidence": r.get("evidence", "(grader gave no verdict)")})
    return {"verdicts": verdicts, "passed": sum(v["pass"] for v in verdicts),
            "total": len(verdicts), "grader_raw": proc.stdout[-2000:] if not results else ""}


def run_case(job: dict, args: argparse.Namespace) -> dict:
    skill, case, arm = job["skill"], job["case"], job["arm"]
    out_dir = job["out"] / skill / f"case-{case['id']}" / arm
    out_dir.mkdir(parents=True, exist_ok=True)
    ws = job["workspaces"] / f"{skill}-c{case['id']}-{arm}"
    label = f"{skill} #{case['id']} [{arm}]"
    log(f"start  {label}")
    build_workspace(job["mirror"], job["fixtures"], skill, arm, ws)
    before = snapshot(ws)
    run = run_agent(ws, case["prompt"], args, out_dir / "stream.jsonl")
    files = changed_files(ws, before)
    try:
        with tempfile.TemporaryDirectory() as td:
            g = grade(case, run, ws, files, args, Path(td))
    except Exception as e:  # noqa: BLE001 — keep the run record even if grading breaks
        g = {"verdicts": [{"assertion": a, "pass": False, "evidence": f"grader failed: {e}"}
                          for a in case["assertions"]],
             "passed": 0, "total": len(case["assertions"]), "grader_raw": str(e)}
    record = {
        "skill": skill, "case_id": case["id"], "arm": arm, "prompt": case["prompt"],
        "model": args.model, "grader_model": args.grader_model,
        "skill_invoked": skill in run["skills_invoked"],
        "skills_invoked": run["skills_invoked"], "tool_use_count": len(run["tool_uses"]),
        "num_turns": run["num_turns"], "cost_usd": round(run["cost_usd"], 4),
        "duration_s": round(run["duration_ms"] / 1000, 1), "is_error": run["is_error"],
        "stop_reason": run["stop_reason"], "changed_files": files,
        "final_message": run["final"][-4000:], "grade": g,
    }
    (out_dir / "result.json").write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
    if not args.keep_workspaces:
        shutil.rmtree(ws, ignore_errors=True)
    log(f"done   {label}: {g['passed']}/{g['total']} assertions, "
        f"{record['num_turns']} turns, ${record['cost_usd']}, {record['duration_s']}s"
        + (" (skill invoked)" if record["skill_invoked"] else ""))
    return record


# ── reporting ──────────────────────────────────────────────────────────────────
def summarize(records: list[dict], meta: dict) -> dict:
    by_skill: dict[str, dict] = {}
    for r in records:
        s = by_skill.setdefault(r["skill"], {a: {"cases": 0, "passed": 0, "total": 0,
                                                  "cases_all_pass": 0, "skill_invoked": 0,
                                                  "cost_usd": 0.0, "duration_s": 0.0,
                                                  "errors": 0} for a in ARMS})
        a = s[r["arm"]]
        a["cases"] += 1
        a["passed"] += r["grade"]["passed"]
        a["total"] += r["grade"]["total"]
        a["cases_all_pass"] += int(r["grade"]["passed"] == r["grade"]["total"])
        a["skill_invoked"] += int(r["skill_invoked"])
        a["cost_usd"] += r["cost_usd"]
        a["duration_s"] += r["duration_s"]
        a["errors"] += int(r["is_error"])
    for s in by_skill.values():
        for a in s.values():
            a["pass_rate"] = round(100 * a["passed"] / a["total"], 1) if a["total"] else None
            a["cost_usd"] = round(a["cost_usd"], 2)
            a["duration_s"] = round(a["duration_s"], 0)
    tot = {a: {"passed": sum(s[a]["passed"] for s in by_skill.values()),
               "total": sum(s[a]["total"] for s in by_skill.values()),
               "cost_usd": round(sum(s[a]["cost_usd"] for s in by_skill.values()), 2)}
           for a in ARMS}
    for a in tot.values():
        a["pass_rate"] = round(100 * a["passed"] / a["total"], 1) if a["total"] else None
    return {**meta, "skills": by_skill, "totals": tot}


def write_markdown(summary: dict, records: list[dict], path: Path) -> None:
    L = [f"# Skill eval results — {summary['date']}", ""]
    L.append(f"- mirror: `{summary['mirror']}` / model: `{summary['model']}` / grader: `{summary['grader_model']}`"
             f" / Claude Code: `{summary['claude_version']}`")
    L.append(f"- max-turns {summary['max_turns']}, max-budget ${summary['max_budget_usd']} per run, "
             f"effort: {summary['effort'] or 'default'}")
    t = summary["totals"]
    L.append(f"- **with skill: {t['with']['passed']}/{t['with']['total']} assertions "
             f"({t['with']['pass_rate']}%)**, without skill: {t['without']['passed']}/{t['without']['total']} "
             f"({t['without']['pass_rate']}%), total cost ${round(t['with']['cost_usd'] + t['without']['cost_usd'], 2)}")
    L += ["", "| skill | cases | with: assertions | with: cases all-pass | skill invoked | without: assertions | Δ pts | cost (with / without) |",
          "| --- | --- | --- | --- | --- | --- | --- | --- |"]
    for name, s in sorted(summary["skills"].items()):
        w, wo = s["with"], s["without"]
        delta = (w["pass_rate"] or 0) - (wo["pass_rate"] or 0) if w["total"] and wo["total"] else None
        L.append(f"| `{name}` | {w['cases']} | {w['passed']}/{w['total']} ({w['pass_rate']}%) | "
                 f"{w['cases_all_pass']}/{w['cases']} | {w['skill_invoked']}/{w['cases']} | "
                 f"{wo['passed']}/{wo['total']} ({wo['pass_rate']}%) | "
                 f"{'+' if delta is not None and delta >= 0 else ''}{delta if delta is not None else '—'} | "
                 f"${w['cost_usd']} / ${wo['cost_usd']} |")
    L += ["", "## Per assertion", ""]
    for r in sorted(records, key=lambda x: (x["skill"], x["case_id"], x["arm"])):
        L.append(f"### `{r['skill']}` case {r['case_id']} — {r['arm']} skill "
                 f"({r['grade']['passed']}/{r['grade']['total']}, {r['num_turns']} turns, ${r['cost_usd']}, {r['duration_s']}s"
                 f"{', skill invoked' if r['skill_invoked'] else ''}{', ERROR' if r['is_error'] else ''})")
        L.append("")
        L.append(f"> {r['prompt']}")
        L.append("")
        for v in r["grade"]["verdicts"]:
            L.append(f"- {'✅' if v['pass'] else '❌'} {v['assertion']} — {v['evidence'][:200]}")
        L.append("")
    path.write_text("\n".join(L), encoding="utf-8")


def compare_baseline(summary: dict, baseline_path: Path, tolerance: float) -> list[str]:
    base = json.loads(baseline_path.read_text(encoding="utf-8"))
    regressions = []
    for name, s in summary["skills"].items():
        b = base.get("skills", {}).get(name)
        if not b or s["with"]["pass_rate"] is None or b["with"].get("pass_rate") is None:
            continue
        if s["with"]["pass_rate"] + tolerance < b["with"]["pass_rate"]:
            regressions.append(f"{name}: with-skill pass rate {s['with']['pass_rate']}% "
                               f"< baseline {b['with']['pass_rate']}% − {tolerance}")
    return regressions


# ── main ───────────────────────────────────────────────────────────────────────
def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--mirror", default="project-blueprint", help="project-blueprint | project-blueprint-en")
    ap.add_argument("--skill", action="append", default=[], help="skill name (repeatable)")
    ap.add_argument("--all", action="store_true", help="every skill that ships evals/evals.json")
    ap.add_argument("--cases", default="", help="comma-separated case ids (default: all)")
    ap.add_argument("--arms", default="with,without")
    ap.add_argument("--model", default="sonnet")
    ap.add_argument("--grader-model", default="sonnet")
    ap.add_argument("--effort", default="")
    ap.add_argument("--max-turns", type=int, default=40)
    ap.add_argument("--max-budget-usd", type=float, default=3.0)
    ap.add_argument("--timeout", type=int, default=1800, help="seconds per run")
    ap.add_argument("--permission-mode", default="dontAsk",
                    help="permission mode for the agent runs (dontAsk auto-denies anything outside --allowed-tools)")
    ap.add_argument("--allowed-tools", default=DEFAULT_ALLOWED_TOOLS,
                    help="comma-separated allowlist handed to `claude --allowedTools`")
    ap.add_argument("--parallel", type=int, default=2)
    ap.add_argument("--out", default="", help="results directory (default evals/results/<timestamp>)")
    ap.add_argument("--fixtures", default="", help="fixtures root (default evals/fixtures/<ja|en>)")
    ap.add_argument("--keep-workspaces", action="store_true")
    ap.add_argument("--baseline", default="", help="summary.json to compare the with-skill pass rate against")
    ap.add_argument("--tolerance", type=float, default=15.0, help="allowed drop in percentage points")
    args = ap.parse_args()

    mirror = (REPO / args.mirror).resolve()
    if not (mirror / "setup.sh").exists():
        print(f"mirror not found: {mirror}", file=sys.stderr)
        return 2
    if shutil.which("claude") is None:
        print("`claude` CLI not found", file=sys.stderr)
        return 2
    lang = "en" if args.mirror.endswith("-en") else "ja"
    fixtures = Path(args.fixtures).resolve() if args.fixtures else REPO / "evals" / "fixtures" / lang
    if not fixtures.is_dir():
        log(f"WARN no fixtures at {fixtures}; cases that need input files will see an empty project")
        fixtures = None

    skills_dir = mirror / ".claude" / "skills"
    names = args.skill or ([p.parent.parent.name for p in sorted(skills_dir.glob("*/evals/evals.json"))] if args.all else [])
    if not names:
        print("specify --skill <name> (repeatable) or --all", file=sys.stderr)
        return 2
    wanted = {int(x) for x in args.cases.split(",") if x.strip()} if args.cases else None
    arms = [a for a in args.arms.split(",") if a in ARMS]

    stamp = dt.datetime.now().strftime("%Y-%m-%d_%H%M%S")
    out = Path(args.out).resolve() if args.out else REPO / "evals" / "results" / stamp
    out.mkdir(parents=True, exist_ok=True)
    workspaces = Path(tempfile.mkdtemp(prefix="skill-evals-"))
    version = sh(["claude", "--version"]).stdout.strip()

    jobs = []
    for name in names:
        ev = skills_dir / name / "evals" / "evals.json"
        if not ev.exists():
            log(f"WARN {name}: no evals.json, skipped")
            continue
        for case in json.loads(ev.read_text(encoding="utf-8"))["evals"]:
            if wanted and case["id"] not in wanted:
                continue
            for arm in arms:
                jobs.append({"skill": name, "case": case, "arm": arm, "mirror": mirror,
                             "fixtures": fixtures, "out": out, "workspaces": workspaces})
    log(f"{len(jobs)} runs ({len(names)} skills × cases × {len(arms)} arms), parallel {args.parallel}, out {out}")

    records: list[dict] = []
    with cf.ThreadPoolExecutor(max_workers=args.parallel) as ex:
        futures = {ex.submit(run_case, j, args): j for j in jobs}
        for fut in cf.as_completed(futures):
            j = futures[fut]
            try:
                records.append(fut.result())
            except Exception as e:  # noqa: BLE001 — one failed run must not kill the batch
                log(f"ERROR {j['skill']} #{j['case']['id']} [{j['arm']}]: {e}")
                records.append({"skill": j["skill"], "case_id": j["case"]["id"], "arm": j["arm"],
                                "prompt": j["case"]["prompt"], "skill_invoked": False, "skills_invoked": [],
                                "tool_use_count": 0, "num_turns": 0, "cost_usd": 0.0, "duration_s": 0.0,
                                "is_error": True, "stop_reason": "exception", "changed_files": [],
                                "final_message": str(e), "grade": {"verdicts": [
                                    {"assertion": a, "pass": False, "evidence": "run failed"}
                                    for a in j["case"]["assertions"]],
                                    "passed": 0, "total": len(j["case"]["assertions"])}})

    meta = {"date": stamp[:10], "mirror": args.mirror, "model": args.model, "grader_model": args.grader_model,
            "effort": args.effort, "max_turns": args.max_turns, "max_budget_usd": args.max_budget_usd,
            "claude_version": version, "runs": len(records)}
    summary = summarize(records, meta)
    (out / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    (out / "records.json").write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
    write_markdown(summary, records, out / "SUMMARY.md")
    if not args.keep_workspaces:
        shutil.rmtree(workspaces, ignore_errors=True)
    t = summary["totals"]
    log(f"with skill {t['with']['passed']}/{t['with']['total']} ({t['with']['pass_rate']}%), "
        f"without {t['without']['passed']}/{t['without']['total']} ({t['without']['pass_rate']}%), "
        f"cost ${round(t['with']['cost_usd'] + t['without']['cost_usd'], 2)} → {out}")

    if args.baseline:
        regressions = compare_baseline(summary, Path(args.baseline), args.tolerance)
        for r in regressions:
            log(f"REGRESSION {r}")
        if regressions:
            return 1
        log("no regression against baseline")
    return 0


if __name__ == "__main__":
    sys.exit(main())
