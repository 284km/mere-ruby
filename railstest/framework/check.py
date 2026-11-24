#!/usr/bin/env python3
"""Check that the framework runner cannot turn a missing or failed test into MATCH."""
import importlib.util
import json
import os
import threading
import time
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('rails_framework', Path(__file__).with_name('run.py'))
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)

def parsed(text, outcome=None):
    if outcome is None:
        # the exit minitest gives for this summary
        found = run.SUMMARY.findall(text)
        failing = bool(found) and (int(found[-1][2]) + int(found[-1][3])) > 0
        outcome = dict(exit=1 if failing else 0, limit=None)
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / 'out.stdout'
        path.write_text(text)
        return run.parse(path, outcome)


def transcript(cases, assertions=1):
    lines = ''.join(f'{name} = 0.01 s = {verdict}\n' for name, verdict in cases.items())
    counts = [sum(v == k for v in cases.values()) for k in 'FES']
    return lines + f'\n{len(cases)} runs, {assertions} assertions, {counts[0]} failures, {counts[1]} errors, {counts[2]} skips\n'


class FrameworkCheck(unittest.TestCase):
    def test_lock_matches_gemfile_and_rails_tag(self):
        data = run.lock()
        self.assertEqual('8.1.4.1', data['rails_version'])
        self.assertEqual('4.0.10', data['ruby_version'])
        self.assertEqual('3f290b759c8e2ffe7c257951b1255740751355e4', data['rails_source_commit'])
        lock = (run.ROOT / 'Gemfile.lock').read_text()
        names = {p['file'] for p in data['packages']}
        for line in lock.split('CHECKSUMS\n')[1].split('\n\n')[0].splitlines():
            name, version = line.split()[0], line.split()[1].strip('()')
            self.assertIn(f'{name}-{version}.gem', names)
        self.assertIn('bundler-4.0.20.gem', names)

    def test_verdicts(self):
        reference = parsed(transcript({'A#test_a': '.', 'A#test_b': '.', 'A#test_c': '.', 'A#test_d': 'F', 'A#test_e': 'S'}))
        mere = parsed(transcript({'A#test_a': '.', 'A#test_b': 'E', 'A#test_d': 'F', 'A#test_e': 'S', 'A#test_x': '.'}))
        self.assertEqual('COMPLETE', reference['state'])
        mere = parsed(transcript({'A#test_a': '.', 'A#test_b': 'E', 'A#test_d': 'F', 'A#test_e': 'S', 'A#test_x': '.'}),
                      dict(exit=1, limit=None))
        self.assertEqual('COMPLETE', mere['state'])
        self.assertEqual({'A#test_a': 'MATCH', 'A#test_b': 'RED', 'A#test_c': 'MISSING', 'A#test_d': 'BOTH',
                          'A#test_e': 'BOTH', 'A#test_x': 'EXTRA'}, run.classify(reference, mere))

    def test_partial_transcript_is_not_complete_and_loses_nothing(self):
        cases = {'A#test_a': '.', 'A#test_b': '.'}
        crashed = parsed('A#test_a = 0.01 s = .\n')
        self.assertEqual('INCOMPLETE', crashed['state'])
        verdicts = run.classify(parsed(transcript(cases)), crashed)
        self.assertEqual({'A#test_a': 'MATCH', 'A#test_b': 'MISSING'}, verdicts)

    def test_resource_limit_wins_over_a_summary(self):
        text = transcript({'A#test_a': '.'})
        self.assertEqual('WALL_LIMIT', parsed(text, dict(exit=-9, limit='WALL_LIMIT'))['state'])
        self.assertEqual('MEMORY_LIMIT', parsed(text, dict(exit=-9, limit='MEMORY_LIMIT'))['state'])

    def test_inconsistent_transcripts(self):
        self.assertEqual('ZERO', parsed('0 runs, 0 assertions, 0 failures, 0 errors, 0 skips\n')['state'])
        self.assertEqual('COUNT_MISMATCH', parsed('A#test_a = 0.01 s = .\n2 runs, 1 assertions, 0 failures, 0 errors, 0 skips\n')['state'])
        self.assertEqual('COUNT_MISMATCH', parsed('A#test_a = 0.01 s = .\nA#test_a = 0.01 s = .\n'
                                                  '2 runs, 1 assertions, 0 failures, 0 errors, 0 skips\n')['state'])
        self.assertEqual('REPORT_MISMATCH', parsed('A#test_a = 0.01 s = .\n1 runs, 1 assertions, 1 failures, 0 errors, 0 skips\n')['state'])

    def test_unhealthy_reference_compares_nothing(self):
        record = dict(files={'activesupport/test/x_test.rb': dict(sides=dict(
            reference=dict(parsed('boom\n'), exit=1), mere=dict(parsed(transcript({'A#test_a': '.'})), exit=0)))})
        run.summarize(record)
        entry = record['files']['activesupport/test/x_test.rb']
        self.assertEqual('REFERENCE_INCOMPLETE', entry['verdict'])
        self.assertEqual(0, entry['counts']['MATCH'])
        self.assertEqual(1, record['components']['activesupport']['reference_unusable'])

    def test_inherited_settings_are_dropped(self):
        with patch.dict(os.environ, dict(RUBYOPT='-rforeign', RUBYLIB='/foreign', GEM_PATH='/foreign', BUNDLE_PATH='/x',
                                        RAILS_STRICT_WARNINGS='1', BUILDKITE='1', CI='1')):
            env = run.environment(Path('/run/reference'), '/stdlib')
        self.assertEqual('/run/reference/gems', env['GEM_PATH'])
        self.assertEqual('/run/reference/bundle/Gemfile', env['BUNDLE_GEMFILE'])
        self.assertEqual('--disable-gems -r' + str(run.RAILSTEST / 'bootstrap.rb'), env['RUBYOPT'])
        for name in ('RUBYLIB', 'BUNDLE_PATH', 'RAILS_STRICT_WARNINGS', 'BUILDKITE', 'CI'):
            self.assertNotIn(name, env)
        with patch.dict(os.environ, dict(RUBYLIB='/foreign')):
            env = run.environment(Path('/run/mere'), '/stdlib', mere=True)
        self.assertEqual('/stdlib', env['RUBYLIB'])

    def test_shared_settings_reach_both_sides_and_stay_publishable(self):
        # --env: the same setting on both sides, recorded; never a setting the
        # runner makes, mere-ruby's own, a secret, or a path of this machine
        shared = run.shared_settings(['ARCONN=sqlite3', 'AR_TEST_FLAG=1'])
        self.assertEqual({'AR_TEST_FLAG': '1', 'ARCONN': 'sqlite3'}, shared)
        for side, mere in (('reference', False), ('mere', True)):
            env = run.side_environment(Path('/run') / side, '/stdlib', mere, shared)
            self.assertEqual('sqlite3', env['ARCONN'])
            self.assertEqual(f'/run/{side}/gems', env['GEM_HOME'])
        for bad in ('ARCONN', 'arconn=sqlite3', 'GEM_HOME=/x', 'RUBYOPT=-rx', 'TMPDIR=t', 'PATH=x',
                    'BUNDLE_GEMFILE=x', 'MERE_RUBY_VM=1', 'GITHUB_TOKEN=abc', 'DB_PASSWORD=pw', 'AWS_SECRET=s',
                    'AR_DB=/Users/someone/db', 'AR_DB=~/db', 'AR_DB=x:/tmp/db', 'AR_DB=/home/u/db'):
            with self.subTest(item=bad):
                with self.assertRaises(ValueError):
                    run.shared_settings([bad])

    def test_selection_stays_inside_component_tests(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            (source / 'activesupport/test/core_ext').mkdir(parents=True)
            (source / 'activesupport/test/core_ext/a_test.rb').write_text('')
            (source / 'activesupport/test/b_test.rb').write_text('')
            (source / 'activesupport/test/helper.rb').write_text('')
            (source / 'tools').mkdir()
            (source / 'tools/c_test.rb').write_text('')
            self.assertEqual(['activesupport/test/b_test.rb', 'activesupport/test/core_ext/a_test.rb'],
                             run.select_files(source, ['activesupport/test']))
            with self.assertRaisesRegex(ValueError, 'not a component test'):
                run.select_files(source, ['tools'])
            with self.assertRaisesRegex(ValueError, 'no such'):
                run.select_files(source, ['activemodel/test'])

    def test_compare_reports_a_lost_match(self):
        def record(mere_verdict):
            ref = parsed(transcript({'A#test_a': '.', 'A#test_b': '.'}))
            mere = parsed(transcript({'A#test_a': '.', 'A#test_b': mere_verdict}))
            data = dict(files={'activesupport/test/x_test.rb': dict(sides=dict(reference=ref, mere=mere))})
            run.summarize(data)
            return data
        with tempfile.TemporaryDirectory() as directory:
            base, new = Path(directory) / 'base.json', Path(directory) / 'new.json'
            base.write_text(json.dumps(record('.')))
            new.write_text(json.dumps(record('F')))
            args = type('Args', (), dict(base=base, new=new))
            with open(os.devnull, 'w') as sink, patch('sys.stdout', sink):
                self.assertEqual(1, run.compare(args))
                args.base, args.new = new, base
                self.assertEqual(0, run.compare(args))

    def test_jobs_are_bounded(self):
        self.assertEqual(2, run.MAX_JOBS)

    def test_one_side_never_runs_two_files_at_once(self):
        # mere-ruby is the slow side: with a shared pool its second file used
        # to start while its first still ran
        running, overlaps, lock = {}, [], threading.Lock()

        def one(side, _binary, name):
            with lock:
                if running.get(side):
                    overlaps.append((side, running[side], name))
                running[side] = name
            time.sleep(0.02 if side == 'mere' else 0.002)
            with lock:
                running[side] = None
        files = [f'activesupport/test/f{i}_test.rb' for i in range(6)]
        run.schedule([('reference', 'r'), ('mere', 'm')], files, 2, one)
        self.assertEqual([], overlaps)

    def test_a_duplicated_name_keeps_its_worse_verdict(self):
        twice = parsed('A#test_a = 0.01 s = F\nA#test_a = 0.01 s = .\n1 runs, 1 assertions, 1 failures, 0 errors, 0 skips\n')
        self.assertEqual('F', twice['cases']['A#test_a'])
        self.assertEqual('COUNT_MISMATCH', twice['state'])
        reference = parsed(transcript({'A#test_a': '.'}))
        self.assertEqual({'A#test_a': 'RED'}, run.classify(reference, twice))

    def test_a_pass_in_an_inconsistent_transcript_is_not_a_match(self):
        reference = parsed(transcript({'A#test_a': '.', 'A#test_b': '.'}))
        lying = parsed('A#test_a = 0.01 s = .\nA#test_b = 0.01 s = .\n2 runs, 2 assertions, 1 failures, 0 errors, 0 skips\n',
                       dict(exit=1, limit=None))
        self.assertEqual('REPORT_MISMATCH', lying['state'])
        self.assertEqual({'A#test_a': 'UNCONFIRMED', 'A#test_b': 'UNCONFIRMED'}, run.classify(reference, lying))

    def test_a_crash_after_the_summary_is_visible(self):
        text = transcript({'A#test_a': '.'})
        self.assertEqual('EXIT_ERROR', parsed(text, dict(exit=-11, limit=None))['state'])
        self.assertEqual('EXIT_ERROR', parsed(text, dict(exit=1, limit=None))['state'])
        self.assertEqual('COMPLETE', parsed(transcript({'A#test_a': 'F'}), dict(exit=1, limit=None))['state'])
        # the verdicts it did report are still compared
        crashed = parsed(text, dict(exit=-11, limit=None))
        self.assertEqual({'A#test_a': 'MATCH'}, run.classify(parsed(text), crashed))

    def test_output_in_front_of_a_result_line(self):
        # a class name with spaces (a describe block) is read whole
        spaced = parsed('a thing#test_0001_works = 0.01 s = .\n1 runs, 1 assertions, 0 failures, 0 errors, 0 skips\n')
        self.assertEqual(['a thing#test_0001_works'], list(spaced['cases']))
        # output in front of a result line makes another name: never a MATCH
        reference = parsed(transcript({'A#test_a': '.'}))
        noisy = parsed('hello A#test_a = 0.01 s = .\n1 runs, 1 assertions, 0 failures, 0 errors, 0 skips\n')
        self.assertEqual({'A#test_a': 'MISSING', 'hello A#test_a': 'EXTRA'}, run.classify(reference, noisy))

    def test_order_is_compared(self):
        cases = {'A#test_a': '.', 'A#test_b': '.'}
        record = dict(files={'activesupport/test/x_test.rb': dict(sides=dict(
            reference=parsed(transcript(cases)), mere=parsed(transcript(dict(reversed(list(cases.items()))))))),
            'activesupport/test/y_test.rb': dict(sides=dict(reference=parsed(transcript(cases)), mere=parsed(transcript(cases))))})
        run.summarize(record)
        self.assertFalse(record['files']['activesupport/test/x_test.rb']['same_order'])
        self.assertTrue(record['files']['activesupport/test/y_test.rb']['same_order'])
        self.assertEqual(1, record['components']['activesupport']['order_differs'])

    def test_compare_counts_a_vanished_file_or_side(self):
        cases = {'A#test_a': '.'}
        full = dict(files={'activesupport/test/x_test.rb': dict(sides=dict(
            reference=parsed(transcript(cases)), mere=parsed(transcript(cases))))})
        run.summarize(full)
        no_mere = dict(files={'activesupport/test/x_test.rb': dict(sides=dict(reference=parsed(transcript(cases))))})
        run.summarize(no_mere)
        with tempfile.TemporaryDirectory() as directory:
            base, new = Path(directory) / 'base.json', Path(directory) / 'new.json'
            base.write_text(json.dumps(full))
            args = type('Args', (), dict(base=base, new=new))
            with open(os.devnull, 'w') as sink, patch('sys.stdout', sink):
                for gone in (dict(files={}), no_mere):
                    new.write_text(json.dumps(gone))
                    self.assertEqual(1, run.compare(args))

    def test_a_run_uses_the_binary_that_installed(self):
        record = dict(sides=dict(mere=dict(binary_sha256='a' * 64)))
        self.assertTrue(run.check_install_binary(record, 'mere', 'a' * 64, False))
        with self.assertRaisesRegex(ValueError, 'not the one that installed'):
            run.check_install_binary(record, 'mere', 'b' * 64, False)
        self.assertFalse(run.check_install_binary(record, 'mere', 'b' * 64, True))

    def test_mere_settings_are_checked_first(self):
        self.assertEqual({'MERE_RUBY_VM': '1'}, run.mere_settings(['MERE_RUBY_VM=1']))
        for bad in (['RUBYOPT=-rx'], ['MERE_RUBY_VM']):
            with self.assertRaisesRegex(ValueError, 'MERE_RUBY_'):
                run.mere_settings(bad)

    def test_install_requires_every_component(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'source/activesupport/lib').mkdir(parents=True)
            (root / 'home/gems').mkdir(parents=True)
            with self.assertRaisesRegex(ValueError, 'not installed'):
                run.component_lib_parity(root / 'source', root / 'home')


if __name__ == '__main__':
    unittest.main()
