#!/usr/bin/env python3
"""Exercise native resolver ownership and numeric nonblocking connections."""
import ctypes
import errno
import fcntl
import os
from pathlib import Path
import select
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent


def wait_for(test):
    deadline = time.monotonic() + 5
    while not test():
        assert time.monotonic() < deadline, 'native operation did not finish'
        time.sleep(0.001)


with tempfile.TemporaryDirectory() as directory:
    library = Path(directory) / 'socket_glue.so'
    subprocess.run([os.environ.get('CC', 'clang'), '-shared', '-fPIC', '-pthread',
                    '-Wall', '-Wextra', '-Werror', str(ROOT / 'tools/socket_glue.c'),
                    '-o', str(library)], check=True, timeout=30)
    lib = ctypes.CDLL(str(library))
    lib.mr_resolve_start.argtypes = [ctypes.c_char_p] + [ctypes.c_int] * 4
    lib.mr_resolve_address.argtypes = [ctypes.c_int, ctypes.c_int]
    lib.mr_resolve_address.restype = ctypes.c_char_p
    lib.mr_connect_start.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_int]
    lib.mr_ip_addresses.restype = ctypes.c_char_p

    job = lib.mr_resolve_start(b'localhost', 80, 4, 0, 0)
    assert job > 0
    wait_for(lambda: lib.mr_resolve_done(job))
    assert lib.mr_resolve_error(job) == 0
    assert lib.mr_resolve_address(job, 0) == b'127.0.0.1'
    lib.mr_resolve_release(job)
    assert lib.mr_resolve_address(job, 0) == b''

    job = lib.mr_resolve_start(b'localhost', 80, 6, 20, socket.EAI_FAIL)
    wait_for(lambda: lib.mr_resolve_done(job))
    assert lib.mr_resolve_error(job) == socket.EAI_FAIL
    lib.mr_resolve_release(job)

    # Release before a resolver starts, during its delay, and after completion.
    # Each worker must release its remaining reference without a caller join.
    for _ in range(100):
        job = lib.mr_resolve_start(b'localhost', 80, 4, 5000, 0)
        assert job > 0 and lib.mr_resolve_done(job) == 0
        before = time.monotonic()
        lib.mr_resolve_release(job)
        assert time.monotonic() - before < 1
        lib.mr_resolve_release(job)  # already released; no stale pointer
    time.sleep(0.05)

    # A forked child has no resolver workers from its parent. It must be able
    # to start a fresh resolution, and old request IDs must not become valid.
    job = lib.mr_resolve_start(b'localhost', 80, 4, 5000, 0)
    child = os.fork()
    if child == 0:
        try:
            assert lib.mr_resolve_address(job, 0) == b''
            fresh = lib.mr_resolve_start(b'localhost', 80, 4, 0, 0)
            assert fresh > 0 and fresh != job
            wait_for(lambda: lib.mr_resolve_done(fresh))
            assert lib.mr_resolve_error(fresh) == 0
            lib.mr_resolve_release(fresh)
            os._exit(0)
        except BaseException:
            os._exit(1)
    lib.mr_resolve_release(job)
    status = []
    def child_finished():
        pid, value = os.waitpid(child, os.WNOHANG)
        if pid:
            status.append(value)
        return bool(pid)
    try:
        wait_for(child_finished)
    except BaseException:
        os.kill(child, 9)
        os.waitpid(child, 0)
        raise
    assert status == [0]

    with socket.socket() as server:
        server.bind(('127.0.0.1', 0))
        server.listen()
        fd = lib.mr_connect_start(b'127.0.0.1', server.getsockname()[1], b'127.0.0.1', 0)
        assert fd >= 0
        try:
            assert fcntl.fcntl(fd, fcntl.F_GETFL) & os.O_NONBLOCK
            assert fcntl.fcntl(fd, fcntl.F_GETFD) & fcntl.FD_CLOEXEC
            assert select.select([], [fd], [], 5)[1] == [fd]
            assert lib.mr_connect_error(fd) == 0
            server.settimeout(5)
            accepted, _ = server.accept()
            accepted.close()
        finally:
            os.close(fd)
        bad = lib.mr_connect_start(b'127.0.0.1', server.getsockname()[1], b'192.0.2.1', 8000)
        assert bad == -errno.EADDRNOTAVAIL

    addresses = lib.mr_ip_addresses().splitlines()
    assert addresses
    for address in addresses:
        raw = bytes.fromhex(address.decode())
        assert len(raw) == raw[0] and raw[1] in (socket.AF_INET, socket.AF_INET6)
    print('native socket resolver lifecycle, nonblocking connect, binding and interface addresses: PASS')
