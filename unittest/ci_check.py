#!/usr/bin/env python3
"""Check sharding, partial collection and provenance without building Mere."""
import contextlib
import io
import os
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import ci
import harness_check


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
        patch.object(ci, "group_rss", return_value=1).start()
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
        with patch.object(ci, "group_rss", side_effect=RuntimeError("monitor unavailable")):
            self.assertEqual(self.run_shard(0), 1)
        self.assertTrue(all(row["ref_state"] == "INFRA_ERROR" for row in ci.load(self.output / "0/result.json")["rows"]))

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
        result["bounds"]["rss_group_kb"] *= 2
        ci.save(path, result)
        self.assertEqual(self.merge(), 1)

    def test_monitor_kills_only_its_own_process_group(self):
        log = self.root / "limited.log"
        # A fixed memory reading exercises the actual group cleanup without
        # depending on the host ps implementation or allocating large memory.
        with patch.object(ci, "group_rss", return_value=1025):
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


if __name__ == "__main__":
    unittest.main()
