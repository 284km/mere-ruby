#!/usr/bin/env python3
"""Exercise discovery and accounting with controlled interpreter transcripts."""
import csv
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class HarnessCheck(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="mere-ruby-harness-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for folder in ["unittest", "tools", "mspec", "src/test/ruby/enc", "src/tool/lib", "bin"]:
            (self.root / folder).mkdir(parents=True)
        for script in ["run.sh", "list.sh"]:
            shutil.copyfile(ROOT / "unittest" / script, self.root / "unittest" / script)
        shutil.copyfile(ROOT / "mspec/mask.sh", self.root / "mspec/mask.sh")
        (self.root / "unittest/files.txt").write_text("ruby\n-ruby/test_vm.rb\n")
        for name in ["test_ok.rb", "test_vm.rb", "test_helper.rb", "enc/test_encoding.rb"]:
            (self.root / "src/test/ruby" / name).write_text("# fixture\n")
        # No global RSS poller: these fake interpreters only print fixed text.
        (self.root / "mspec/rss_guard.sh").write_text("#!/bin/sh\nexit 0\n")
        (self.root / "bin/pgrep").write_text("#!/bin/sh\nexit 1\n")
        (self.root / "bin/pgrep").chmod(0o755)
        (self.root / "tools/ref_ruby.sh").write_text(
            'REF_RUBY_VERSION=fixture\nREF_RUBY_BIN="$FIXTURE_ROOT/reference"\n')
        interpreter = '''#!/bin/sh
case "$*" in *rubylibdir*) printf '\\n'; exit 0 ;; esac
preload=0
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-r" ] && [ "${2:-}" = "test/unit" ]; then preload=1; fi
  shift
done
[ "$preload" -eq 1 ] || { echo 'uninitialized constant Test (NameError)'; exit 1; }
side=$(basename "$0")
if [ -f "$FIXTURE_ROOT/$side.interleave" ]; then
  printf '[1/1] Example#test_ok'
  printf '/fixture/test.rb:1: warning: test warning\\n' >&2
  printf ' = 0.00 s\\n1 tests, 1 assertions, 0 failures, 0 errors, 0 skips\\n'
else
  cat "$FIXTURE_ROOT/$side.transcript"
fi
exit "$(cat "$FIXTURE_ROOT/$side.code")"
'''
        for side in ["reference", "mere-ruby"]:
            (self.root / side).write_text(interpreter)
            (self.root / side).chmod(0o755)
            self.transcript(side, self.passing())
        self.env = dict(os.environ, FIXTURE_ROOT=str(self.root),
                        MR_BIN=str(self.root / "mere-ruby"),
                        UNITTEST_RECORD_DIR=str(self.root / "records"),
                        UNITTEST_KEEP=str(self.root / "raw"),
                        PATH=str(self.root / "bin") + os.pathsep + os.environ["PATH"])

    @staticmethod
    def passing():
        return "[ 1/1] Example#test_ok = 0.00 s\n1 tests, 1 assertions, 0 failures, 0 errors, 0 skips\n"

    def transcript(self, side, text, code=0):
        (self.root / f"{side}.transcript").write_text(text)
        (self.root / f"{side}.code").write_text(str(code))

    def run_harness(self, *paths):
        return subprocess.run(["sh", str(self.root / "unittest/run.sh"),
                               str(self.root / "src"), *paths],
                              env=self.env, text=True, capture_output=True, timeout=15)

    def coverage(self):
        with (self.root / "records/COVERAGE.tsv").open() as file:
            return list(csv.DictReader(file, delimiter="\t"))

    def test_discovery_default_recursive_explicit_and_all(self):
        cases = [((), ["ruby/test_ok.rb"]),
                 (("ruby/enc",), ["ruby/enc/test_encoding.rb"]),
                 (("ruby/test_vm.rb",), ["ruby/test_vm.rb"]),
                 (("--all",), ["ruby/enc/test_encoding.rb", "ruby/test_ok.rb", "ruby/test_vm.rb"]),
                 (("ruby", "ruby/test_ok.rb"), ["ruby/enc/test_encoding.rb", "ruby/test_ok.rb", "ruby/test_vm.rb"])]
        for paths, expected in cases:
            with self.subTest(paths=paths):
                result = self.run_harness("--list", *paths)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.splitlines(), expected)
        # Listing must work even when no interpreter is installed or built.
        (self.root / "mere-ruby").unlink()
        self.assertEqual(self.run_harness("--list", "--all").returncode, 0)

    def test_manifest_without_exclusions(self):
        (self.root / "unittest/files.txt").write_text("ruby\n")
        self.assertEqual(self.run_harness("--list").stdout.splitlines(),
                         ["ruby/test_ok.rb", "ruby/test_vm.rb"])

    def test_extension_directory_with_leading_hyphen(self):
        (self.root / "src/test/-ext-").mkdir()
        (self.root / "src/test/-ext-/test_bug.rb").write_text("# fixture\n")
        result = self.run_harness("--list", "-ext-")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["-ext-/test_bug.rb"])

    def test_bad_or_empty_selection_fails_before_running(self):
        for args in [("missing.rb",), ("--all", "ruby"), ("../test.rb",)]:
            with self.subTest(args=args):
                self.assertEqual(self.run_harness(*args).returncode, 2)
        (self.root / "src/test/empty").mkdir()
        self.assertEqual(self.run_harness("empty").returncode, 2)

    def test_pass_preloads_framework_and_keeps_both_logs(self):
        result = self.run_harness("ruby/test_ok.rb")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("MATCH 1, RED 0, BOTH 0, EXTRA 0", result.stdout)
        row = self.coverage()[0]
        self.assertEqual(row["ref_state"], "COMPLETE")
        self.assertEqual(row["mere_state"], "COMPLETE")
        self.assertEqual(row["ref_discovered_tests"], "1")
        self.assertTrue((self.root / "raw/ruby_test_ok.reference.out").exists())
        self.assertTrue((self.root / "raw/ruby_test_ok.out").exists())
        self.assertFalse((self.root / "unittest/STATUS.md").exists())

    def test_zero_on_both_sides_is_not_a_successful_measurement(self):
        for side in ["reference", "mere-ruby"]:
            self.transcript(side, "0 tests, 0 assertions, 0 failures, 0 errors, 0 skips\n")
        result = self.run_harness("ruby/test_ok.rb")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.coverage()[0]["ref_state"], "ZERO")
        self.assertEqual(self.coverage()[0]["mere_state"], "ZERO")

    def test_warning_during_verbose_name_does_not_change_test_identity(self):
        (self.root / "reference.interleave").touch()
        result = self.run_harness("ruby/test_ok.rb")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("MATCH 1, RED 0, BOTH 0, EXTRA 0", result.stdout)
        self.assertIn("test warning", (self.root / "raw/ruby_test_ok.reference.out").read_text())

    def test_reference_load_error_remains_visible_even_if_neither_names_tests(self):
        for side in ["reference", "mere-ruby"]:
            self.transcript(side, "LoadError: missing extension\n", 1)
        result = self.run_harness("ruby/test_ok.rb")
        self.assertEqual(result.returncode, 1)
        row = self.coverage()[0]
        self.assertEqual(row["ref_state"], "INCOMPLETE")
        self.assertEqual(row["ref_exit"], "1")
        self.assertEqual(row["ref_summary_tests"], "-")

    def test_abort_after_last_progress_line_is_red(self):
        self.transcript("mere-ruby", "[ 1/1] Example#test_ok = 0.00 s\n", 137)
        result = self.run_harness("ruby/test_ok.rb")
        self.assertEqual(result.returncode, 1)
        self.assertIn("MATCH 0, RED 1", result.stdout)
        self.assertEqual(self.coverage()[0]["mere_exit"], "137")
        self.assertEqual(self.coverage()[0]["mere_state"], "INCOMPLETE")

    def test_absent_mere_test_is_red_and_zero_is_visible(self):
        self.transcript("mere-ruby", "0 tests, 0 assertions, 0 failures, 0 errors, 0 skips\n")
        result = self.run_harness("ruby/test_ok.rb")
        self.assertEqual(result.returncode, 1)
        self.assertIn("MATCH 0, RED 1", result.stdout)
        self.assertIn("ABSENT", (self.root / "records/tags/ruby_test_ok.txt").read_text())

    def test_summary_count_mismatch_is_not_complete(self):
        self.transcript("mere-ruby", self.passing().replace("1 tests,", "2 tests,"))
        self.assertEqual(self.run_harness("ruby/test_ok.rb").returncode, 1)
        self.assertEqual(self.coverage()[0]["mere_state"], "COUNT_MISMATCH")

    def test_crash_after_summary_is_recorded(self):
        self.transcript("mere-ruby", self.passing(), 139)
        self.assertEqual(self.run_harness("ruby/test_ok.rb").returncode, 1)
        self.assertEqual(self.coverage()[0]["mere_state"], "EXIT_ERROR")

    def test_failure_count_above_one_is_a_normal_runner_exit(self):
        failure = ("[1/2] Example#test_one = 0.00 s\n[2/2] Example#test_two = 0.00 s\n"
                   "  1) Failure:\nExample#test_one [test_ok.rb:1]:\nfailed\n"
                   "  2) Failure:\nExample#test_two [test_ok.rb:2]:\nfailed\n"
                   "2 tests, 2 assertions, 2 failures, 0 errors, 0 skips\n")
        self.transcript("mere-ruby", failure, 2)
        result = self.run_harness("ruby/test_ok.rb")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.coverage()[0]["mere_state"], "COMPLETE")

    def test_reported_test_timeout_is_red(self):
        timeout = ("[1/1] Example#test_ok = 0.00 s\n  1) Timeout:\n"
                   "Example#test_ok\n"
                   "1 tests, 0 assertions, 0 failures, 1 errors, 0 skips\n")
        self.transcript("mere-ruby", timeout, 1)
        result = self.run_harness("ruby/test_ok.rb")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("MATCH 0, RED 1", result.stdout)

    def test_completed_failure_preserves_extra_and_both(self):
        failure = ("[ 1/1] Example#test_ok = 0.00 s\n  1) Failure:\n"
                   "Example#test_ok [test_ok.rb:1]:\nfailed\n"
                   "1 tests, 1 assertions, 1 failures, 0 errors, 0 skips\n")
        self.transcript("reference", failure, 1)
        result = self.run_harness("ruby/test_ok.rb")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("MATCH 0, RED 0, BOTH 0, EXTRA 1", result.stdout)
        self.transcript("mere-ruby", failure, 1)
        self.assertIn("MATCH 0, RED 0, BOTH 1, EXTRA 0",
                      self.run_harness("ruby/test_ok.rb").stdout)


if __name__ == "__main__":
    unittest.main()
