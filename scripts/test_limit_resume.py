#!/usr/bin/env python3
"""limit_resume.py(`/limit-resume` skill のランナー)の機能テスト。

解除時刻の読み取り・キューの解釈・結果の分類を単体で確かめ、偽の `claude` を差し替えて
「上限 → 待機 → セッション再開 → 完了」「STOP ファイルで停止」「再実行で done を飛ばす」までを通しで確かめる。
実際の CLI もモデルも呼ばない。日英ミラーのランナーが同一ファイルであることも検査する。

使い方: python3 scripts/test_limit_resume.py   (validate-harness.sh --limit-resume からも呼ばれる)
"""

from __future__ import annotations

import datetime as dt
import importlib.util
import json
import os
import stat
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REL = ".agents/skills/limit-resume/scripts/limit_resume.py"
SCRIPT = REPO / "project-blueprint" / REL

# テンプレートの中に __pycache__ を作らない(日英ミラーの構成一致を崩すため)
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("limit_resume", SCRIPT)
lr = importlib.util.module_from_spec(spec)
sys.modules["limit_resume"] = lr
spec.loader.exec_module(lr)

TOKYO = dt.timezone(dt.timedelta(hours=9))
NOW = dt.datetime(2026, 11, 24, 22, 30, tzinfo=TOKYO)  # 火曜


class ParseResetTime(unittest.TestCase):
    def p(self, text: str) -> dt.datetime | None:
        return lr.parse_reset_time(text, NOW)

    def test_epoch(self) -> None:
        r = self.p("Claude AI usage limit reached|1764000000")
        self.assertEqual(int(r.timestamp()), 1764000000)

    def test_time_only_rolls_to_tomorrow(self) -> None:
        self.assertEqual(self.p("5-hour limit reached ∙ resets 3am"), NOW.replace(day=25, hour=3, minute=0))

    def test_time_today(self) -> None:
        self.assertEqual(self.p("You've hit your limit · resets 11:30pm"), NOW.replace(hour=23, minute=30))

    def test_explicit_timezone(self) -> None:
        r = self.p("Session limit reached ∙ resets 3pm (UTC)")
        self.assertEqual(r.astimezone(dt.timezone.utc).hour, 15)
        self.assertGreater(r, NOW)

    def test_weekday(self) -> None:
        r = self.p("Weekly limit reached ∙ resets Mon 10am")
        self.assertEqual((r.weekday(), r.hour), (0, 10))
        self.assertEqual(r.date(), dt.date(2026, 11, 30))

    def test_month_day(self) -> None:
        self.assertEqual(self.p("Weekly limit reached ∙ resets Nov 28, 10am"), NOW.replace(day=28, hour=10, minute=0))

    def test_month_day_past_goes_next_year(self) -> None:
        self.assertEqual(self.p("resets Jan 2, 9am").year, 2027)

    def test_relative(self) -> None:
        self.assertEqual(self.p("You've hit your usage limit. Try again in 2 hours 13 minutes."), NOW + dt.timedelta(hours=2, minutes=13))

    def test_try_again_at(self) -> None:
        self.assertEqual(self.p("usage limit. try again at 3:15 AM"), NOW.replace(day=25, hour=3, minute=15))

    def test_unknown(self) -> None:
        self.assertIsNone(self.p("usage limit reached"))
        self.assertIsNone(self.p("resets 5"))


class Classify(unittest.TestCase):
    def test_kinds(self) -> None:
        self.assertEqual(lr.classify(0, "all good", False), "ok")
        self.assertEqual(lr.classify(1, "5-hour limit reached ∙ resets 3am", True), "limit")
        self.assertEqual(lr.classify(1, "API Error: 529 overloaded", True), "transient")
        self.assertEqual(lr.classify(1, "TypeError in test", True), "error")
        self.assertEqual(lr.classify(0, "usage limit", True), "limit")


class Queue(unittest.TestCase):
    def test_parse(self) -> None:
        q = textwrap.dedent("""\
            # キュー
            <!-- 説明 -->
            ## t1
            一つ目

            ## t2
            二つ目
            ## empty
            """)
        tasks = lr.parse_queue(q)
        self.assertEqual([(x.id, x.prompt) for x in tasks], [("t1", "一つ目"), ("t2", "二つ目")])

    def test_duplicate(self) -> None:
        with self.assertRaises(ValueError):
            lr.parse_queue("## a\nx\n## a\ny\n")


FAKE_CLAUDE = """#!/usr/bin/env python3
import json, sys, pathlib
args = sys.argv[1:]
d = pathlib.Path(sys.argv[0]).parent
calls = d / "calls.jsonl"
with calls.open("a") as f:
    f.write(json.dumps(args) + "\\n")
n = sum(1 for _ in calls.open())
prompt = args[-1]
if "LIMIT_ONCE" in prompt and n == 1:
    print(json.dumps({"type": "result", "subtype": "success", "is_error": True, "session_id": "s-1",
                      "result": "5-hour limit reached \\u2219 resets 11:40pm (Asia/Tokyo)"}))
    sys.exit(1)
if "ALWAYS_FAIL" in prompt:
    print(json.dumps({"type": "result", "subtype": "success", "is_error": True, "session_id": "s-x", "result": "tests failed"}))
    sys.exit(1)
print(json.dumps({"type": "result", "subtype": "success", "is_error": False, "session_id": "s-2",
                  "result": "done", "total_cost_usd": 0.42}))
"""


class EndToEnd(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        fake = self.tmp / "claude"
        fake.write_text(FAKE_CLAUDE, encoding="utf-8")
        fake.chmod(fake.stat().st_mode | stat.S_IEXEC)
        os.environ["LIMIT_RESUME_CLAUDE_BIN"] = str(fake)
        os.environ.pop("ANTHROPIC_API_KEY", None)
        self.queue = self.tmp / "queue.md"
        self.state = self.tmp / "state"
        self.slept: list[float] = []
        self.clock_now = NOW

    def clock(self) -> dt.datetime:
        return self.clock_now

    def sleep(self, s: float) -> None:
        self.slept.append(s)
        self.clock_now += dt.timedelta(seconds=s)

    def runner(self, *extra: str) -> "lr.Runner":
        a = lr.build_parser().parse_args(["--queue", str(self.queue), "--state-dir", str(self.state), *extra])
        return lr.Runner(a, sleep=self.sleep, clock=self.clock)

    def calls(self) -> list[list[str]]:
        p = self.tmp / "calls.jsonl"
        return [json.loads(x) for x in p.read_text().splitlines()] if p.exists() else []

    def test_limit_then_resume_session(self) -> None:
        self.queue.write_text("## a\nLIMIT_ONCE をやる\n## b\n次の作業\n", encoding="utf-8")
        r = self.runner()
        # 実時間で眠らないよう、待機の長さを 0 に縮める(時刻の計算は wait ログで確かめる)
        orig = r.wait_until
        waits: list[dt.datetime] = []
        r.wait_until = lambda target, reason: (waits.append(target), orig(self.clock_now, reason))[1]
        self.assertEqual(r.run(lr.parse_queue(self.queue.read_text())), 0)
        self.assertEqual(waits[0], NOW.replace(hour=23, minute=42))  # 11:40pm + 既定の余裕 120 秒
        c = self.calls()
        self.assertEqual(len(c), 3)
        self.assertIn("--resume", c[1])
        self.assertIn("s-1", c[1])
        self.assertIn("--permission-mode", c[0])
        self.assertEqual(c[0][c[0].index("--permission-mode") + 1], "dontAsk")
        st = json.loads((self.state / "state.json").read_text())
        self.assertEqual({k: v["status"] for k, v in st["tasks"].items()}, {"a": "done", "b": "done"})
        log = [json.loads(x) for x in (self.state / "runs.jsonl").read_text().splitlines()]
        self.assertTrue(any(x["event"] == "wait" for x in log))
        self.assertTrue(any(x.get("cost_usd_api_equivalent") == 0.42 for x in log))

    def test_rerun_skips_done_and_failure_is_recorded(self) -> None:
        self.queue.write_text("## a\nふつう\n## bad\nALWAYS_FAIL\n", encoding="utf-8")
        self.assertEqual(self.runner().run(lr.parse_queue(self.queue.read_text())), 1)
        self.assertEqual(len(self.calls()), 3)  # a 1 回 + bad 2 回(--max-attempts 既定 2)
        self.assertEqual(self.runner().run(lr.parse_queue(self.queue.read_text())), 1)
        self.assertEqual(len(self.calls()), 3)  # done と failed は再実行しない

    def test_stop_file(self) -> None:
        self.queue.write_text("## a\nふつう\n", encoding="utf-8")
        self.state.mkdir()
        (self.state / "STOP").touch()
        self.assertEqual(self.runner().run(lr.parse_queue(self.queue.read_text())), 3)
        self.assertEqual(self.calls(), [])

    def test_max_wait_exceeded_exits(self) -> None:
        r = self.runner("--max-wait-hours", "1")
        with self.assertRaises(SystemExit):
            r.wait_until(NOW + dt.timedelta(hours=5), "x")

    def test_preflight(self) -> None:
        a = lr.build_parser().parse_args(["--queue", "q", "--permission-mode", "bypassPermissions"])
        self.assertTrue(lr.preflight(a))
        os.environ["ANTHROPIC_API_KEY"] = "dummy"
        try:
            a = lr.build_parser().parse_args(["--queue", "q"])
            self.assertTrue(lr.preflight(a))
            a = lr.build_parser().parse_args(["--queue", "q", "--allow-api-key"])
            self.assertFalse(lr.preflight(a))
        finally:
            os.environ.pop("ANTHROPIC_API_KEY", None)


class Mirror(unittest.TestCase):
    def test_identical(self) -> None:
        en = REPO / "project-blueprint-en" / REL
        self.assertEqual(SCRIPT.read_bytes(), en.read_bytes(), "日英ミラーの limit_resume.py は同一ファイルとして保守する")


if __name__ == "__main__":
    unittest.main(verbosity=1)
