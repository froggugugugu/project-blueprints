#!/usr/bin/env python3
"""limit_resume.py — 使用上限で止まったら解除時刻まで待ち、キューの続きを無人で回すランナー。

Claude Code(`claude -p`)または Codex(`codex exec`)にキューのタスクを 1 件ずつ渡す。
使用上限(5 時間・週次)に当たったら、メッセージから解除時刻を読み取り、その時刻まで眠ってから再開する。
読み取れないときは指数バックオフで待つ。状態はファイルに残すので、止めても同じコマンドで続きから再開できる。

使い方:
  python3 .agents/skills/limit-resume/scripts/limit_resume.py --queue output/tasks/limit-resume-queue.md
  python3 .agents/skills/limit-resume/scripts/limit_resume.py --queue <file> --dry-run
  python3 .agents/skills/limit-resume/scripts/limit_resume.py --queue <file> --status
  touch testreport/limit-resume/STOP     # 実行中のランナーを、待機中または次のタスクの前で止める

標準ライブラリだけで動く(Python 3.9 以上。zoneinfo を使う)。日英ミラーで同一のファイル。
テスト用に、エージェントの実行ファイルは環境変数 LIMIT_RESUME_CLAUDE_BIN / LIMIT_RESUME_CODEX_BIN で差し替えられる。
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shlex
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover - Python 3.8
    ZoneInfo = None  # type: ignore[assignment]

JA = os.environ.get("LANG", "").lower().startswith("ja") or os.environ.get("LIMIT_RESUME_LANG", "") == "ja"


def t(ja: str, en: str) -> str:
    return ja if JA else en


# 無人実行であることを各タスクの先頭で伝える。質問で止まると、待機と再開の仕組みが意味を失うため
UNATTENDED_HEADER = (
    "これは無人実行のタスクです。ユーザーに質問せず、判断が必要なら理由を書いて中断してください。"
    "push・merge・削除など不可逆な操作はタスクに明記されていない限り行わないでください。"
    "最後に、実行した検証コマンドとその結果を書いてください。\n\n"
)
CONTINUE_PROMPT = "使用上限で中断した作業の続きを進めてください。完了済みの手順はやり直さないでください。"

# 使用上限を示す文言(Claude Code / Codex)。上限ではない一時エラー(overloaded)は短い待機で再試行する
LIMIT_RE = re.compile(
    r"usage limit|limit reached|hit your (?:usage )?limit|session limit|weekly limit|5-hour limit"
    r"|rate[ _]limit|quota exceeded|too many requests|\b429\b",
    re.I,
)
TRANSIENT_RE = re.compile(r"overloaded|\b529\b|\b503\b|connection (?:reset|refused)|timed? ?out", re.I)

MONTHS = {m: i for i, m in enumerate(
    ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"], start=1)}
WEEKDAYS = {d: i for i, d in enumerate(["mon", "tue", "wed", "thu", "fri", "sat", "sun"])}


# ── 解除時刻の読み取り ─────────────────────────────────────────

def _tz(name: str | None, default: dt.tzinfo) -> dt.tzinfo:
    if name and ZoneInfo is not None:
        try:
            return ZoneInfo(name.strip())
        except Exception:  # noqa: BLE001 - 不明なタイムゾーン名はローカル時刻として扱う
            return default
    return default


def _hour(h: int, ampm: str | None) -> int:
    if ampm:
        ampm = ampm.lower()
        if ampm == "pm" and h != 12:
            return h + 12
        if ampm == "am" and h == 12:
            return 0
    return h


def parse_reset_time(text: str, now: dt.datetime) -> dt.datetime | None:
    """上限メッセージから解除時刻(aware datetime)を読み取る。読めなければ None。

    now は aware datetime(既定のタイムゾーンとして使う)。
    対応する形:
      - `usage limit reached|1748995200`(エポック秒)
      - `resets 3pm` / `resets 3:30pm (Asia/Tokyo)` / `resets Mon 10am` / `resets Nov 28, 10am`
      - `try again in 2 hours 13 minutes` / `try again at 3:15 PM`
    """
    m = re.search(r"limit reached\|(\d{10})\b", text, re.I)
    if m:
        return dt.datetime.fromtimestamp(int(m.group(1)), tz=now.tzinfo)

    m = re.search(r"(?:try again|retry|resets?) in\s+((?:\d+\s*(?:days?|d|hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)\b[\s,and]*)+)", text, re.I)
    if m:
        total = 0
        for num, unit in re.findall(r"(\d+)\s*([a-z]+)", m.group(1), re.I):
            u = unit.lower()
            mult = 86400 if u.startswith("d") else 3600 if u.startswith("h") else 60 if u.startswith("m") else 1
            total += int(num) * mult
        if total > 0:
            return now + dt.timedelta(seconds=total)

    m = re.search(
        r"(?:resets?|reset at|try again at|available again at)\s+(?:on\s+)?"
        r"(?:(?P<wd>mon|tue|wed|thu|fri|sat|sun)[a-z]*\.?,?\s+)?"
        r"(?:(?P<mon>jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(?P<day>\d{1,2}),?\s+(?:at\s+)?)?"
        r"(?P<h>\d{1,2})(?::(?P<min>\d{2}))?\s*(?P<ampm>am|pm)?"
        r"(?:\s*\((?P<tz>[A-Za-z_]+/[A-Za-z_/+-]+|UTC)\))?",
        text, re.I,
    )
    if not m:
        return None
    if not m.group("ampm") and not m.group("min") and not m.group("mon") and not m.group("wd"):
        return None  # 「resets 5」のような数字だけは時刻と断定しない
    tz = _tz(m.group("tz"), now.tzinfo or dt.timezone.utc)
    local_now = now.astimezone(tz)
    hour = _hour(int(m.group("h")), m.group("ampm"))
    minute = int(m.group("min") or 0)
    if hour > 23 or minute > 59:
        return None

    if m.group("mon"):
        month, day = MONTHS[m.group("mon").lower()[:3]], int(m.group("day"))
        try:
            cand = local_now.replace(month=month, day=day, hour=hour, minute=minute, second=0, microsecond=0)
        except ValueError:
            return None
        if cand <= local_now - dt.timedelta(minutes=1):
            cand = cand.replace(year=cand.year + 1)
        return cand

    cand = local_now.replace(hour=hour, minute=minute, second=0, microsecond=0)
    if m.group("wd"):
        ahead = (WEEKDAYS[m.group("wd").lower()[:3]] - local_now.weekday()) % 7
        cand += dt.timedelta(days=ahead)
        if cand <= local_now:
            cand += dt.timedelta(days=7)
        return cand
    if cand <= local_now:
        cand += dt.timedelta(days=1)
    return cand


def classify(exit_code: int, text: str, is_error: bool | None) -> str:
    """実行結果を ok / limit / transient / error に分ける。"""
    if exit_code == 0 and not is_error:
        return "ok"
    if LIMIT_RE.search(text):
        return "limit"
    if TRANSIENT_RE.search(text):
        return "transient"
    return "error"


# ── キューと状態 ──────────────────────────────────────────────

@dataclass
class Task:
    id: str
    prompt: str


def parse_queue(text: str) -> list[Task]:
    """`## <id>` 見出しごとに 1 タスク。見出しの下の本文がプロンプト。HTML コメントは除く。"""
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    tasks: list[Task] = []
    cur_id: str | None = None
    buf: list[str] = []
    seen: set[str] = set()

    def flush() -> None:
        if cur_id is None:
            return
        body = "\n".join(buf).strip()
        if body:
            if cur_id in seen:
                raise ValueError(t(f"タスク id が重複しています: {cur_id}", f"duplicate task id: {cur_id}"))
            seen.add(cur_id)
            tasks.append(Task(cur_id, body))

    for line in text.splitlines():
        m = re.match(r"^##\s+(\S.*?)\s*$", line)
        if m:
            flush()
            cur_id, buf = m.group(1), []
        elif cur_id is not None:
            buf.append(line)
    flush()
    return tasks


@dataclass
class State:
    path: Path
    tasks: dict = field(default_factory=dict)

    @classmethod
    def load(cls, path: Path) -> "State":
        if path.exists():
            data = json.loads(path.read_text(encoding="utf-8"))
            return cls(path, data.get("tasks", {}))
        return cls(path)

    def get(self, tid: str) -> dict:
        return self.tasks.setdefault(tid, {"status": "pending", "attempts": 0, "session_id": None})

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps({"tasks": self.tasks}, ensure_ascii=False, indent=2), encoding="utf-8")
        tmp.replace(self.path)


# ── ランナー ─────────────────────────────────────────────────

class StopRequested(Exception):
    pass


class Runner:
    def __init__(self, args: argparse.Namespace, sleep=time.sleep, clock=None) -> None:
        self.a = args
        self.sleep = sleep
        self.clock = clock or (lambda: dt.datetime.now().astimezone())
        self.dir = Path(args.state_dir)
        self.state = State.load(self.dir / "state.json")
        self.log_path = self.dir / "runs.jsonl"
        self.stop_file = self.dir / "STOP"

    # 記録と通知
    def log(self, event: str, **kw) -> None:
        self.dir.mkdir(parents=True, exist_ok=True)
        rec = {"ts": self.clock().isoformat(timespec="seconds"), "event": event, **kw}
        with self.log_path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")

    def say(self, msg: str, notify: bool = False) -> None:
        print(f"[limit-resume {self.clock().strftime('%m-%d %H:%M')}] {msg}", flush=True)
        if notify and self.a.notify_cmd:
            try:
                subprocess.run(shlex.split(self.a.notify_cmd) + [msg], timeout=30, check=False)
            except Exception as e:  # noqa: BLE001 - 通知の失敗で本体を止めない
                print(t(f"通知に失敗: {e}", f"notify failed: {e}"), file=sys.stderr)

    def check_stop(self) -> None:
        if self.stop_file.exists():
            raise StopRequested()

    # 待機
    def wait_until(self, target: dt.datetime, reason: str) -> None:
        now = self.clock()
        secs = max(0.0, (target - now).total_seconds())
        if secs > self.a.max_wait_hours * 3600:
            raise SystemExit(t(
                f"解除まで {secs / 3600:.1f} 時間あり、--max-wait-hours({self.a.max_wait_hours})を超えるので終了します。同じコマンドで後から再開できます",
                f"reset is {secs / 3600:.1f}h away, beyond --max-wait-hours ({self.a.max_wait_hours}); exiting. Re-run the same command later to resume",
            ))
        self.log("wait", reason=reason, until=target.isoformat(timespec="seconds"), seconds=int(secs))
        self.say(t(f"{reason}: {target.strftime('%m-%d %H:%M')} まで待機します", f"{reason}: waiting until {target.strftime('%m-%d %H:%M')}"), notify=True)
        end = time.monotonic() + secs
        while True:
            self.check_stop()
            left = end - time.monotonic()
            if left <= 0:
                break
            self.sleep(min(60.0, left))
        self.log("resume", reason=reason)

    # 1 回の実行
    def command(self, task: Task, st: dict) -> list[str]:
        if self.a.agent == "claude":
            exe = os.environ.get("LIMIT_RESUME_CLAUDE_BIN", "claude")
            cmd = [exe, "-p", "--output-format", "json", "--permission-mode", self.a.permission_mode]
            if self.a.max_turns:
                cmd += ["--max-turns", str(self.a.max_turns)]
            if self.a.model:
                cmd += ["--model", self.a.model]
            if st.get("session_id"):
                return cmd + ["--resume", st["session_id"], CONTINUE_PROMPT]
            return cmd + [UNATTENDED_HEADER + task.prompt]
        exe = os.environ.get("LIMIT_RESUME_CODEX_BIN", "codex")
        cmd = [exe, "exec"]
        if self.a.model:
            cmd += ["--model", self.a.model]
        # Codex は中断したセッションの再開を使わず、最初からやり直す(タスクを冪等に書く前提)
        return cmd + [UNATTENDED_HEADER + task.prompt]

    def run_once(self, task: Task, st: dict) -> tuple[str, str]:
        cmd = self.command(task, st)
        started = time.monotonic()
        try:
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=self.a.task_timeout_min * 60)
            out, code = (p.stdout or "") + "\n" + (p.stderr or ""), p.returncode
        except subprocess.TimeoutExpired as e:
            out = (e.stdout or "") if isinstance(e.stdout, str) else ""
            return "error", out + "\n" + t("タスクがタイムアウトしました", "task timed out")
        except FileNotFoundError:
            raise SystemExit(t(f"{cmd[0]} が見つかりません", f"{cmd[0]} not found"))

        is_error, cost, session = None, None, None
        if self.a.agent == "claude":
            try:
                data = json.loads(p.stdout)
                is_error = bool(data.get("is_error")) or data.get("subtype", "success") != "success"
                cost = data.get("total_cost_usd")
                session = data.get("session_id")
                out = str(data.get("result", "")) + "\n" + (p.stderr or "")
            except (json.JSONDecodeError, AttributeError, TypeError):
                pass
        if session:
            st["session_id"] = session
        kind = classify(code, out, is_error)
        self.log("run", task=task.id, outcome=kind, exit_code=code, seconds=int(time.monotonic() - started),
                 cost_usd_api_equivalent=cost, tail=out.strip()[-300:])
        return kind, out

    # 全体
    def run(self, tasks: list[Task]) -> int:
        backoff = self.a.backoff_min * 60
        try:
            for task in tasks:
                st = self.state.get(task.id)
                if st["status"] == "done":
                    continue
                if st["status"] == "failed" and not self.a.retry_failed:
                    continue
                if st["status"] == "failed":
                    st.update(status="pending", attempts=0)
                while True:
                    self.check_stop()
                    self.say(t(f"開始: {task.id}", f"start: {task.id}"))
                    kind, out = self.run_once(task, st)
                    if kind == "ok":
                        st.update(status="done", session_id=None)
                        self.state.save()
                        backoff = self.a.backoff_min * 60
                        self.say(t(f"完了: {task.id}", f"done: {task.id}"), notify=True)
                        break
                    if kind == "limit":
                        self.state.save()
                        reset = parse_reset_time(out, self.clock())
                        if reset is None:
                            target = self.clock() + dt.timedelta(seconds=backoff)
                            backoff = min(backoff * 2, self.a.backoff_max_min * 60)
                            self.wait_until(target, t("使用上限(解除時刻不明)", "usage limit (reset time unknown)"))
                        else:
                            self.wait_until(reset + dt.timedelta(seconds=self.a.margin_sec), t("使用上限", "usage limit"))
                        continue  # 上限による中断は試行回数に数えない
                    st["attempts"] += 1
                    if kind == "transient" and st["attempts"] < self.a.max_attempts:
                        self.state.save()
                        self.wait_until(self.clock() + dt.timedelta(minutes=5), t("一時エラー", "transient error"))
                        continue
                    if st["attempts"] < self.a.max_attempts:
                        st["session_id"] = None  # 失敗したセッションは引き継がず最初からやり直す
                        self.state.save()
                        continue
                    st["status"] = "failed"
                    self.state.save()
                    self.say(t(f"失敗: {task.id}(試行 {st['attempts']} 回)", f"failed: {task.id} ({st['attempts']} attempts)"), notify=True)
                    if self.a.stop_on_failure:
                        return 1
                    break
        except StopRequested:
            self.state.save()
            self.log("stopped")
            self.say(t(f"STOP ファイルを検知して停止しました({self.stop_file} を消してから再実行で再開)",
                       f"stopped by STOP file (delete {self.stop_file} and re-run to resume)"), notify=True)
            return 3
        self.say(t("キューを最後まで処理しました", "queue finished"), notify=True)
        return 0 if not any(self.state.get(x.id)["status"] == "failed" for x in tasks) else 1


# ── 事前チェックと CLI ────────────────────────────────────────

def preflight(a: argparse.Namespace) -> list[str]:
    """続行できない問題を返す(空なら可)。"""
    problems: list[str] = []
    if a.agent == "claude":
        if a.permission_mode == "bypassPermissions":
            problems.append(t("bypassPermissions は使えません(無人実行で全確認を外すと、ガードレールが deny と hooks だけになります)",
                              "bypassPermissions is refused (unattended runs keep the permission layer)"))
        if os.environ.get("ANTHROPIC_API_KEY") and not a.allow_api_key:
            problems.append(t("ANTHROPIC_API_KEY が設定されています。サブスクではなく API の従量課金になり、上限を待つ意味がありません。"
                              "外すか、従量課金で回すと決めたなら --allow-api-key を付けてください",
                              "ANTHROPIC_API_KEY is set: runs bill the API instead of the subscription, so waiting for limits is pointless. "
                              "Unset it, or pass --allow-api-key if you mean to pay per use"))
    return problems


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(description=t("使用上限の解除を待ってキューを無人で回す", "Run a task queue unattended, waiting out usage limits"))
    ap.add_argument("--queue", required=True, help=t("タスクキュー(`## <id>` 見出しごとに 1 タスク)", "task queue (one task per `## <id>` heading)"))
    ap.add_argument("--agent", choices=["claude", "codex"], default="claude")
    ap.add_argument("--state-dir", default="testreport/limit-resume")
    ap.add_argument("--permission-mode", default="dontAsk", choices=["dontAsk", "acceptEdits", "default", "plan", "auto", "bypassPermissions"],
                    help=t("Claude Code の権限モード(既定 dontAsk: allow にない操作は拒否)", "Claude Code permission mode (default dontAsk)"))
    ap.add_argument("--model")
    ap.add_argument("--max-turns", type=int)
    ap.add_argument("--margin-sec", type=int, default=120, help=t("解除時刻に足す余裕(秒)", "seconds added after the reset time"))
    ap.add_argument("--max-wait-hours", type=float, default=170, help=t("これより長い待機は行わず終了する", "exit instead of waiting longer than this"))
    ap.add_argument("--backoff-min", type=float, default=15, help=t("解除時刻が読めないときの初回待機(分)", "first wait when the reset time is unknown (minutes)"))
    ap.add_argument("--backoff-max-min", type=float, default=120)
    ap.add_argument("--max-attempts", type=int, default=2, help=t("上限以外の失敗で再試行する回数の上限", "attempts per task for non-limit failures"))
    ap.add_argument("--task-timeout-min", type=float, default=120)
    ap.add_argument("--notify-cmd", help=t("通知コマンド。最後の引数にメッセージを渡す", "notification command; the message is passed as the last argument"))
    ap.add_argument("--stop-on-failure", action="store_true")
    ap.add_argument("--retry-failed", action="store_true", help=t("failed のタスクも再実行する", "re-run tasks marked failed"))
    ap.add_argument("--allow-api-key", action="store_true")
    ap.add_argument("--dry-run", action="store_true", help=t("実行せず、処理対象と組み立てるコマンドを表示する", "show what would run"))
    ap.add_argument("--status", action="store_true", help=t("状態の集計を表示して終了する", "print a status summary and exit"))
    return ap


def main(argv: list[str] | None = None) -> int:
    a = build_parser().parse_args(argv)
    qpath = Path(a.queue)
    if not qpath.is_file():
        print(t(f"キューが見つかりません: {qpath}", f"queue not found: {qpath}"), file=sys.stderr)
        return 2
    try:
        tasks = parse_queue(qpath.read_text(encoding="utf-8"))
    except ValueError as e:
        print(e, file=sys.stderr)
        return 2
    if not tasks:
        print(t("キューにタスクがありません(`## <id>` 見出しの下に本文を書く)", "no tasks in the queue"), file=sys.stderr)
        return 2

    runner = Runner(a)
    if a.status or a.dry_run:
        counts: dict[str, int] = {}
        for task in tasks:
            st = runner.state.get(task.id)
            counts[st["status"]] = counts.get(st["status"], 0) + 1
            line = f"  {st['status']:<8} {task.id}"
            if a.dry_run and st["status"] != "done":
                line += "  $ " + " ".join(shlex.quote(c) for c in runner.command(task, st))[:160]
            print(line)
        print(" / ".join(f"{k} {v}" for k, v in sorted(counts.items())))
        if a.dry_run:
            for p in preflight(a):
                print("NG: " + p)
        return 0

    problems = preflight(a)
    if problems:
        for p in problems:
            print("ERROR: " + p, file=sys.stderr)
        return 2
    if runner.stop_file.exists():
        print(t(f"{runner.stop_file} があります。消してから実行してください", f"{runner.stop_file} exists; delete it first"), file=sys.stderr)
        return 2
    runner.log("start", queue=str(qpath), agent=a.agent, tasks=len(tasks))
    return runner.run(tasks)


if __name__ == "__main__":
    sys.exit(main())
