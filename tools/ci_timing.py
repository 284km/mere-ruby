#!/usr/bin/env python3
"""Snapshot GitHub Actions job start delays and execution wall times."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess

REPORT_JOB = 'CI timing report'


def instant(value):
    if not value:
        return None
    result = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if result.tzinfo is None:
        raise ValueError('timestamp has no timezone')
    return result


def seconds(start, end):
    if start is None or end is None:
        return None
    result = (end - start).total_seconds()
    if result < 0:
        raise ValueError('timestamps are out of order')
    return result


def job_timing(job, observed):
    status, conclusion = job['status'], job.get('conclusion')
    created = instant(job.get('created_at'))
    end = instant(job.get('completed_at'))
    # GitHub can put created_at into started_at on a QUEUED job. A cancelled
    # job without a runner/steps also has no evidence of execution.
    evidence = job.get('runner_id') or job.get('runner_name') or any(
        s.get('status') == 'in_progress' or s.get('conclusion') not in (None, 'skipped')
        for s in job.get('steps', []))
    started = (status == 'in_progress' or (status == 'completed' and evidence)) and conclusion != 'skipped'
    start = instant(job.get('started_at')) if started else None
    execution_end = end if status == 'completed' else observed
    wait_end = start or (end if status == 'completed' else observed)
    # Reruns can carry a completed execution forward under a newly created
    # job record. Its original start/end remain useful, but that record has
    # no observable queue interval. Require an actual later attempt and a
    # wholly earlier completed execution; other inverted timestamps still fail.
    copied_execution = bool(job.get('run_attempt', 1) > 1 and status == 'completed'
                            and created and start and end and start <= end < created)
    delay_reason = ('execution_precedes_rerun_record' if copied_execution else
                    'missing_creation_time' if created is None else None)
    start_delay = (None if conclusion == 'skipped' or copied_execution
                   else seconds(created, wait_end))
    steps = []
    for step in job.get('steps', []):
        step_start = instant(step.get('started_at')) if start and step.get('conclusion') != 'skipped' else None
        step_end = instant(step.get('completed_at')) if step.get('status') == 'completed' else observed
        steps.append(dict(name=step['name'], status=step['status'], conclusion=step.get('conclusion'),
                          seconds=seconds(step_start, step_end)))
    return dict(id=job['id'], name=job['name'], status=status, conclusion=conclusion,
                url=job.get('html_url'), labels=job.get('labels', []),
                run_attempt=job.get('run_attempt'),
                created_at=job.get('created_at'), started_at=job.get('started_at'),
                completed_at=job.get('completed_at'), execution_started=bool(start),
                start_delay_seconds=start_delay, start_delay_unavailable_reason=delay_reason,
                execution_seconds=seconds(start, execution_end),
                execution_complete=bool(start and status == 'completed' and end), steps=steps)


def summarize(run, jobs, observed, checkout_sha=None, mere_ref=None):
    attempt = run['run_attempt']
    if any(j.get('run_attempt', attempt) != attempt for j in jobs):
        raise ValueError('mixed workflow attempts')
    if len({j['id'] for j in jobs}) != len(jobs):
        raise ValueError('duplicate jobs')
    work = [job_timing(j, observed) for j in jobs if j['name'] != REPORT_JOB]
    for job in work:
        job['created_after_run_seconds'] = seconds(instant(run['created_at']), instant(job['created_at']))
    complete = bool(work) and all(j['status'] == 'completed' for j in work)
    end = max((instant(j['completed_at']) for j in work if j['completed_at']), default=None)
    span_end = end if complete else observed
    return dict(schema=1, run_id=run['id'], run_attempt=attempt, url=run['html_url'],
                head_sha=run['head_sha'], checkout_sha=checkout_sha, mere_ref=mere_ref,
                event=run['event'], head_branch=run['head_branch'],
                workflow_status=run['status'], workflow_conclusion=run.get('conclusion'),
                created_at=run['created_at'], observed_at=observed.isoformat(),
                measured_jobs_complete=complete,
                measured_jobs_successful=complete and all(j['conclusion'] in ('success', 'skipped') for j in work),
                measured_work_span_seconds=seconds(instant(run['created_at']), span_end),
                sum_start_delay_seconds=sum(j['start_delay_seconds'] or 0 for j in work),
                sum_execution_seconds=sum(j['execution_seconds'] or 0 for j in work),
                unknown_start_delay_jobs=sum(j['start_delay_seconds'] is None and j['conclusion'] != 'skipped' for j in work),
                jobs=work)


def api(path):
    result = subprocess.run(['gh', 'api', path], capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise RuntimeError('GitHub API request failed: ' + result.stderr.strip())
    return json.loads(result.stdout)


def snapshot(repository, run_id, checkout_sha=None, mere_ref=None, attempt=None):
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ValueError('invalid repository')
    base = f'repos/{repository}/actions/runs/{int(run_id)}'
    run = api(f'{base}/attempts/{attempt}' if attempt is not None else base)
    if attempt is not None and run['run_attempt'] != attempt:
        raise ValueError('workflow attempt changed')
    jobs, page = [], 1
    while True:
        response = api(f'{base}/attempts/{run["run_attempt"]}/jobs?per_page=100&page={page}')
        rows = response['jobs']
        jobs.extend(rows)
        if len(jobs) >= response['total_count']:
            break
        if not rows:
            raise ValueError('incomplete job pagination')
        page += 1
    observed = datetime.now(timezone.utc)
    return run, jobs, summarize(run, jobs, observed, checkout_sha, mere_ref)


def duration(value):
    return '—' if value is None else f'{value / 60:.2f} min'


def cell(value):
    return str(value or '—').replace('|', '\\|').replace('\n', ' ').replace('\r', ' ')


def markdown(report):
    lines = [f'## CI timing: run {report["run_id"]}, attempt {report["run_attempt"]}', '',
             f'[{report["head_branch"]}: {report["head_sha"]}]({report["url"]})', '',
             f'Observed: {report["observed_at"]}. Workflow: {report["workflow_status"]} / '
             f'{report["workflow_conclusion"] or "pending"}.', '',
             f'Measured jobs complete: **{report["measured_jobs_complete"]}**; '
             f'all successful/skipped: **{report["measured_jobs_successful"]}**.', '',
             'Start delay is job creation → runner start, including matrix/concurrency '
             'throttling and runner availability. Queued rows show elapsed waiting at observation. '
             'Carried-forward executions in reruns retain their original execution time, but their '
             'start delay is unknown when the new record was created after completion. '
             'Created-after-run time includes dependency/planning delay; it is not attributed '
             'solely to dependencies. Execution is runner wall time, including setup and cleanup.', '',
             f'Measured work span: **{duration(report["measured_work_span_seconds"])}** '
             '(elapsed so far when work is incomplete; excludes this reporter). '
             f'Summed execution: **{duration(report["sum_execution_seconds"])}**; '
             f'summed start delay: **{duration(report["sum_start_delay_seconds"])}**. '
             'Sums overlap across parallel jobs and are not workflow elapsed time. '
             f'Unknown start-delay rows: {report["unknown_start_delay_jobs"]}.', '',
             '| Job | Status / conclusion | Created after run | Start delay | Execution |',
             '|---|---|---:|---:|---:|']
    for job in sorted(report['jobs'], key=lambda j: j['start_delay_seconds'] or 0, reverse=True):
        execution = duration(job['execution_seconds'])
        if job['execution_started'] and not job['execution_complete']:
            execution += ' (so far)'
        lines.append(f'| {cell(job["name"])} | {cell(job["status"])} / {cell(job["conclusion"])} '
                     f'| {duration(job["created_after_run_seconds"])} '
                     f'| {duration(job["start_delay_seconds"])} | {execution} |')
    steps = sorted(((s['seconds'], j['name'], s['name']) for j in report['jobs'] for s in j['steps']
                    if s['seconds'] is not None), reverse=True)[:15]
    lines += ['', '### Longest observed steps', '', '| Job | Step | Wall time |', '|---|---|---:|']
    lines += [f'| {cell(job)} | {cell(step)} | {duration(value)} |' for value, job, step in steps]
    return '\n'.join(lines) + '\n'


def collect(args):
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    reports = []
    for label, run_id in [('current', args.run_id), ('baseline', args.baseline_run_id)]:
        if not run_id:
            continue
        folder = output / label
        folder.mkdir(exist_ok=True)
        try:
            parameters = dict(attempt=args.run_attempt) if label == 'current' and getattr(args, 'run_attempt', None) else {}
            run, jobs, report = snapshot(args.repository, run_id,
                                         args.checkout_sha if label == 'current' else None,
                                         args.mere_ref if label == 'current' else None, **parameters)
        except Exception as error:
            (folder / 'error.json').write_text(json.dumps(dict(type=type(error).__name__, message=str(error))) + '\n')
            raise
        for name, value in [('run.json', run), ('jobs.json', jobs), ('summary.json', report)]:
            (folder / name).write_text(json.dumps(value, indent=2) + '\n')
        (folder / 'summary.md').write_text(markdown(report))
        reports.append(markdown(report))
    header = ('# CI timing snapshots\n\nJob definitions, source/compiler revisions and cache state can differ '
              'between runs. These are descriptive snapshots; an incomplete or failed baseline does '
              'not establish an end-to-end speedup.\n\n')
    rendered = header + '\n'.join(reports)
    (output / 'summary.md').write_text(rendered)
    if args.step_summary:
        with Path(args.step_summary).open('a') as file:
            file.write(rendered)
    print(rendered)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', required=True)
    parser.add_argument('--run-id', required=True, type=int)
    parser.add_argument('--run-attempt', type=int, help='pin the reporter to its own workflow attempt')
    parser.add_argument('--baseline-run-id', type=int)
    parser.add_argument('--checkout-sha')
    parser.add_argument('--mere-ref')
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--step-summary', default=os.environ.get('GITHUB_STEP_SUMMARY'))
    collect(parser.parse_args())


if __name__ == '__main__':
    main()
