"""Check basic accounting and preservation of the upstream runner's child output."""
import os
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

import measure
from ci_check import FixtureFamily


class BasicCheck(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='basic-check-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / 'source with spaces/basictest/test.rb'
        self.source.parent.mkdir(parents=True)
        self.output = self.root / 'stdout'

    def parse(self, text, exit=0, child=0, limit=None):
        self.output.write_text(text)
        return measure.parse_output(self.output, self.source, dict(exit=exit, limit=limit), child)

    def passing(self):
        return f"ok 1 ({self.source}:12:in '<main>')\n"

    def test_repeated_locations_remain_distinct(self):
        summary, cases = self.parse(self.passing() * 2 + 'end of test(test: 2)\n')
        self.assertEqual(summary['state'], 'COMPLETE')
        self.assertEqual(list(cases.values()), ['PASS', 'PASS'])
        self.assertEqual({key[-1] for key in cases}, {1, 2})

    def test_failure_is_complete_with_normal_body_exit_and_failed_host(self):
        summary, cases = self.parse(self.passing() + f"not ok float 2 -- {self.source}:18:in '<main>'\nnot ok/test: 2 failed 1\n", exit=1)
        self.assertEqual(summary['state'], 'COMPLETE')
        self.assertEqual(summary['verdicts'], dict(PASS=1, FAIL=1))
        self.assertEqual(measure.compare(cases, cases)['both'], 1)

    def test_missing_final_does_not_promote_progress(self):
        summary, cases = self.parse(self.passing(), exit=1, child=1)
        self.assertEqual(summary['state'], 'INCOMPLETE')
        self.assertEqual(list(cases.values()), ['X'])

    def test_limits_and_crash_after_summary_never_pass(self):
        text = self.passing() + 'end of test(test: 1)\n'
        for kwargs in [dict(limit='MEMORY_LIMIT'), dict(child=139), dict(exit=1), dict(child=None)]:
            with self.subTest(kwargs=kwargs):
                summary, cases = self.parse(text, **kwargs)
                self.assertNotEqual(summary['state'], 'COMPLETE')
                self.assertEqual(list(cases.values()), ['X'])

    def test_bad_case_count_duplicate_summary_and_trailing_output_fail_closed(self):
        for tail in ['end of test(test: 2)\n', 'end of test(test: 1)\nend of test(test: 1)\n',
                     'end of test(test: 1)\n' + self.passing(), 'end of test(test: 1)\nextra output\n']:
            with self.subTest(tail=tail):
                summary, cases = self.parse(self.passing() + tail)
                self.assertEqual(summary['state'], 'INCOMPLETE')
                self.assertEqual(list(cases.values()), ['X'])

    def test_unrecognized_location_and_empty_body_are_visible(self):
        summary, cases = self.parse("ok 1 (unknown.rb:12)\nend of test(test: 1)\n")
        self.assertEqual(summary['state'], 'INCOMPLETE')
        self.assertTrue(summary['issues'])
        summary, cases = self.parse('end of test(test: 0)\n')
        self.assertEqual(summary['state'], 'ZERO')

    def test_native_host_output_is_captured_even_when_runner_discards_it(self):
        ruby = os.environ.get('UNITTEST_REAL_RUBY')
        runner = os.environ.get('UNITTEST_BASIC_RUNNER')
        if not ruby or not runner:
            self.skipTest('set UNITTEST_REAL_RUBY and UNITTEST_BASIC_RUNNER')
        shutil.copyfile(runner, self.source.parent / 'runner.rb')
        for failed in [False, True]:
            with self.subTest(failed=failed):
                expected_source = self.root / str(failed) / 'source/basictest/test.rb'
                line = f"not ok fixture 1 -- {expected_source}:12:in '<main>'" if failed else f"ok 1 ({expected_source}:12:in '<main>')"
                final = 'not ok/test: 1 failed 1' if failed else 'end of test(test: 1)'
                # Inspect ./miniruby too: the host and the body's CLI children
                # must use the requested target, including paths with spaces.
                self.source.write_text('abort "missing miniruby" unless File.executable?("./miniruby")\nputs ' + json.dumps(line) + '\nputs ' + json.dumps(final) + '\n')
                env = dict(PATH=os.environ['PATH'], HOME=str(self.root), LANG='C', LC_ALL='C', RUBYOPT='-Eutf-8')
                with patch.object(measure.ci, 'ProcessFamily', FixtureFamily):
                    summary, cases = measure.run_side(self.source.parent.parent, Path(ruby).resolve(), Path(ruby).resolve(),
                                                       self.root / str(failed), env, 10, 2097152, self.root / ('result-' + str(failed)))
                self.assertEqual(summary['state'], 'COMPLETE', summary)
                self.assertEqual(list(cases.values()), ['FAIL' if failed else 'PASS'])


if __name__ == '__main__':
    unittest.main()
