#!/usr/bin/env python3
"""Check runtime-specific library ordering at the corpus and mspec boundaries."""
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
OWN = "/fixture/mere/stdlib:/fixture/mere/arch"
FALLBACK = "/fixture/reference/stdlib:/fixture/a gem/lib"


class LoadPathCheck(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="mere-load-path-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for folder in ("tools", "mspec", "corpus"):
            (self.root / folder).mkdir()
        for name in ("run_corpus.sh", "tools/runtime_load_path.sh",
                     "mspec/run_spec.sh", "mspec/bounds.sh", "mspec/spec_helper.rb"):
            shutil.copyfile(ROOT / name, self.root / name)
        # Source guards have separate controls; this fixture exercises execution
        # of both corpus passes and the pre-sweep interpreter self-check.
        for guard in ("gc_roots", "dup_defs", "dead_defs", "meth_writes",
                      "name_spec", "rx_caps", "ns_names", "name_len"):
            (self.root / "tools" / f"{guard}_check.sh").write_text("#!/bin/sh\nexit 0\n")
            (self.root / "tools" / f"{guard}_check.sh").chmod(0o755)
        (self.root / "mspec/record_hygiene.sh").write_text("#!/bin/sh\nexit 0\n")
        (self.root / "mspec/record_hygiene.sh").chmod(0o755)
        for name in ("01_arith.rb", "02_monitor.rb"):
            (self.root / "corpus" / name).write_text("require 'monitor'\n")
        (self.root / "probe_spec.rb").write_text("require 'monitor'\n")
        interpreter = '''#!PYTHON
import json, os, pathlib, sys
root = pathlib.Path(__file__).resolve().parent
side = pathlib.Path(__file__).name
query = "-e" in sys.argv
record = dict(query=query, library=os.environ.get("RUBYLIB"),
              options=os.environ.get("RUBYOPT"),
              errno=os.environ.get("MERE_RUBY_ERRNO_CHECK"),
              no_hash=os.environ.get("MERE_RUBY_NO_HASH_INDEX"))
with (root / (side + ".jsonl")).open("a") as log:
    log.write(json.dumps(record) + "\\n")
if query:
    if (root / "query-fails").exists(): sys.exit(17)
    print("OWN", end="")
elif side == "mere-ruby" and (root / "require-own").exists() and not (record["library"] or "").startswith("OWN:"):
    print("cannot load such file -- monitor.so", file=sys.stderr)
    sys.exit(1)
else:
    print("pass=2 fail=0 err=0")
'''.replace("PYTHON", sys.executable).replace("OWN", OWN)
        for name in ("mere-ruby", "reference"):
            (self.root / name).write_text(interpreter)
            (self.root / name).chmod(0o755)
        (self.root / "tools/ref_ruby.sh").write_text(
            "REF_RUBY_BIN=" + shlex.quote(str(self.root / "reference")) + "\n")
        self.env = dict(os.environ, LANG="en_US.UTF-8", MR_BIN=str(self.root / "mere-ruby"))
        for name in ("RUBYLIB", "RUBYOPT", "SPEC_MERE_LOAD_PATH", "SPEC_TREE", "SPEC_CPU_OK",
                     "MERE_RUBY_NO_HASH_INDEX", "MERE_RUBY_ERRNO_CHECK"):
            self.env.pop(name, None)

    def run_driver(self, name, *args):
        return subprocess.run(["sh", str(self.root / name), *args], cwd=self.root,
                              env=self.env, text=True, capture_output=True, timeout=15)

    def records(self, name):
        return [json.loads(line) for line in (self.root / f"{name}.jsonl").read_text().splitlines()]

    def test_query_ignores_inherited_ruby_configuration(self):
        self.env.update(RUBYLIB=FALLBACK, RUBYOPT="-rmonitor")
        result = self.run_driver("tools/runtime_load_path.sh", str(self.root / "mere-ruby"))
        self.assertEqual((result.returncode, result.stdout), (0, OWN), result.stderr)
        query, = self.records("mere-ruby")
        self.assertEqual((query["library"], query["options"]), ("", ""))

    def test_corpus_preserves_unset_library_and_queries_nothing(self):
        result = self.run_driver("run_corpus.sh", "--both")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for side in ("mere-ruby", "reference"):
            self.assertTrue(all(not r["query"] and r["library"] is None for r in self.records(side)))

    def test_corpus_uses_own_paths_in_self_check_and_both_passes(self):
        self.env["RUBYLIB"] = FALLBACK
        (self.root / "require-own").touch()
        result = self.run_driver("run_corpus.sh", "--both")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        records = self.records("mere-ruby")
        self.assertEqual(sum(r["query"] for r in records), 1)
        runs = [r for r in records if not r["query"]]
        self.assertEqual(len(runs), 5)
        self.assertTrue(runs[0]["errno"])
        self.assertEqual(sum(r["no_hash"] == "1" for r in runs), 2)
        self.assertTrue(all(r["library"] == OWN + ":" + FALLBACK for r in runs))
        self.assertTrue(all(r["library"] == FALLBACK for r in self.records("reference")))

    def test_corpus_stops_if_own_path_query_fails(self):
        self.env["RUBYLIB"] = FALLBACK
        (self.root / "query-fails").touch()
        result = self.run_driver("run_corpus.sh", "--both")
        self.assertEqual(result.returncode, 17)
        self.assertEqual(len(self.records("mere-ruby")), 1)
        self.assertFalse((self.root / "reference.jsonl").exists())

    def test_mspec_stops_if_own_path_query_fails(self):
        self.env["RUBYLIB"] = FALLBACK
        (self.root / "query-fails").touch()
        result = self.run_driver("mspec/run_spec.sh", str(self.root / "probe_spec.rb"))
        self.assertEqual(result.returncode, 2)
        self.assertEqual(len(self.records("mere-ruby")), 1)
        self.assertFalse((self.root / "reference.jsonl").exists())

    @unittest.skipUnless(sys.platform == "darwin", "run_spec.sh uses BSD time's -l")
    def test_mspec_orders_each_side_and_uses_sweep_cache(self):
        for cached in (False, True):
            with self.subTest(cached=cached):
                for file in self.root.glob("*.jsonl"):
                    file.unlink()
                self.env["RUBYLIB"] = FALLBACK
                self.env["SPEC_CPU_OK"] = "1"
                if cached:
                    self.env["SPEC_MERE_LOAD_PATH"] = OWN
                (self.root / "require-own").touch()
                result = self.run_driver("mspec/run_spec.sh", str(self.root / "probe_spec.rb"))
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(result.stdout.splitlines()[-1], "MATCH")
                records = self.records("mere-ruby")
                self.assertEqual(sum(r["query"] for r in records), 0 if cached else 1)
                self.assertEqual(records[-1]["library"], OWN + ":" + FALLBACK)
                self.assertEqual(self.records("reference")[-1]["library"], FALLBACK)


if __name__ == "__main__":
    unittest.main()
