#!/usr/bin/env python3
"""Check that the framework runner cannot turn a missing or failed test into MATCH."""
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('rails_framework', Path(__file__).with_name('run.py'))
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)

OK = dict(exit=0, limit=None)


def parsed(text, outcome=OK):
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
        self.assertEqual('4.0.9', data['ruby_version'])
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


if __name__ == '__main__':
    unittest.main()
