"""Track a test worker across process-group changes and daemon reparenting."""
import os
import signal
import subprocess
import sys
import time
from dataclasses import dataclass

MARKER = "MERE_RUBY_TEST_FAMILY"


@dataclass(frozen=True)
class Process:
    pid: int
    ppid: int
    pgid: int
    rss: int
    state: str
    birth: str
    marked: bool

    @property
    def identity(self):
        return self.pid, self.birth

    @property
    def alive(self):
        return not self.state.startswith("Z")


def snapshot(marker=None):
    # macOS -E and Linux's BSD-style e show launch environments, even after
    # unsetenv in the process. This recovers fast double-forks that reparent
    # before the next PPID sample. Never retain/log command lines or env values.
    command = ["ps", "-ww", "-axo", "pid=,ppid=,pgid=,rss=,state=,lstart=,command="]
    if marker:
        command.insert(1, "-E" if sys.platform == "darwin" else "e")
    output = subprocess.check_output(command, text=True, encoding="utf-8", errors="replace", stderr=subprocess.PIPE,
                                     env={"PATH": os.defpath, "LC_ALL": "C"})
    records = {}
    needle = f" {MARKER}={marker} " if marker else None
    for line in output.splitlines():
        parts = line.split(None, 10)
        if len(parts) < 10:
            continue
        try:
            pid, ppid, pgid, rss = map(int, parts[:4])
        except ValueError:
            continue
        arguments = " " + (parts[10] if len(parts) > 10 else "") + " "
        records[pid] = Process(pid, ppid, pgid, rss, parts[4], " ".join(parts[5:10]),
                               bool(needle and needle in arguments))
    return records


class ProcessFamily:
    def __init__(self, process, marker):
        self.process = process
        self.marker = marker
        self.members = {}

    @staticmethod
    def preflight():
        # Fail before launching tests if process inspection is unavailable.
        if os.getpid() not in snapshot():
            raise RuntimeError("process inspection is unavailable")

    def update(self, records):
        owned = {pid: record for pid, record in records.items()
                 if record.marked or (pid in self.members and record.identity == self.members[pid].identity)}
        # An unreaped root PID cannot have been reused. After exit, only its
        # recorded birth identity or inherited marker may establish ownership.
        if self.process.poll() is None and self.process.pid in records:
            owned[self.process.pid] = records[self.process.pid]
        while True:
            groups = {record.pgid for record in owned.values() if record.alive}
            added = {pid: record for pid, record in records.items()
                     if pid not in owned and (record.ppid in owned or record.pgid in groups)}
            if not added:
                break
            owned.update(added)
        self.members = owned
        return sum(record.rss for record in owned.values() if record.alive)

    def sample(self):
        return self.update(snapshot(self.marker))

    def signal_members(self, members, sig):
        # Revalidate birth identities before signalling to avoid stale/reused PIDs.
        current = snapshot(self.marker)
        signalled = set()
        for record in members:
            found = current.get(record.pid)
            if found is None or found.identity != record.identity or not found.alive:
                continue
            try:
                os.kill(record.pid, sig)
                signalled.add(record.identity)
            except ProcessLookupError:
                pass
        return signalled

    def stop(self):
        # Freeze parents before the final traversal so they cannot fork again
        # while descendants are being killed. Rescan to catch a fork that raced
        # with the first stop. Session changes do not affect tracked identities.
        stopped = set()
        for _ in range(8):
            self.sample()
            pending = [record for record in self.members.values()
                       if record.alive and record.identity not in stopped]
            if not pending:
                break
            stopped.update(self.signal_members(pending, signal.SIGSTOP))
        else:
            raise RuntimeError("test process family did not stabilize for cleanup")
        self.sample()
        members = sorted(self.members.values(), key=lambda record: record.pid == self.process.pid)
        self.signal_members(members, signal.SIGKILL)
        self.process.wait(timeout=5)
        deadline = time.monotonic() + 3
        while True:
            self.sample()
            if not any(record.alive for record in self.members.values()):
                return
            if time.monotonic() > deadline:
                raise RuntimeError("test descendants survived cleanup")
            time.sleep(0.02)
