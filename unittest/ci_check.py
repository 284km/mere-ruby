#!/usr/bin/env python3
"""Check sharding, partial collection and provenance without building Mere."""
import contextlib
import io
import json
import os
import shlex
import shutil
import subprocess
import signal
import sys
import time
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import ci
import harness_check

REAL_RUBY = os.environ.get("UNITTEST_REAL_RUBY")
REAL_TOOL_LIB = os.environ.get("UNITTEST_REAL_TOOL_LIB")


class FixtureFamily:
    """Controlled transcript tests spawn no escaping children."""
    def __init__(self, process, marker):
        self.process = process

    @staticmethod
    def preflight():
        pass

    def sample(self):
        return 1

    def stop(self):
        try:
            os.killpg(self.process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        self.process.wait()


class CICheck(unittest.TestCase):
    def setUp(self):
        fixture = harness_check.HarnessCheck()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        self.fixture = fixture
        self.root = fixture.root
        self.plan_path = self.root / "plan/manifest.json"
        self.build = self.root / "build.json"
        self.reference = self.root / "reference.json"
        self.output = self.root / "results"
        self.addCleanup(patch.stopall)
        patch.object(ci, "ROOT", self.root).start()
        patch.dict(os.environ, dict(fixture.env, REF_RUBY_BIN=str(self.root / "reference"))).start()
        patch.object(ci, "ProcessFamily", FixtureFamily).start()
        patch.dict(os.environ, {"GITHUB_OUTPUT": "", "GITHUB_STEP_SUMMARY": ""}).start()
        self.quiet = contextlib.redirect_stdout(io.StringIO())
        self.quiet.__enter__()
        self.addCleanup(self.quiet.__exit__, None, None, None)
        ci.plan(SimpleNamespace(ruby_src=self.root / "src", output=self.root / "plan", shards=2,
                                source_ref="a" * 40, mere_ref="b" * 40, ruby_ref="c" * 40, ruby_version="fixture"))
        ci.save(self.build, dict(source_ref="a" * 40, mere_ref="b" * 40,
                                binary_sha256=ci.digest(self.root / "mere-ruby"), optimization="O2"))
        ci.save(self.reference, dict(ruby_ref="c" * 40, version="fixture",
                                    binary_sha256=ci.digest(self.root / "reference")))

    def run_shard(self, shard):
        return ci.run_shard(SimpleNamespace(plan=self.plan_path, build_info=self.build, reference_info=self.reference, shard=shard,
                                            ruby_src=self.root / "src", output=self.output / str(shard), wall=5, rss_kb=1024))

    def merge(self):
        return ci.merge(SimpleNamespace(plan=self.plan_path, input=self.output, output=self.root / "report"))

    def test_complete_measurement_covers_every_planned_file(self):
        self.assertEqual(self.run_shard(0), 0)
        self.assertEqual(self.run_shard(1), 0)
        self.assertEqual(self.merge(), 0)
        summary = ci.load(self.root / "report/summary.json")
        self.assertEqual(summary["expected_files"], 3)
        self.assertEqual(summary["totals"]["match"], 3)
        self.assertEqual(summary["missing_files"], 0)

    def test_missing_shard_retains_all_manifest_rows_and_fails_collection(self):
        self.run_shard(0)
        self.assertEqual(self.merge(), 1)
        text = (self.root / "report/files.tsv").read_text()
        self.assertIn("MISSING_SHARD", text)
        self.assertEqual(len(text.splitlines()), 4)

    def test_unattempted_file_in_partial_artifact_is_not_dropped(self):
        self.run_shard(0)
        self.run_shard(1)
        path = self.output / "0/result.json"
        result = ci.load(path)
        result["rows"][-1] = dict(file=result["rows"][-1]["file"], ref_state="NOT_RUN", mere_state="NOT_RUN")
        ci.save(path, result)
        self.assertEqual(self.merge(), 1)
        self.assertIn("NOT_RUN", (self.root / "report/files.tsv").read_text())

    def test_wrong_build_is_refused_before_execution(self):
        build = ci.load(self.build)
        build["mere_ref"] = "wrong"
        ci.save(self.build, build)
        with self.assertRaises(ValueError):
            self.run_shard(0)

    def test_wrong_reference_is_refused_before_execution(self):
        reference = ci.load(self.reference)
        reference["ruby_ref"] = "wrong"
        ci.save(self.reference, reference)
        with self.assertRaises(ValueError):
            self.run_shard(0)

    def test_mismatched_provenance_is_not_merged(self):
        self.run_shard(0)
        self.run_shard(1)
        path = self.output / "1/result.json"
        result = ci.load(path)
        result["ruby_ref"] = "wrong"
        ci.save(path, result)
        self.assertEqual(self.merge(), 1)

    def test_different_reference_binaries_fail_collection(self):
        self.run_shard(0)
        self.run_shard(1)
        path = self.output / "1/result.json"
        result = ci.load(path)
        result["reference_sha256"] = "different"
        ci.save(path, result)
        self.assertEqual(self.merge(), 1)

    def test_zero_tests_are_reported_without_claiming_conformance(self):
        for side in ("reference", "mere-ruby"):
            self.fixture.transcript(side, "0 tests, 0 assertions, 0 failures, 0 errors, 0 skips\n")
        self.run_shard(0)
        self.run_shard(1)
        self.assertEqual(self.merge(), 0)
        summary = ci.load(self.root / "report/summary.json")
        self.assertEqual(summary["incomplete_files"], 3)
        self.assertEqual(summary["totals"]["tests"], 0)
        self.assertIn("ZERO", (self.root / "report/files.tsv").read_text())

    def test_memory_limit_preserves_finished_reference_and_partial_diagnostics(self):
        def limited(command, env, log, rss, seconds):
            work, index = Path(command[-3]), command[-2]
            (work / f"{index}.phase").write_text("mere\n")
            (work / f"{index}.ref-coverage").write_text("COMPLETE\t0\t1\t1\n")
            (work / f"{index}.stderr").write_text("partial diagnostic\n")
            log.write_text("")
            return dict(exit=-9, peak_rss_kb=rss + 1, seconds=0.1, limit="MEMORY_LIMIT")
        with patch.object(ci, "supervise", side_effect=limited):
            self.assertEqual(self.run_shard(0), 0)
        result = ci.load(self.output / "0/result.json")
        self.assertTrue(all(row["ref_state"] == "COMPLETE" and row["mere_state"] == "MEMORY_LIMIT" for row in result["rows"]))
        self.assertTrue(list((self.output / "0/logs").glob("*.partial.stderr")))

    def test_lost_rss_monitor_is_an_infrastructure_failure(self):
        with patch.object(FixtureFamily, "sample", side_effect=RuntimeError("monitor unavailable")):
            self.assertEqual(self.run_shard(0), 1)
        rows = ci.load(self.output / "0/result.json")["rows"]
        self.assertEqual(rows[0]["ref_state"], "INFRA_ERROR")
        self.assertTrue(all(row["ref_state"] == "NOT_RUN" for row in rows[1:]))

    def test_duplicate_shards_are_not_summed_twice(self):
        self.run_shard(0)
        self.run_shard(1)
        ci.save(self.output / "duplicate/result.json", ci.load(self.output / "0/result.json"))
        self.assertEqual(self.merge(), 1)
        self.assertEqual(ci.load(self.root / "report/summary.json")["totals"]["match"], 3)

    def test_different_bounds_are_not_merged_as_one_measurement(self):
        self.run_shard(0)
        self.run_shard(1)
        path = self.output / "1/result.json"
        result = ci.load(path)
        result["bounds"]["rss_family_kb"] *= 2
        ci.save(path, result)
        self.assertEqual(self.merge(), 1)

    def test_different_environment_policies_are_not_merged(self):
        self.run_shard(0)
        self.run_shard(1)
        path = self.output / "1/result.json"
        result = ci.load(path)
        result["environment_policy"] = "legacy-inherited"
        ci.save(path, result)
        self.assertEqual(self.merge(), 1)

    def test_monitor_kills_only_its_own_process_group(self):
        log = self.root / "limited.log"
        # A fixed memory reading exercises the actual group cleanup without
        # depending on the host ps implementation or allocating large memory.
        with patch.object(FixtureFamily, "sample", return_value=1025):
            result = ci.supervise(["sh", "-c", "sleep 10"], dict(os.environ), log, 1024, 10)
        self.assertEqual(result["limit"], "MEMORY_LIMIT")
        self.assertLess(result["seconds"], 3)

    def test_outer_wall_limit_cleans_up_the_worker(self):
        result = ci.supervise(["sh", "-c", "sleep 10"], dict(os.environ), self.root / "wall.log", 1024, 0.01)
        self.assertEqual(result["limit"], "WALL_LIMIT")
        self.assertLess(result["seconds"], 3)

    def test_failed_cases_keep_masked_tags_in_the_shard_artifact(self):
        failure = ("[1/1] Example#test_ok = 0.00 s\n  1) Failure:\n"
                   "Example#test_ok [test_ok.rb:1]:\nfailed\n"
                   "1 tests, 1 assertions, 1 failures, 0 errors, 0 skips\n")
        self.fixture.transcript("mere-ruby", failure, 1)
        self.assertEqual(self.run_shard(0), 0)
        self.assertTrue(list((self.output / "0/tags").glob("*.txt")))
        self.assertTrue(all(row["red"] == 1 for row in ci.load(self.output / "0/result.json")["rows"]))

    def test_masks_machine_paths_and_environment_dumps_in_artifacts(self):
        source = self.root / "diagnostic.out"
        target = self.root / "public.out"
        source.write_text('/Users/operator/private/test.rb:9: failure\n{"ACCESS_TOKEN"=>"private-value"}\n')
        ci.sanitize(source, target)
        text = target.read_text()
        self.assertNotIn("/Users/operator", text)
        self.assertNotIn("private-value", text)

    def test_diagnostic_memory_is_bounded_as_unterminated_input_grows(self):
        # Separate processes make peak RSS comparable. No newline: sed/perl
        # must not be allowed to buffer the entire raw log as a single line.
        worker = '''import json, resource, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import ci
ci.sanitize(Path(sys.argv[2]), Path(sys.argv[3]))
divisor = 1024 if sys.platform == "darwin" else 1
print(json.dumps({"parent_kb": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / divisor,
                  "mask_kb": resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss / divisor}))
'''
        samples = []
        for size_mb in (8, 64):
            source, target = self.root / f"raw-{size_mb}.out", self.root / f"public-{size_mb}.out"
            with source.open("wb") as raw:
                block = b"x" * 65536
                for _ in range(size_mb * 16):
                    raw.write(block)
            result = subprocess.run([sys.executable, "-c", worker, str(Path(ci.__file__).parent),
                                     str(source), str(target)], text=True, capture_output=True,
                                    timeout=30, check=True)
            samples.append(json.loads(result.stdout))
            self.assertLessEqual(target.stat().st_size, ci.LOG_OUTPUT_CAP + 128)
            self.assertIn(b"input limit", target.read_bytes())
        # Allow interpreter/OS noise, while rejecting the previous ~56 MiB
        # increase for this 8 -> 64 MiB input change, in parent or mask tools.
        print("Diagnostic peak RSS KiB (8/64 MiB input): " + json.dumps(samples), file=sys.stderr)
        for component in ("parent_kb", "mask_kb"):
            self.assertLess(samples[1][component] - samples[0][component], 16 * 1024, samples)

    def test_input_truncation_is_reported_even_when_masked_output_is_short(self):
        source, target = self.root / "hash.out", self.root / "public.out"
        source.write_bytes(b'{"key"=>"' + b"x" * ci.LOG_INPUT_CAP + b'"}')
        ci.sanitize(source, target)
        text = target.read_text()
        self.assertTrue(text.startswith("{..."))
        self.assertIn("input limit", text)
        self.assertLess(len(text), 128)

    def test_expanded_output_is_capped_and_utf8_boundaries_are_valid(self):
        source, target = self.root / "invalid.out", self.root / "public.out"
        source.write_bytes(b"\xff" * (ci.LOG_INPUT_CAP // 2))
        ci.sanitize(source, target)
        self.assertLessEqual(target.stat().st_size, ci.LOG_OUTPUT_CAP + 128)
        self.assertIn("output limit", target.read_text())
        source.write_text("abcd\U0001f600\n")
        with patch.object(ci, "LOG_OUTPUT_CAP", 5):
            ci.sanitize(source, target)
        self.assertTrue(target.read_text().startswith("abcd\n[diagnostic log truncated"))

    def test_mask_timeout_reclaims_its_group_and_publishes_no_output(self):
        source, target = self.root / "raw.out", self.root / "public.out"
        source.write_text("diagnostic\n")
        for body in ("sleep 30", "yes noisy"):
            with self.subTest(mask=body):
                (self.root / "mspec/mask.sh").write_text("strip_noise() { " + body + "; }\n")
                start = time.monotonic()
                with patch.object(ci, "LOG_MASK_SECONDS", 0.1), patch.object(ci.os, "killpg", wraps=os.killpg) as kill:
                    with self.assertRaises(subprocess.TimeoutExpired):
                        ci.sanitize(source, target)
                kill.assert_called_once()
                self.assertEqual(kill.call_args.args[1], signal.SIGKILL)
                self.assertLess(time.monotonic() - start, 3)
                self.assertFalse(target.exists())

    def test_failed_mask_does_not_publish_unfiltered_output(self):
        source, target = self.root / "raw.out", self.root / "public.out"
        source.write_text("private diagnostic\n")
        (self.root / "mspec/mask.sh").write_text("strip_noise() { cat; return 1; }\n")
        with self.assertRaises(subprocess.CalledProcessError):
            ci.sanitize(source, target)
        self.assertFalse(target.exists())

    def reference_context_fixture(self):
        settings = json.loads(subprocess.check_output(
            [REAL_RUBY, "-rrbconfig", "-rjson", "-e",
             'puts JSON.generate(RbConfig::CONFIG.slice("arch", "LIBRUBY_A", "prefix", "bindir"))'], text=True))
        build = self.root / "ruby source's build"
        for name in ("Makefile", settings["LIBRUBY_A"], "lib/mkmf.rb", "include/ruby.h",
                     f'.ext/include/{settings["arch"]}/ruby/config.h'):
            path = build / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("# context fixture, not used for compilation\n")
        return settings, build

    @unittest.skipUnless(REAL_RUBY, "set UNITTEST_REAL_RUBY for the reference context fixture")
    def test_reference_context_rebinds_build_directory_and_preserves_installation(self):
        settings, build = self.reference_context_fixture()
        subprocess.run([REAL_RUBY, str(harness_check.ROOT / "unittest/prepare_reference.rb"), str(build)],
                       check=True, capture_output=True, text=True, timeout=10)
        code = 'puts JSON.generate(RbConfig::CONFIG.slice("topdir", "prefix", "bindir"))'
        result = subprocess.check_output([REAL_RUBY, "-I", str(build / ".unittest-reference"),
                                          "-rrbconfig", "-rjson", "-e", code], text=True, timeout=10)
        config = json.loads(result)
        self.assertEqual(config["topdir"], str(build.resolve()))
        self.assertEqual(config["prefix"], settings["prefix"])
        self.assertEqual(config["bindir"], settings["bindir"])

    @unittest.skipUnless(REAL_RUBY, "set UNITTEST_REAL_RUBY for the reference context fixture")
    def test_incomplete_reference_build_context_is_refused(self):
        settings, build = self.reference_context_fixture()
        (build / settings["LIBRUBY_A"]).unlink()
        result = subprocess.run([REAL_RUBY, str(harness_check.ROOT / "unittest/prepare_reference.rb"), str(build)],
                                capture_output=True, text=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(settings["LIBRUBY_A"], result.stderr)
        self.assertFalse((build / ".unittest-reference/rbconfig.rb").exists())

    def test_interpreters_receive_only_an_allowlist_and_an_empty_home(self):
        private = self.root / "private-environment"
        private.mkdir()
        with patch.dict(os.environ, {"REVIEW_SECRET": "SYNTHETIC_SECRET_VALUE", "ACTIONS_RUNTIME_TOKEN": "SYNTHETIC_TOKEN"}):
            env = ci.test_environment(private, self.root / "mere-ruby", "fixture")
        self.assertNotIn("REVIEW_SECRET", env)
        self.assertNotIn("ACTIONS_RUNTIME_TOKEN", env)
        self.assertEqual(env["HOME"], str(private / "home"))
        self.assertEqual(list((private / "home").iterdir()), [])
        self.assertEqual(env["UNITTEST_SEED"], "1")

    @unittest.skipUnless(REAL_RUBY and REAL_TOOL_LIB, "set UNITTEST_REAL_RUBY and UNITTEST_REAL_TOOL_LIB for the real Test::Unit fixture")
    def test_real_test_unit_multiline_hash_and_array_diagnostics_do_not_leak_parent_environment(self):
        shutil.copytree(REAL_TOOL_LIB, self.root / "src/tool/lib", dirs_exist_ok=True)
        # This helper is outside the current test directory, as psych/helper
        # and rubygems/simple_gem are in the real source tree.
        (self.root / "src/test/diagnostic_helper.rb").write_text('DIAGNOSTIC_EXPECTED = "different"\n')
        program = self.root / "src/test/ruby/test_env_diagnostics.rb"
        program.write_text('''require "test/unit"
require "diagnostic_helper"
class TestEnvironmentDiagnostics < Test::Unit::TestCase
  def test_hash
    assert_equal({"expected" => DIAGNOSTIC_EXPECTED}, ENV.to_h)
  end
  def test_pairs
    assert_equal([["expected", DIAGNOSTIC_EXPECTED]], ENV.to_a)
  end
end
''')
        secret = "SYNTHETIC_SECRET_VALUE"
        baseline_env = dict(PATH=os.environ["PATH"], HOME=str(self.root), TMPDIR=str(self.root),
                            LC_ALL="C", REVIEW_SECRET=secret)
        baseline = subprocess.run([REAL_RUBY, "-I", REAL_TOOL_LIB, "-I", str(self.root / "src/test"),
                                   "-r", "test/unit", str(program), "-v"],
                                  env=baseline_env, text=True, capture_output=True, timeout=15)
        self.assertEqual(baseline.returncode, 2)
        self.assertTrue(secret in baseline.stdout, "the real framework must render the synthetic environment value")
        version = subprocess.check_output([REAL_RUBY, "-e", "print RUBY_VERSION"], text=True).strip()
        for name in ("reference", "mere-ruby"):
            (self.root / name).unlink()
            (self.root / name).symlink_to(Path(REAL_RUBY).resolve())
        (self.root / "tools/ref_ruby.sh").write_text(
            f"REF_RUBY_VERSION={shlex.quote(version)}\nREF_RUBY_BIN={shlex.quote(str(self.root / 'reference'))}\n")
        build = ci.load(self.build)
        build["binary_sha256"] = ci.digest(self.root / "mere-ruby")
        ci.save(self.build, build)
        ci.save(self.reference, dict(ruby_ref="c" * 40, version=version,
                                    binary_sha256=ci.digest(self.root / "reference")))
        manifest = ci.load(self.plan_path)
        manifest.update(files=["ruby/test_env_diagnostics.rb"], shards=1, ruby_version=version)
        ci.save(self.plan_path, manifest)
        with patch.dict(os.environ, {"REVIEW_SECRET": secret}):
            self.assertEqual(self.run_shard(0), 0)
        result = ci.load(self.output / "0/result.json")
        self.assertEqual(result["rows"][0]["ref_state"], "COMPLETE")
        self.assertEqual(result["rows"][0]["mere_state"], "COMPLETE")
        self.assertEqual(result["rows"][0]["both"], 2)
        self.assertTrue((self.output / "0/logs/ruby_test_env_diagnostics.reference.out").exists())
        self.assertTrue((self.output / "0/logs/ruby_test_env_diagnostics.out").exists())
        for path in (self.output / "0").rglob("*"):
            if path.is_file():
                self.assertFalse(secret in path.read_text(errors="replace"), "parent environment leaked into an artifact")


if __name__ == "__main__":
    unittest.main()
