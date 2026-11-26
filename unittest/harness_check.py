#!/usr/bin/env python3
"""Exercise discovery and accounting with controlled interpreter transcripts."""
import csv
import os
import shlex
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
        for script in ["run.sh", "list.sh", "transcript.py", "case_encodings.rb", "bootstrap.rb", "exclusions.py", "exclusions.rb"]:
            shutil.copyfile(ROOT / "unittest" / script, self.root / "unittest" / script)
        # (the real table names files this fixture tree does not have; a test
        #  that splits writes its own)
        (self.root / "unittest/splits.tsv").write_text("# fixture: no file is split\n")
        shutil.copytree(ROOT / 'unittest/child-bin', self.root / 'unittest/child-bin')
        shutil.copyfile(ROOT / "mspec/mask.sh", self.root / "mspec/mask.sh")
        shutil.copyfile(ROOT / 'tools/runtime_load_path.sh', self.root / 'tools/runtime_load_path.sh')
        (self.root / "unittest/files.txt").write_text("ruby\n-ruby/test_vm.rb\n")
        for name in ["test_ok.rb", "test_vm.rb", "test_helper.rb", "enc/test_encoding.rb"]:
            (self.root / "src/test/ruby" / name).write_text("# fixture\n")
        # No global RSS poller: these fake interpreters only print fixed text.
        (self.root / "mspec/rss_guard.sh").write_text("#!/bin/sh\nexit 0\n")
        (self.root / "bin/pgrep").write_text("#!/bin/sh\nexit 1\n")
        (self.root / "bin/pgrep").chmod(0o755)
        (self.root / "tools/ref_ruby.sh").write_text(
            'REF_RUBY_VERSION=fixture\nREF_RUBY_BIN=' + shlex.quote(str(self.root / "reference")) + '\n')
        interpreter = '''#!/bin/sh
case "$*" in *rubylibdir*) printf '/fixture/reference-stdlib'; exit 0 ;; esac
case "$*" in *'$LOAD_PATH.join'*) printf '/fixture/runtime-stdlib'; exit 0 ;; esac
case "$*" in *Gem.bin_path*) printf '\\n'; exit 0 ;; esac
printf '%s\n' "$@" > "$(cd "$(dirname "$0")" && pwd)/$(basename "$0").args"
preload=0
script=
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-r" ] && [ "${2:-}" = "test/unit" ]; then preload=1; fi
  case "$1" in *.rb) script="$1" ;; esac
  shift
done
[ "$preload" -eq 1 ] || { echo 'uninitialized constant Test (NameError)'; exit 1; }
[ -n "$script" ] && [ -f "$script" ] || { echo 'fixture script not found'; exit 1; }
side=$(basename "$0")
fixture_root=$(cd "$(dirname "$0")" && pwd)
if [ -n "${UNITTEST_EXCLUSIONS:-}" ] && [ -f "$fixture_root/$side.exclusions" ]; then
  cat "$fixture_root/$side.exclusions" >> "$UNITTEST_EXCLUSIONS"
fi
printf '%s' "$RUBYLIB" > "$fixture_root/$side.rubylib"
if [ -f "$fixture_root/$side.interleave" ]; then
  printf '[1/1] Example#test_ok'
  printf '/fixture/test.rb:1: warning: test warning\\n' >&2
  printf ' = 0.00 s\\n1 tests, 1 assertions, 0 failures, 0 errors, 0 skips\\n'
else
  cat "$fixture_root/$side.transcript"
fi
exit "$(cat "$fixture_root/$side.code")"
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

    def test_split_units_are_listed_and_run_with_their_filter(self):
        # A file split by unittest/splits.tsv is listed as one unit per part,
        # and each unit runs the file with its part's name filter on both
        # sides; logs, tags and the coverage row keep the part.
        (self.root / 'unittest/splits.tsv').write_text(
            '# fixture\nruby/test_vm.rb\t1\t/#test_a/\nruby/test_vm.rb\t2\t!/#test_a/\n')
        listed = self.run_harness('--list', '--all')
        self.assertEqual(listed.returncode, 0, listed.stderr)
        self.assertEqual(listed.stdout.splitlines(),
                         ['ruby/enc/test_encoding.rb', 'ruby/test_ok.rb', 'ruby/test_vm.rb@1', 'ruby/test_vm.rb@2'])
        work = self.root / 'work'
        work.mkdir()
        one = subprocess.run(['sh', str(self.root / 'unittest/run.sh'), str(self.root / 'src'), '--one',
                              str(work), '1', 'ruby/test_vm.rb@2'],
                             env=self.env, text=True, capture_output=True, timeout=15)
        self.assertEqual(one.returncode, 0, one.stderr)
        for side in ('reference', 'mere-ruby'):
            args = (self.root / (side + '.args')).read_text().splitlines()
            self.assertIn(str(self.root / 'src/test/ruby/test_vm.rb'), args)
            at = args.index('-n')
            self.assertEqual(args[at + 1], '!/#test_a/')
        self.assertEqual((work / '1.coverage').read_text().split('\t')[0], 'ruby/test_vm.rb@2')
        self.assertTrue((self.root / 'raw/ruby_test_vm@2.out').exists())
        self.assertTrue((self.root / 'raw/ruby_test_vm@2.reference.out').exists())
        # a malformed table is refused, not skipped
        for table in ('ruby/test_vm.rb\t1\t/#test_a/\n',
                      'ruby/test_vm.rb\t1\t/#test_a/\nruby/test_vm.rb\t2\t/#test_b/\n',
                      'ruby/test_vm.rb\t1\t!/#test_a/\nruby/test_vm.rb\t2\t!/#test_b/\n',
                      'ruby/test_vm.rb\t1\t/#test_a/\nruby/test_vm.rb\t3\t!/#test_a/\n',
                      'ruby/test_vm.rb\t1\n',
                      'ruby/test_gone.rb\t1\t/#test_a/\nruby/test_gone.rb\t2\t!/#test_a/\n'):
            with self.subTest(table=table):
                (self.root / 'unittest/splits.tsv').write_text(table)
                self.assertNotEqual(self.run_harness('--list', '--all').returncode, 0)
        (self.root / 'unittest/splits.tsv').write_text(
            'ruby/test_vm.rb\t1\t/#test_a/\nruby/test_vm.rb\t2\t!/#test_a/\n')
        # an unlisted part is refused rather than run unfiltered
        bad = subprocess.run(['sh', str(self.root / 'unittest/run.sh'), str(self.root / 'src'), '--one',
                              str(work), '2', 'ruby/test_vm.rb@9'],
                             env=self.env, text=True, capture_output=True, timeout=15)
        self.assertNotEqual(bad.returncode, 0)

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

    def test_audited_extra_bodies_follow_recursive_scope_without_duplicates(self):
        (self.root / 'src/test/rubygems').mkdir()
        (self.root / 'src/test/rubygems/bundler_test_gem.rb').write_text('# body\n')
        (self.root / 'unittest/extra_files.txt').write_text('rubygems/bundler_test_gem.rb\n')
        self.assertIn('rubygems/bundler_test_gem.rb', self.run_harness('--list', '--all').stdout.splitlines())
        result = self.run_harness('--list', 'rubygems', 'rubygems/bundler_test_gem.rb')
        self.assertEqual(result.stdout.splitlines(), ['rubygems/bundler_test_gem.rb'])
        self.assertNotIn('rubygems/bundler_test_gem.rb', self.run_harness('--list', 'ruby').stdout)
        self.assertNotIn('rubygems/bundler_test_gem.rb', self.run_harness('--list').stdout)
        (self.root / 'src/test/rubygems/bundler_test_gem.rb').unlink()
        self.assertEqual(self.run_harness('--list', '--all').returncode, 2)

    def test_extension_directory_with_leading_hyphen_reaches_the_test_file(self):
        (self.root / "src/test/-ext-").mkdir()
        (self.root / "src/test/-ext-/test_bug.rb").write_text("# fixture\n")
        result = self.run_harness("-ext-/test_bug.rb")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("MATCH 1, RED 0, BOTH 0, EXTRA 0", result.stdout)
        row = self.coverage()[0]
        self.assertEqual(row["ref_state"], "COMPLETE")
        self.assertEqual(row["mere_state"], "COMPLETE")

    def test_bad_or_empty_selection_fails_before_running(self):
        for args in [("missing.rb",), ("--all", "ruby"), ("../test.rb",)]:
            with self.subTest(args=args):
                self.assertEqual(self.run_harness(*args).returncode, 2)
        (self.root / "src/test/empty").mkdir()
        self.assertEqual(self.run_harness("empty").returncode, 2)

    def test_pass_preloads_framework_and_keeps_both_logs(self):
        result = self.run_harness("ruby/test_ok.rb")
        self.assertEqual(result.returncode, 0, result.stderr)
        libraries = (self.root / 'mere-ruby.rubylib').read_text().split(os.pathsep)
        self.assertLess(libraries.index('/fixture/runtime-stdlib'), libraries.index('/fixture/reference-stdlib'))
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

    def test_explicit_reference_binary_is_verified_and_preserved(self):
        binary = self.root / "custom-reference"
        binary.write_text("#!/bin/sh\nprintf fixture\n")
        binary.chmod(0o755)
        result = subprocess.run(["sh", "-c", '. "$1"; printf "%s" "$REF_RUBY_BIN"',
                                 "reference-check", str(ROOT / "tools/ref_ruby.sh")],
                                env=dict(self.env, REF_RUBY_BIN=str(binary), REF_RUBY_VERSION="fixture"),
                                text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, str(binary))

    def test_corpus_uses_selected_reference_and_both_index_modes(self):
        shutil.copyfile(ROOT / "run_corpus.sh", self.root / "run_corpus.sh")
        shutil.copyfile(ROOT / "tools/ref_ruby.sh", self.root / "tools/ref_ruby.sh")
        (self.root / "corpus").mkdir()
        (self.root / "corpus/01_arith.rb").write_text("# fixture\n")
        for name in ["gc_roots", "dup_defs", "dead_defs", "meth_writes",
                     "name_spec", "rx_caps", "ns_names", "name_len", "iv_door"]:
            stub = self.root / "tools" / (name + "_check.sh")
            stub.write_text("#!/bin/sh\nexit 0\n")
            stub.chmod(0o755)
        hygiene = self.root / "mspec/record_hygiene.sh"
        hygiene.write_text("#!/bin/sh\nexit 0\n")
        hygiene.chmod(0o755)
        # PATH's ruby must never run after the explicit binary is selected.
        wrong = self.root / "bin/ruby"
        wrong.write_text("#!/bin/sh\necho wrong-reference\nexit 99\n")
        wrong.chmod(0o755)
        reference = self.root / "selected reference"
        reference.write_text('''#!/bin/sh
if [ "$1" = "-e" ]; then printf fixture; exit 0; fi
printf 'reference\\n' >> "$FIXTURE_ROOT/corpus.calls"
printf 'answer\\n'
''')
        reference.chmod(0o755)
        (self.root / "mere-ruby").write_text('''#!/bin/sh
if [ "$MERE_RUBY_STORE_STATS" = 1 ]; then
  printf 'sh_cls_var 0\\nsh_cls_cap 0\\n' >&2
  exit 0
fi
[ "${MERE_RUBY_ERRNO_CHECK:-}" = 1 ] && exit 0
printf 'candidate:%s\\n' "${MERE_RUBY_NO_HASH_INDEX-unset}" >> "$FIXTURE_ROOT/corpus.calls"
printf 'answer\\n'
''')
        env = dict(self.env, REF_RUBY_BIN=str(reference), REF_RUBY_VERSION="fixture",
                   MERE_RUBY_NO_HASH_INDEX="1")
        cases = [(('--both',), ["reference", "candidate:unset", "candidate:1"]),
                 ((), ["reference", "candidate:1"])]
        for args, expected in cases:
            with self.subTest(args=args):
                calls = self.root / "corpus.calls"
                calls.write_text("")
                result = subprocess.run(["sh", "run_corpus.sh", *args], cwd=self.root,
                                        env=env, text=True, capture_output=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("1/1 corpus programs match ruby", result.stdout)
                self.assertEqual(calls.read_text().splitlines(), expected)

    def test_wrong_explicit_reference_version_is_refused(self):
        binary = self.root / "wrong-reference"
        binary.write_text("#!/bin/sh\nprintf wrong\n")
        binary.chmod(0o755)
        result = subprocess.run(["sh", "-c", '. "$1"', "reference-check", str(ROOT / "tools/ref_ruby.sh")],
                                env=dict(self.env, REF_RUBY_BIN=str(binary), REF_RUBY_VERSION="fixture"),
                                text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
