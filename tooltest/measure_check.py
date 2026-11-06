"""Check durable tool accounting and the upstream runner's selected child Ruby."""
import contextlib
import copy
import io
import os
from pathlib import Path
import shlex
import shutil
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import measure
from ci_check import FixtureFamily


class ToolCheck(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='tool-check-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.files = ['tool/test/test_a.rb', 'tool/test/test_b.rb']

    def snapshot(self, passed=True):
        result = measure.unrun()
        result.update(state='COMPLETE', exit=0 if passed else 1, discovered=1,
                      summary=dict(tests=1, assertions=1, failures=0 if passed else 1, errors=0, skips=0),
                      cases={'Fixture#test_one': '.' if passed else 'F'})
        return result

    def report(self, shard, reference=None, mere=None):
        row = measure.empty_row(self.files[shard])
        row.update(reference=reference or self.snapshot(), mere=mere or self.snapshot())
        row['counts'], _ = measure.transcript.compare(row['reference'], row['mere'])
        report = dict.fromkeys(['schema', 'policy', 'case_policy', 'environment_policy',
                               'manifest', 'build', 'reference', 'inputs', 'wall_seconds', 'rss_kb', 'harness'])
        report.update(schema=1, policy=measure.POLICY, files=self.files, shards=2,
                      shard=shard, rows=[row], completed=True, infrastructure_error=None)
        measure.ci.save(self.root / 'shards' / str(shard) / 'result.json', report)
        return report

    def collect(self):
        with contextlib.redirect_stdout(io.StringIO()):
            measure.collect(SimpleNamespace(input=self.root / 'shards', output=self.root / 'report'))
        return measure.ci.load(self.root / 'report/summary.json')

    def test_full_collection_keeps_real_case_verdicts(self):
        self.report(0)
        self.report(1, mere=self.snapshot(False))
        summary = self.collect()
        self.assertEqual(summary['totals'], dict(tests=2, match=1, red=1, both=0, extra=0))
        self.assertEqual(summary['missing_shards'], [])

    def test_missing_shard_keeps_every_planned_file_and_fails(self):
        self.report(0)
        with self.assertRaises(SystemExit):
            self.collect()
        summary = measure.ci.load(self.root / 'report/summary.json')
        self.assertEqual([row['file'] for row in summary['rows']], self.files)
        self.assertEqual(summary['missing_shards'], [1])
        self.assertEqual(summary['rows'][1]['reference']['state'], 'NOT_RUN')

    def test_interrupted_mere_side_preserves_reference_cases(self):
        self.report(0, mere=measure.unrun())
        self.report(1)
        with self.assertRaises(SystemExit):
            self.collect()
        summary = measure.ci.load(self.root / 'report/summary.json')
        self.assertEqual(summary['totals']['red'], 1)
        self.assertEqual(summary['totals']['match'], 1)

    def test_infrastructure_error_keeps_partial_results_and_fails(self):
        report = self.report(0, mere=measure.unrun())
        report['infrastructure_error'] = 'KeyboardInterrupt'
        measure.ci.save(self.root / 'shards/0/result.json', report)
        self.report(1)
        with self.assertRaises(SystemExit):
            self.collect()
        summary = measure.ci.load(self.root / 'report/summary.json')
        self.assertEqual(summary['totals']['red'], 1)
        self.assertTrue(summary['infrastructure_errors'])

    def test_wrong_build_and_changed_case_counts_are_rejected(self):
        self.report(0)
        original = self.report(1)
        for key, value in [('build', {'binary_sha256': 'changed'}), ('rows', [])]:
            changed = copy.deepcopy(original)
            changed[key] = value
            measure.ci.save(self.root / 'shards/1/result.json', changed)
            with self.assertRaises(ValueError):
                self.collect()
        changed = copy.deepcopy(original)
        changed['rows'][0]['counts']['match'] += 1
        measure.ci.save(self.root / 'shards/1/result.json', changed)
        with self.assertRaises(ValueError):
            self.collect()

    def test_original_runner_uses_selected_interpreter_for_cli_children(self):
        ruby, runner = os.environ.get('UNITTEST_REAL_RUBY'), os.environ.get('UNITTEST_TOOL_RUNNER')
        if not ruby or not runner:
            self.skipTest('set UNITTEST_REAL_RUBY and UNITTEST_TOOL_RUNNER')
        runner = Path(runner)
        source = self.root / 'source with spaces'
        (source / 'tool/test').mkdir(parents=True)
        (source / 'tool/lib').symlink_to(runner.parents[1] / 'lib', target_is_directory=True)
        (source / 'test').symlink_to(runner.parents[2] / 'test', target_is_directory=True)
        shutil.copyfile(runner, source / 'tool/test/runner.rb')
        shutil.copyfile(runner.with_name('init.rb'), source / 'tool/test/init.rb')
        body = source / 'tool/test/test_selected.rb'
        body.write_text("require 'test/unit'\nclass SelectedTool < Test::Unit::TestCase\n"
                        "  def test_child\n"
                        "    selected = ENV.fetch('UNITTEST_CHILD_RUBY')\n"
                        "    out = IO.popen([*@__runner_options__[:ruby], '-e', "
                        "'print ENV.fetch(\"UNITTEST_CHILD_RUBY\")'], &:read)\n"
                        "    assert_equal(selected, out)\n"
                        "  end\nend\n")
        calls = self.root / 'calls'
        subject = self.root / 'selected ruby with spaces'
        subject.write_text('#!/bin/sh\nprintf "call\\n" >> ' + shlex.quote(str(calls)) +
                           '\nexec ' + shlex.quote(str(Path(ruby).resolve())) + ' "$@"\n')
        subject.chmod(0o755)
        with patch.dict(os.environ, REF_RUBY_BIN=str(subject)), patch.object(measure.ci, 'ProcessFamily', FixtureFamily):
            parsed, stdout, stderr = measure.run_side(source, subject, subject, self.root / 'work',
                                            dict(file='tool/test/test_selected.rb'), '4.0.9', 20, 2097152)
        self.assertEqual(parsed['state'], 'COMPLETE', parsed)
        self.assertEqual(parsed['cases'], {'SelectedTool#test_child': '.'}, stdout.read_text() + stderr.read_text())
        self.assertGreaterEqual(len(calls.read_text().splitlines()), 2)

    def test_monitor_failure_persists_discovered_cases_without_a_pass(self):
        source = self.root / 'source'
        subject = self.root / 'ruby'
        observed = []

        def interrupted(command, env, log, rss, wall):
            (self.root / 'work/stdout').write_text('[1/1] Fixture#test_one =\n')
            raise KeyboardInterrupt()

        with patch.dict(os.environ, REF_RUBY_BIN=str(subject)), patch.object(measure.ci, 'supervise', interrupted):
            with self.assertRaises(KeyboardInterrupt):
                measure.run_side(source, subject, subject, self.root / 'work',
                                 dict(file='tool/test/test_one.rb'), '4.0.9', 1, 1024,
                                 lambda parsed, *_: observed.append(parsed))
        self.assertEqual(observed[0]['state'], 'INCOMPLETE')
        self.assertEqual(observed[0]['cases'], {'Fixture#test_one': 'X'})


if __name__ == '__main__':
    unittest.main()
