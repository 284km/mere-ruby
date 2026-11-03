#!/usr/bin/env python3
"""Exercise detached-process accounting and cleanup with small real fixtures."""
import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import ci
import process_family as pf


class FamilySelectionCheck(unittest.TestCase):
    def test_tracks_new_sessions_and_reparenting_but_rejects_reused_pids(self):
        process = SimpleNamespace(pid=100, poll=lambda: None)
        family = pf.ProcessFamily(process, "fixture")
        first = {
            100: pf.Process(100, 1, 100, 10, "S", "root", True),
            101: pf.Process(101, 100, 101, 20, "S", "child", False),
            900: pf.Process(900, 1, 900, 1000, "S", "other", False),
        }
        self.assertEqual(family.update(first), 30)
        process.poll = lambda: 0
        second = {
            100: pf.Process(100, 1, 100, 1000, "S", "reused", False),
            101: pf.Process(101, 1, 101, 20, "S", "child", False),
            102: pf.Process(102, 101, 102, 30, "S", "grandchild", False),
            900: first[900],
        }
        self.assertEqual(family.update(second), 50)
        self.assertEqual(set(family.members), {101, 102})

    def test_marker_finds_a_daemon_after_the_parent_has_already_exited(self):
        family = pf.ProcessFamily(SimpleNamespace(pid=100, poll=lambda: 0), "fixture")
        rows = {
            101: pf.Process(101, 1, 101, 25, "S", "daemon", True),
            900: pf.Process(900, 1, 900, 1000, "S", "other", False),
        }
        self.assertEqual(family.update(rows), 25)
        self.assertEqual(set(family.members), {101})

    def test_revalidates_birth_before_sending_a_signal(self):
        family = pf.ProcessFamily(SimpleNamespace(pid=100, poll=lambda: 0), "fixture")
        old = pf.Process(101, 1, 101, 25, "S", "old", False)
        reused = pf.Process(101, 1, 101, 25, "S", "new", False)
        with patch.object(pf, "snapshot", return_value={101: reused}), patch.object(pf.os, "kill") as kill:
            family.signal_members([old], signal.SIGKILL)
        kill.assert_not_called()


class RealFamilyCheck(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="mere-ruby-family-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.pidfile = self.root / "child.json"
        self.script = self.root / "spawn.py"
        self.script.write_text('''import json, os, subprocess, sys, time
mode, pidfile = sys.argv[1:3]
child_code = "import time; time.sleep(30)"
if mode == "double-fork":
    first = os.fork()
    if first:
        os.waitpid(first, 0)
        sys.exit(0)
    os.setsid()
    second = os.fork()
    if second:
        os._exit(0)
    with open(pidfile, "w") as f:
        json.dump({"pid": os.getpid()}, f)
    time.sleep(30)
else:
    kwargs = {"start_new_session": True} if mode != "pgroup" else {"preexec_fn": os.setpgrp}
    if mode == "empty-env":
        kwargs["env"] = {}
    child = subprocess.Popen([sys.executable, "-c", child_code], **kwargs)
    with open(pidfile, "w") as f:
        json.dump({"pid": child.pid}, f)
    time.sleep(30)
''')
        # If a regression leaves the fixture alive, reclaim only the PID that
        # this fixture wrote, never a process chosen by a command-name pattern.
        self.addCleanup(self.reclaim_fixture)

    def reclaim_fixture(self):
        if self.pidfile.exists():
            try:
                os.kill(json.loads(self.pidfile.read_text())["pid"], signal.SIGKILL)
            except ProcessLookupError:
                pass

    def assert_child_stopped(self):
        self.assertTrue(self.pidfile.exists(), "fixture did not reach the detached child")
        pid = json.loads(self.pidfile.read_text())["pid"]
        deadline = time.monotonic() + 3
        while True:
            record = pf.snapshot().get(pid)
            if record is None or not record.alive:
                return
            if time.monotonic() > deadline:
                self.fail("detached child survived cleanup")
            time.sleep(0.02)

    def run_mode(self, mode, seconds=0.8):
        return ci.supervise([sys.executable, str(self.script), mode, str(self.pidfile), "multiline\nargument"],
                            {"PATH": os.defpath, "HOME": str(self.root)}, self.root / "driver.log",
                            rss_kb=1048576, seconds=seconds)

    def test_wall_limit_cleans_up_a_child_in_a_new_session(self):
        result = self.run_mode("session")
        self.assertEqual(result["limit"], "WALL_LIMIT")
        self.assert_child_stopped()

    def test_wall_limit_cleans_up_a_child_in_a_new_process_group(self):
        result = self.run_mode("pgroup")
        self.assertEqual(result["limit"], "WALL_LIMIT")
        self.assert_child_stopped()

    def test_pid_ancestry_cleans_up_a_child_that_execs_with_an_empty_environment(self):
        result = self.run_mode("empty-env")
        self.assertEqual(result["limit"], "WALL_LIMIT")
        self.assert_child_stopped()

    def test_normal_parent_exit_cleans_up_a_fast_double_fork(self):
        result = self.run_mode("double-fork")
        self.assertEqual(result["exit"], 0)
        self.assert_child_stopped()

    def test_escaped_descendant_participates_in_rss_limit_and_unrelated_process_is_untouched(self):
        other = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"], start_new_session=True)
        self.addCleanup(lambda: (other.kill(), other.wait()) if other.poll() is None else None)
        original = pf.ProcessFamily.sample

        def sample(family):
            original(family)
            if self.pidfile.exists():
                child = json.loads(self.pidfile.read_text())["pid"]
                if child in family.members:
                    # Exercise the real discovery/cleanup without allocating
                    # a large buffer just to force the memory limit.
                    return 1048577
            return 0

        with patch.object(pf.ProcessFamily, "sample", sample):
            result = self.run_mode("session", seconds=5)
        self.assertEqual(result["limit"], "MEMORY_LIMIT")
        self.assert_child_stopped()
        self.assertIsNone(other.poll(), "unrelated process was killed")


if __name__ == "__main__":
    unittest.main()
