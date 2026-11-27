#!/usr/bin/env python3
"""Check timing semantics, API snapshots and integration-report routing."""
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import ci_timing as timing

ROOT = Path(__file__).resolve().parents[1]
OBSERVED = datetime(2026, 11, 18, 9, 10, tzinfo=timezone.utc)


def run():
    return dict(id=42, run_attempt=1, html_url='https://github.com/owner/repo/actions/runs/42',
                head_sha='a' * 40, event='pull_request', head_branch='integration',
                status='in_progress', conclusion=None, created_at='2026-11-18T04:47:27Z')


def job(**changes):
    result = dict(id=10, name='basic-measurement', status='completed', conclusion='success',
                  created_at='2026-11-18T05:57:30Z', started_at='2026-11-18T09:01:37Z',
                  completed_at='2026-11-18T09:02:21Z', runner_name='hosted', runner_id=123, steps=[])
    result.update(changes)
    return result


class TimingCheck(unittest.TestCase):
    def test_real_basic_job_wait_and_execution_are_separate(self):
        row = timing.job_timing(job(), OBSERVED)
        self.assertEqual(row['start_delay_seconds'], 11047)
        self.assertEqual(row['execution_seconds'], 44)
        report = timing.summarize(run(), [job()], OBSERVED)
        self.assertEqual(report['jobs'][0]['created_after_run_seconds'], 4203)

    def test_queued_placeholder_start_is_not_execution(self):
        row = timing.job_timing(job(status='queued', conclusion=None, started_at='2026-11-18T05:57:30Z',
                                    completed_at=None, runner_name='', runner_id=0), OBSERVED)
        self.assertFalse(row['execution_started'])
        self.assertIsNone(row['execution_seconds'])
        self.assertEqual(row['start_delay_seconds'], 11550)

    def test_cancelled_before_runner_does_not_invent_runtime(self):
        row = timing.job_timing(job(conclusion='cancelled', started_at='2026-11-18T05:57:30Z',
                                    runner_name='', runner_id=0), OBSERVED)
        self.assertIsNone(row['execution_seconds'])
        self.assertEqual(row['start_delay_seconds'], 11091)

    def test_cancelled_before_job_record_keeps_raw_times_and_unknown_wait(self):
        # PR309, run45728827971: cancellation materialized dependent jobs
        # one second after their recorded workflow cancellation time.
        cancelled = job(id=139607831066, name='corpus', conclusion='cancelled',
                        created_at='2026-11-26T00:33:11Z',
                        started_at='2026-11-26T00:33:11Z',
                        completed_at='2026-11-26T00:33:10Z',
                        runner_name='', runner_id=0)
        metadata = run(); metadata['created_at'] = '2026-11-26T00:27:09Z'
        report = timing.summarize(metadata, [cancelled],
                                  datetime(2026, 11, 26, 0, 34, tzinfo=timezone.utc))
        row = report['jobs'][0]
        for key in ('created_at', 'started_at', 'completed_at'):
            self.assertEqual(row[key], cancelled[key])
        self.assertFalse(row['execution_started'])
        self.assertIsNone(row['execution_seconds'])
        self.assertIsNone(row['start_delay_seconds'])
        self.assertEqual(row['start_delay_unavailable_reason'],
                         'cancellation_precedes_job_record')
        self.assertEqual(report['unknown_start_delay_jobs'], 1)
        self.assertEqual(report['sum_start_delay_seconds'], 0)
        self.assertEqual(report['sum_execution_seconds'], 0)
        self.assertTrue(report['measured_jobs_complete'])
        self.assertFalse(report['measured_jobs_successful'])
        self.assertIn('cancelled', timing.markdown(report))

    def test_cancelled_started_execution_still_rejects_inverted_times(self):
        with self.assertRaisesRegex(ValueError, 'out of order'):
            timing.job_timing(job(conclusion='cancelled',
                                  completed_at='2026-11-18T05:57:29Z'), OBSERVED)

    def test_non_cancelled_unstarted_job_still_rejects_inverted_times(self):
        with self.assertRaisesRegex(ValueError, 'out of order'):
            timing.job_timing(job(conclusion='failure', runner_name='', runner_id=0,
                                  completed_at='2026-11-18T05:57:29Z'), OBSERVED)

    def test_skipped_job_and_steps_have_no_execution(self):
        row = timing.job_timing(job(conclusion='skipped', runner_name='', runner_id=0,
                                    steps=[dict(name='step', status='completed', conclusion='skipped',
                                                started_at='2026-11-18T05:57:30Z',
                                                completed_at='2026-11-18T09:02:21Z')]), OBSERVED)
        self.assertIsNone(row['start_delay_seconds'])
        self.assertIsNone(row['steps'][0]['seconds'])

    def test_a_skipped_job_leaves_the_report_complete_and_successful(self):
        # unittest-vm runs on a schedule and on dispatch only: a push's run skips it.
        skipped = job(id=11, name='unittest-vm', conclusion='skipped', started_at='2026-11-18T05:57:30Z',
                      completed_at='2026-11-18T05:57:30Z', runner_name='', runner_id=0)
        report = timing.summarize(run(), [job(), skipped], OBSERVED)
        self.assertTrue(report['measured_jobs_complete'])
        self.assertTrue(report['measured_jobs_successful'])
        self.assertEqual(report['unknown_start_delay_jobs'], 0)
        self.assertEqual(report['sum_execution_seconds'], 44)

    def test_running_and_cancelled_after_start_keep_elapsed_runtime(self):
        running = timing.job_timing(job(status='in_progress', conclusion=None, completed_at=None), OBSERVED)
        self.assertEqual(running['execution_seconds'], 503)
        self.assertFalse(running['execution_complete'])
        cancelled = timing.job_timing(job(conclusion='cancelled'), OBSERVED)
        self.assertEqual(cancelled['execution_seconds'], 44)

    def test_reporter_is_excluded_and_partial_or_failed_work_is_not_success(self):
        reporter = job(id=99, name=timing.REPORT_JOB, status='in_progress', completed_at=None)
        full = timing.summarize(run(), [job(), reporter], OBSERVED, 'b' * 40, 'c' * 40)
        self.assertTrue(full['measured_jobs_complete'])
        self.assertEqual(len(full['jobs']), 1)
        self.assertEqual(full['checkout_sha'], 'b' * 40)
        failed = timing.summarize(run(), [job(conclusion='failure')], OBSERVED)
        self.assertFalse(failed['measured_jobs_successful'])
        partial = timing.summarize(run(), [job(status='queued', conclusion=None)], OBSERVED)
        self.assertFalse(partial['measured_jobs_complete'])
        self.assertIn('queued', timing.markdown(partial))

    def test_overlapping_jobs_are_not_summed_into_workflow_span(self):
        report = timing.summarize(run(), [job(), job(id=11)], OBSERVED)
        self.assertEqual(report['sum_execution_seconds'], 88)
        self.assertEqual(report['measured_work_span_seconds'], 15294)

    def test_missing_creation_time_stays_unknown_and_bad_timestamps_fail(self):
        report = timing.summarize(run(), [job(created_at=None)], OBSERVED)
        self.assertIsNone(report['jobs'][0]['start_delay_seconds'])
        self.assertEqual(report['unknown_start_delay_jobs'], 1)
        with self.assertRaises(ValueError):
            timing.job_timing(job(started_at='2026-11-18T05:00:00Z'), OBSERVED)

    def test_real_carried_forward_rerun_keeps_execution_with_unknown_wait(self):
        # Run 44239745755, attempt 3: GitHub retained this completed execution
        # while assigning its record a timestamp from the later rerun.
        copied = job(id=135178318416, name='unittest-harness', run_attempt=3,
                     created_at='2026-11-18T22:21:59Z',
                     started_at='2026-11-18T04:47:30Z',
                     completed_at='2026-11-18T04:48:12Z')
        metadata = run(); metadata['run_attempt'] = 3
        report = timing.summarize(metadata, [copied], OBSERVED)
        row = report['jobs'][0]
        self.assertEqual(row['run_attempt'], 3)
        self.assertEqual(row['created_at'], copied['created_at'])
        self.assertEqual(row['started_at'], copied['started_at'])
        self.assertIsNone(row['start_delay_seconds'])
        self.assertEqual(row['start_delay_unavailable_reason'],
                         'execution_precedes_rerun_record')
        self.assertEqual(row['execution_seconds'], 42)
        self.assertEqual(report['unknown_start_delay_jobs'], 1)
        self.assertEqual(report['sum_start_delay_seconds'], 0)
        self.assertTrue(report['measured_jobs_successful'])
        self.assertIn('Carried-forward executions', timing.markdown(report))

    def test_rerun_does_not_hide_other_invalid_timestamps(self):
        for changes in (
            dict(started_at='2026-11-18T05:00:00Z'),
            dict(started_at='2026-11-18T05:00:00Z', completed_at='2026-11-18T04:59:59Z'),
        ):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                timing.job_timing(job(run_attempt=3, **changes), OBSERVED)

    def test_duplicate_jobs_and_mixed_attempts_are_rejected(self):
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            timing.summarize(run(), [job(), job()], OBSERVED)
        with self.assertRaisesRegex(ValueError, 'attempt'):
            timing.summarize(run(), [job(run_attempt=2)], OBSERVED)

    def test_pagination_is_attempt_scoped_and_every_row_is_retained(self):
        calls = []
        def api(path):
            calls.append(path)
            if path.endswith('/42'):
                return run()
            return dict(total_count=2, jobs=[job(id=1 if 'page=1' == path.split('&')[-1] else 2)])
        with patch.object(timing, 'api', side_effect=api):
            _, jobs, report = timing.snapshot('owner/repo', 42)
        self.assertEqual([j['id'] for j in jobs], [1, 2])
        self.assertEqual(len(report['jobs']), 2)
        self.assertTrue(all('/attempts/1/jobs?' in p for p in calls[1:]))

    def test_incomplete_pagination_fails(self):
        with patch.object(timing, 'api', side_effect=[run(), dict(total_count=1, jobs=[])]), \
                self.assertRaisesRegex(ValueError, 'pagination'):
            timing.snapshot('owner/repo', 42)

    def test_explicit_attempt_does_not_follow_a_later_rerun(self):
        calls = []
        def api(path):
            calls.append(path)
            if path.endswith('/attempts/1'):
                return run()
            return dict(total_count=1, jobs=[job()])
        with patch.object(timing, 'api', side_effect=api):
            _, _, report = timing.snapshot('owner/repo', 42, attempt=1)
        self.assertTrue(calls[0].endswith('/42/attempts/1'))
        self.assertEqual(report['run_attempt'], 1)
        self.assertTrue(all('/attempts/1' in p for p in calls))

    def test_report_writes_raw_inputs_and_incomplete_baseline(self):
        with tempfile.TemporaryDirectory() as directory:
            args = SimpleNamespace(repository='owner/repo', run_id=42, baseline_run_id=41,
                                   checkout_sha='b' * 40, mere_ref='c' * 40,
                                   output=Path(directory), step_summary=None)
            def snapshot(repo, rid, checkout, mere):
                metadata = run(); metadata['id'] = rid
                rows = [job(status='queued', conclusion=None)] if rid == 41 else [job()]
                return metadata, rows, timing.summarize(metadata, rows, OBSERVED, checkout, mere)
            with patch.object(timing, 'snapshot', side_effect=snapshot), patch('builtins.print'):
                timing.collect(args)
            baseline = json.loads((args.output / 'baseline/summary.json').read_text())
            self.assertFalse(baseline['measured_jobs_complete'])
            self.assertTrue((args.output / 'current/jobs.json').is_file())
            self.assertIn('incomplete or failed baseline', (args.output / 'summary.md').read_text())

    def test_report_waits_for_all_work_and_keeps_read_only_permissions(self):
        workflow = json.loads(subprocess.check_output(
            ['ruby', '-ryaml', '-rjson', '-e', 'puts JSON.generate(YAML.load_file(ARGV[0]))',
             str(ROOT / '.github/workflows/ci.yml')], text=True))
        jobs = workflow['jobs']
        report = jobs['ci-timing']
        self.assertEqual(set(report['needs']), set(jobs) - {'ci-timing'})
        self.assertEqual(report['if'], 'always()')
        self.assertEqual(report['permissions'], {'actions': 'read', 'contents': 'read'})
        self.assertEqual(report['runs-on'], 'ubuntu-24.04')
        self.assertFalse(report.get('continue-on-error'))
        self.assertTrue(any(s.get('if') == 'always()' and s.get('uses') == 'actions/upload-artifact@v4'
                            for s in report['steps']))

    def test_failed_snapshot_leaves_an_error_artifact_and_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            args = SimpleNamespace(repository='owner/repo', run_id=42, baseline_run_id=None,
                                   checkout_sha=None, mere_ref=None, output=Path(directory), step_summary=None)
            with patch.object(timing, 'snapshot', side_effect=ValueError('bad input')), \
                    self.assertRaises(ValueError):
                timing.collect(args)
            self.assertEqual(json.loads((args.output / 'current/error.json').read_text())['message'], 'bad input')


if __name__ == '__main__':
    unittest.main()
