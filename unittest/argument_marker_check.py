#!/usr/bin/env python3
"""Repeated calls must not retain overwritten argument-marker names forever."""
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
binary = os.environ.get("MR_BIN", str(ROOT / "mere-ruby"))
for indexing in ("ON", "OFF"):
    allocations = []
    for count in (1000, 100000):
        env = dict(os.environ, MERE_REGION_STATS="1")
        if indexing == "OFF":
            env["MERE_RUBY_NO_HASH_INDEX"] = "1"
        else:
            env.pop("MERE_RUBY_NO_HASH_INDEX", None)
        result = subprocess.run(
            [binary, str(ROOT / "bench/argument_markers.rb"), str(count)],
            env=env, capture_output=True, text=True, timeout=60, check=True)
        assert result.stdout == "argument markers: values preserved\n", result.stdout
        match = re.search(r"region-stats default:.*alloc_total=(\d+)", result.stderr)
        assert match, result.stderr
        allocations.append(int(match[1]))
    # Native allocation totals exclude allocator/RSS sampling noise. Allow
    # auxiliary table growth, but reject a retained name copy on every call.
    assert allocations[1] - allocations[0] < 2 * 1024 * 1024, (indexing, allocations)
    print(f"hash indexing {indexing}: default-region bytes = {allocations}")
