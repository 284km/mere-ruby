#!/usr/bin/env python3
"""A nonblocking character-device flush must deliver the entire buffer."""
import os
from pathlib import Path
import pty
import select
import subprocess
import tempfile
import time
import tty

ROOT = Path(__file__).resolve().parent.parent
MERE = str(Path(os.environ.get("MR_BIN", str(ROOT / "mere-ruby"))).resolve())
RUBY = os.environ.get("REF_RUBY", "ruby")
PAYLOAD = b"0123456789abcdef" * 12500


def check(binary, env):
    master, slave = pty.openpty()
    tty.setraw(slave)
    path = os.ttyname(slave)
    source = """require 'io/nonblock'
STDOUT.sync = true
f = File.open(ARGV.fetch(0), 'w')
f.nonblock = true
puts 'ready'
f.write('0123456789abcdef' * 12500)
f.flush
f.close
puts 'done'
"""
    proc = None
    try:
        with tempfile.TemporaryDirectory(prefix="mere-device-check-") as folder:
            script = Path(folder) / "writer.rb"
            script.write_text(source)
            proc = subprocess.Popen([binary, str(script), path], cwd=ROOT, env=env,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            assert select.select([proc.stdout], [], [], 15)[0], "writer never became ready"
            assert proc.stdout.readline() == b"ready\n", "writer startup failed"
            # Begin draining only after the writer can fill the PTY queue.
            time.sleep(0.25)
            data = bytearray()
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                ready = select.select([master], [], [], 0.05)[0]
                if ready:
                    data.extend(os.read(master, 65536))
                    assert len(data) <= len(PAYLOAD), "device received duplicated bytes"
                elif proc.poll() is not None:
                    break
            else:
                raise AssertionError("device writer did not finish under backpressure")
            out, err = proc.communicate(timeout=5)
            assert proc.returncode == 0 and out == b"done\n" and not err, (proc.returncode, out, err)
            assert bytes(data) == PAYLOAD, (binary, len(data), len(PAYLOAD))
    finally:
        if proc is not None and proc.poll() is None:
            proc.kill()
            proc.wait()
        os.close(master)
        os.close(slave)


check(RUBY, dict(os.environ))
for indexing in ("on", "off"):
    for gc in ("normal", "100"):
        env = dict(os.environ)
        env.pop("MERE_RUBY_NO_HASH_INDEX", None)
        env.pop("MERE_RUBY_GC_STRESS", None)
        if indexing == "off":
            env["MERE_RUBY_NO_HASH_INDEX"] = "1"
        if gc != "normal":
            env["MERE_RUBY_GC_STRESS"] = gc
        check(MERE, env)
print("Character-device backpressure: all 200,000 bytes delivered in four modes")
