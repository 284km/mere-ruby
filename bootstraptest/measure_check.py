"""Check native assertion coverage and fail-closed interrupted measurements."""
import json
import contextlib
import io
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from types import SimpleNamespace

import measure


class MeasurementCheck(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='bootstrap-check-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.ledger = self.root / 'cases.jsonl'

    def write(self, events):
        self.ledger.write_text(''.join(json.dumps(event) + '\n' for event in events))

    def discovered(self):
        return dict(event='discover', id=1, file='test_case.rb', line=1,
                    source_sha256='a' * 64, kind='assert_equal')

    def execution(self, exit=0, limit=None):
        return dict(exit=exit, limit=limit)

    def test_progress_without_final_never_passes(self):
        self.write([self.discovered(), dict(event='start', id=1), dict(event='finish', id=1, status='PASS')])
        summary, cases = measure.parse_cases(self.ledger, self.execution())
        self.assertEqual(summary['state'], 'INCOMPLETE')
        self.assertEqual(list(cases.values()), ['X'])
        self.assertEqual(measure.compare(cases, cases)['match'], 0)

    def test_resource_limit_never_promotes_a_finished_assertion(self):
        self.write([self.discovered(), dict(event='start', id=1), dict(event='finish', id=1, status='PASS'),
                    dict(event='final', normal_exit=True, exit=0, discovered=1)])
        summary, cases = measure.parse_cases(self.ledger, self.execution(limit='MEMORY_LIMIT'))
        self.assertEqual(summary['state'], 'MEMORY_LIMIT')
        self.assertEqual(list(cases.values()), ['X'])

    def test_malformed_or_duplicate_completion_is_incomplete(self):
        base = [self.discovered(), dict(event='start', id=1), dict(event='finish', id=1, status='PASS')]
        for tail in [[dict(event='finish', id=1, status='PASS')], [dict(event='final', normal_exit=True, exit=0, discovered=2)]]:
            with self.subTest(tail=tail):
                self.write(base + tail)
                self.assertEqual(measure.parse_cases(self.ledger, self.execution())[0]['state'], 'INCOMPLETE')
        self.write(base)
        with self.ledger.open('a') as stream:
            stream.write('{"event":')
        self.assertEqual(measure.parse_cases(self.ledger, self.execution())[0]['state'], 'INCOMPLETE')

    def test_nonzero_empty_source_is_not_zero_success(self):
        self.write([dict(event='final', normal_exit=True, exit=1, discovered=0)])
        self.assertEqual(measure.parse_cases(self.ledger, self.execution(exit=1))[0]['state'], 'INCOMPLETE')

    def test_knownbugs_zero_requires_a_comment_only_input(self):
        file = self.root / 'KNOWNBUGS.rb'
        file.write_text('# known bug sentinel\n\n')
        self.assertEqual(measure.empty_inputs(self.root), ['KNOWNBUGS.rb'])
        file.write_text("if false\n  assert_equal '1', '1'\nend\n")
        self.assertEqual(measure.empty_inputs(self.root), [])

    def test_empty_knownbugs_does_not_count_as_a_passing_case(self):
        args = self.collection([(0, 'same'), (1, 'same')])
        manifest = json.loads(args.plan.read_text())
        manifest['files'][0] = 'KNOWNBUGS.rb'
        manifest['empty_inputs'] = ['KNOWNBUGS.rb']
        args.plan.write_text(json.dumps(manifest))
        for index in range(2):
            path = args.input / str(index) / 'result.json'
            value = json.loads(path.read_text())
            value['manifest'] = manifest
            if index == 0:
                value['rows'][0].update(file='KNOWNBUGS.rb', reference=dict(state='ZERO'), mere=dict(state='ZERO'),
                                        counts=dict(tests=0, match=0, red=0, both=0, extra=0))
            path.write_text(json.dumps(value))
        with contextlib.redirect_stdout(io.StringIO()):
            measure.merge(args)
        report = json.loads((args.output / 'summary.json').read_text())
        self.assertEqual(report['reference_gaps'], [])
        self.assertEqual(report['totals']['tests'], 1)
        self.assertEqual(report['reference_states'], dict(ZERO=1, COMPLETE=1))

    def collection(self, shards):
        manifest = dict(files=['bootstraptest/test_a.rb', 'bootstraptest/test_b.rb'], shards=2)
        plan = self.root / 'plan.json'; plan.write_text(json.dumps(manifest))
        directory = self.root / 'artifacts'; directory.mkdir(exist_ok=True)
        for index, (shard, stamp) in enumerate(shards):
            target = directory / str(index); target.mkdir(exist_ok=True)
            row = dict(file=manifest['files'][shard], reference=dict(state='COMPLETE'), mere=dict(state='COMPLETE'),
                       counts=dict(tests=1, match=1, red=0, both=0, extra=0))
            result = dict(schema=1, policy=measure.POLICY, manifest=manifest, shard=shard,
                          infrastructure_error=None, build=dict(binary_sha256=stamp), reference={}, harness={},
                          wall_seconds=600, rss_kb=2097152, rows=[row])
            (target / 'result.json').write_text(json.dumps(result))
        return SimpleNamespace(plan=plan, input=directory, output=self.root / 'report')

    def test_collection_preserves_missing_files_and_requires_all_shards(self):
        args = self.collection([(0, 'same')])
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as stopped:
            measure.merge(args)
        self.assertEqual(stopped.exception.code, 1)
        report = json.loads((args.output / 'summary.json').read_text())
        self.assertEqual(report['missing_files'], ['bootstraptest/test_b.rb'])
        self.assertEqual(report['received_shards'], [0])

    def test_collection_rejects_changed_provenance_and_duplicate_shards(self):
        args = self.collection([(0, 'first'), (1, 'second')])
        with self.assertRaisesRegex(ValueError, 'provenance'):
            measure.merge(args)
        path = args.input / '1/result.json'
        value = json.loads(path.read_text()); value['shard'] = 0
        path.write_text(json.dumps(value))
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            measure.merge(args)

    def native(self, source):
        ruby = os.environ.get('UNITTEST_REAL_RUBY')
        runner = os.environ.get('UNITTEST_BOOTSTRAP_RUNNER')
        if not ruby or not runner:
            self.skipTest('set UNITTEST_REAL_RUBY and UNITTEST_BOOTSTRAP_RUNNER for upstream runner checks')
        fixture = self.root / 'test_forms.rb'
        fixture.write_text(source)
        skips = self.root / 'skips'; skips.mkdir(exist_ok=True)
        env = dict(os.environ, BOOTSTRAP_CASE_LOG=str(self.ledger), BOOTSTRAP_SKIP_DIR=str(skips))
        result = subprocess.run([ruby, str(measure.ROOT / 'bootstraptest/audit_runner.rb'), runner,
                                 '--ruby=' + ruby, '-j1', '--timeout=3', str(fixture)],
                                env=env, cwd=self.root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
        return result, measure.parse_cases(self.ledger, self.execution(exit=result.returncode))

    def test_native_runner_executes_every_assertion_form_and_records_skip(self):
        result, (summary, cases) = self.native("""assert_equal '3', '1+2'
assert_match /ok/, %q{'ok'}
assert_not_match /bad/, %q{'ok'}
assert_valid_syntax 'def ok; end'
assert_normal_exit 'exit 0'
assert_finish 2, '1+1'
assert_equal 'skipped', %q{skip 'skipped'}
""")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(summary['state'], 'COMPLETE')
        self.assertEqual(summary['discovered'], 7)
        self.assertEqual(summary['verdicts'], dict(PASS=6, SKIP=1))
        self.assertEqual(set(summary['kinds']), {'assert_equal', 'assert_match', 'assert_not_match', 'assert_valid_syntax', 'assert_normal_exit', 'assert_finish'})

    def test_native_failure_is_a_complete_nonpassing_case(self):
        result, (summary, cases) = self.native("assert_equal 'wrong', '1+2'\nassert_equal '3', '1+2'\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(summary['state'], 'COMPLETE')
        self.assertEqual(summary['verdicts'], dict(FAIL=1, PASS=1))

    def test_native_empty_source_is_reported_as_zero(self):
        result, (summary, cases) = self.native('# known bug sentinel\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(summary['state'], 'ZERO')
        self.assertEqual(cases, {})

    def test_native_source_load_failure_keeps_registered_cases_unpassed(self):
        result, (summary, cases) = self.native("assert_equal '3', '1+2'\nraise 'source registration failed'\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(summary['state'], 'INCOMPLETE')
        self.assertEqual(summary['discovered'], 1)
        self.assertEqual(list(cases.values()), ['X'])

    def test_repeated_assertions_on_one_line_remain_distinct(self):
        result, (summary, cases) = self.native("3.times { assert_equal '3', '1+2' }\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(summary['verdicts'], dict(PASS=3))
        self.assertEqual(len(cases), 3)
        self.assertEqual({key[-1] for key in cases}, {1, 2, 3})

    def test_generated_driver_pids_do_not_create_false_test_name_differences(self):
        source = "assert_equal 'true', %Q{#{Process.pid} > 0}\n"
        first, (summary, left) = self.native(source)
        left_digest = json.loads(self.ledger.read_text().splitlines()[0])['source_sha256']
        second, (summary, right) = self.native(source)
        right_digest = json.loads(self.ledger.read_text().splitlines()[0])['source_sha256']
        self.assertEqual((first.returncode, second.returncode), (0, 0))
        self.assertNotEqual(left_digest, right_digest)
        self.assertEqual(measure.compare(left, right), dict(tests=1, match=1, red=0, both=0, extra=0))


if __name__ == '__main__':
    unittest.main()
