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

    @staticmethod
    def anonymous_case(address, suffix='a', second=None):
        second = address if second is None else second
        return f"T#test_#<Class:0x{address}>_matches_#<Class:0x{second}>_{suffix}"

    def test_opaque_class_addresses_require_explicit_policy_and_keep_raw_names(self):
        rname, mname = self.anonymous_case('0011'), self.anonymous_case('abcd')
        reference, mere = parsed(transcript({rname: '.'})), parsed(transcript({mname: '.'}))
        self.assertEqual({rname: 'MISSING', mname: 'EXTRA'}, run.classify(reference, mere))
        self.assertEqual({rname: 'MATCH'}, run.classify(reference, mere, 'opaque-class-addresses'))
        self.assertEqual([mname], list(mere['cases']))
        self.assertEqual({mname: rname}, run.case_identity_aliases(reference, mere, 'opaque-class-addresses'))
        name = 'activesupport/test/example_test.rb'
        record = dict(files={name: dict(sides=dict(reference=reference, mere=mere))})
        self.assertFalse(run.all_pass(record, [name]))
        record['case_identity_policy'] = 'opaque-class-addresses'
        self.assertTrue(run.all_pass(record, [name]))
        run.summarize(record)
        self.assertEqual(1, record['components']['activesupport']['MATCH'])
        self.assertEqual({mname: rname}, record['files'][name]['case_identity_aliases'])
        self.assertTrue(record['files'][name]['same_order'])

    def test_opaque_class_aliases_preserve_results_and_require_complete_inventories(self):
        rname, mname = self.anonymous_case('11'), self.anonymous_case('22')
        good = parsed(transcript({rname: '.'}))
        for verdict in 'FES':
            bad = parsed(transcript({mname: verdict}))
            self.assertEqual({rname: 'RED'}, run.classify(good, bad, 'opaque-class-addresses'))
        bad_reference = parsed(transcript({rname: 'F'}))
        self.assertEqual({rname: 'BOTH'}, run.classify(bad_reference, parsed(transcript({mname: '.'})),
                                                    'opaque-class-addresses'))
        for state in ('ZERO', 'INCOMPLETE', 'COUNT_MISMATCH', 'REPORT_MISMATCH', 'WALL_LIMIT',
                      'MEMORY_LIMIT', 'EXIT_ERROR'):
            for side in ('reference', 'mere'):
                reference, mere = good, parsed(transcript({mname: '.'}))
                if side == 'reference':
                    reference = dict(reference, state=state)
                else:
                    mere = dict(mere, state=state)
                self.assertEqual({}, run.case_identity_aliases(reference, mere, 'opaque-class-addresses'))

    def test_opaque_class_aliases_reject_collisions_and_repeated_address_mismatches(self):
        rname, mname = self.anonymous_case('11'), self.anonymous_case('22')
        for reference, mere in (
            ({rname: '.', self.anonymous_case('33'): '.'}, {mname: '.'}),
            ({rname: '.'}, {mname: '.', self.anonymous_case('33'): '.'}),
            ({rname: '.', self.anonymous_case('33'): '.'}, {mname: '.', self.anonymous_case('44'): '.'}),
            ({rname: '.'}, {self.anonymous_case('22', second='33'): '.'}),
            ({'T#test_object_#<Object:0x11>': '.'}, {'T#test_object_#<Object:0x22>': '.'}),
            ({'T#test_literal_0x11': '.'}, {'T#test_literal_0x22': '.'}),
        ):
            left, right = parsed(transcript(reference)), parsed(transcript(mere))
            self.assertEqual({}, run.case_identity_aliases(left, right, 'opaque-class-addresses'))
            self.assertNotIn('MATCH', run.classify(left, right, 'opaque-class-addresses').values())

    def test_ambiguous_shapes_do_not_reassign_a_literal_match(self):
        common = self.anonymous_case('11')
        reference = parsed(transcript({common: '.', self.anonymous_case('22'): '.'}))
        mere = parsed(transcript({common: '.', self.anonymous_case('33'): '.'}))
        self.assertEqual(run.classify(reference, mere),
                         run.classify(reference, mere, 'opaque-class-addresses'))
        self.assertEqual({}, run.case_identity_aliases(reference, mere, 'opaque-class-addresses'))

    def test_opaque_class_aliases_preserve_bijections_across_test_names(self):
        left = {self.anonymous_case('11', 'a'): '.', self.anonymous_case('11', 'b'): '.'}
        consistent = {self.anonymous_case('22', 'a'): '.', self.anonymous_case('22', 'b'): '.'}
        reference = parsed(transcript(left))
        self.assertEqual(set(left), set(run.classify(reference, parsed(transcript(consistent)),
                                                   'opaque-class-addresses')))
        for right in (
            {self.anonymous_case('22', 'a'): '.', self.anonymous_case('33', 'b'): '.'},
            {self.anonymous_case('11', 'a'): '.', self.anonymous_case('22', 'b'): '.'},
        ):
            aliases = run.case_identity_aliases(reference, parsed(transcript(right)), 'opaque-class-addresses')
            self.assertEqual({}, aliases)
        reference = parsed(transcript({self.anonymous_case('11', 'a'): '.', self.anonymous_case('33', 'b'): '.'}))
        self.assertEqual({}, run.case_identity_aliases(reference, parsed(transcript(consistent)),
                                                     'opaque-class-addresses'))
        with self.assertRaises(ValueError):
            run.classify(reference, parsed(transcript(consistent)), 'unknown-policy')

    def test_partial_transcript_is_not_complete_and_loses_nothing(self):
        cases = {'A#test_a': '.', 'A#test_b': '.'}
        crashed = parsed('A#test_a = 0.01 s = .\n')
        self.assertEqual('INCOMPLETE', crashed['state'])
        verdicts = run.classify(parsed(transcript(cases)), crashed)
        self.assertEqual({'A#test_a': 'MATCH', 'A#test_b': 'MISSING'}, verdicts)

    def test_all_pass_requires_every_selected_file_and_both_inventories(self):
        name = 'actionpack/test/example_test.rb'
        healthy = parsed(transcript({'A#test_a': '.', 'A#test_b': '.'}))
        def record(reference=healthy, mere=healthy):
            return dict(files={name: dict(sides=dict(reference=reference, mere=mere))})
        self.assertTrue(run.all_pass(record(), [name]))
        self.assertFalse(run.all_pass(record(), [name, 'actionpack/test/missing_test.rb']))
        self.assertFalse(run.all_pass(dict(files={}), []))
        self.assertFalse(run.all_pass(dict(files={name: dict(sides=dict(mere=healthy))}), [name]))
        self.assertFalse(run.all_pass(record(mere=parsed(transcript({'A#test_a': '.'}))), [name]))
        self.assertFalse(run.all_pass(record(mere=parsed(transcript({'A#test_a': '.', 'A#test_b': '.',
                                                                     'A#test_extra': '.'}))), [name]))
        for verdict in ('F', 'E', 'S'):
            bad = parsed(transcript({'A#test_a': '.', 'A#test_b': verdict}))
            self.assertFalse(run.all_pass(record(mere=bad), [name]))
            self.assertFalse(run.all_pass(record(reference=bad), [name]))
        for state in ('ZERO', 'INCOMPLETE', 'COUNT_MISMATCH', 'REPORT_MISMATCH', 'WALL_LIMIT',
                      'MEMORY_LIMIT', 'EXIT_ERROR'):
            bad = dict(healthy, state=state)
            self.assertFalse(run.all_pass(record(mere=bad), [name]))
            self.assertFalse(run.all_pass(record(reference=bad), [name]))

    def test_logged_output_between_name_and_result_keeps_the_test_identity(self):
        out = ('A#test_a = W, [timestamp] WARN -- : a real log line\n'
               'a second diagnostic line\n0.01 s = .\n'
               'A#test_b = 0.02 s = F\n'
               '2 runs, 3 assertions, 1 failures, 0 errors, 0 skips\n')
        result = parsed(out)
        self.assertEqual('COMPLETE', result['state'])
        self.assertEqual({'A#test_a': '.', 'A#test_b': 'F'}, result['cases'])
        missing = parsed('A#test_a = a log line\nA#test_b = 0.02 s = .\n'
                         '0.01 s = .\n2 runs, 3 assertions, 0 failures, 0 errors, 0 skips\n')
        self.assertEqual('COUNT_MISMATCH', missing['state'])
        self.assertEqual({'A#test_b': '.'}, missing['cases'])

    def test_empty_upstream_files_are_accounted_for_without_inventing_tests(self):
        zero = dict(parsed('0 runs, 0 assertions, 0 failures, 0 errors, 0 skips\n'), exit=0, limit=None)
        name = 'actionpack/test/controller/new_base/render_xml_test.rb'
        size, digest = run.EMPTY_TEST_SOURCES[name]
        entry = dict(source_bytes=size, source_sha256=digest, sides=dict(reference=zero, mere=zero))
        record = dict(files={name: entry})
        self.assertTrue(run.all_pass(record, [name]))
        run.summarize(record)
        self.assertEqual('EMPTY', entry['verdict'])
        self.assertEqual(0, entry['counts']['MATCH'])
        self.assertEqual(1, record['components']['actionpack']['empty_files'])
        self.assertEqual(0, record['components']['actionpack']['reference_unusable'])
        name = 'actionpack/test/journey/nodes/symbol_test.rb'
        size, digest = run.EMPTY_TEST_SOURCES[name]
        no_output = dict(parsed(''), exit=0, limit=None)
        entry = dict(source_bytes=size, source_sha256=digest,
                     sides=dict(reference=no_output, mere=no_output))
        record = dict(files={name: entry})
        self.assertTrue(run.all_pass(record, [name]))
        entry['source_bytes'] = 100
        self.assertFalse(run.all_pass(record, [name]))
        entry['source_bytes'] = size
        entry['source_sha256'] = 'changed'
        self.assertFalse(run.all_pass(record, [name]))
        entry.update(source_sha256=digest, sides=dict(reference=no_output, mere=dict(no_output, exit=1)))
        self.assertFalse(run.all_pass(record, [name]))

    def test_missing_service_zero_runs_cannot_pass_as_an_empty_file(self):
        zero = dict(parsed('0 runs, 0 assertions, 0 failures, 0 errors, 0 skips\n'), exit=0, limit=None)
        name = 'actionpack/test/dispatch/session/mem_cache_store_test.rb'
        size, digest = run.EMPTY_TEST_SOURCES['actionpack/test/controller/new_base/render_xml_test.rb']
        entry = dict(source_bytes=size, source_sha256=digest, sides=dict(reference=zero, mere=zero))
        record = dict(files={name: entry})
        self.assertFalse(run.all_pass(record, [name]))
        run.summarize(record)
        self.assertEqual('REFERENCE_ZERO', entry['verdict'])
        self.assertEqual(0, entry['counts']['MATCH'])
        self.assertEqual(0, record['components']['actionpack']['empty_files'])
        self.assertEqual(1, record['components']['actionpack']['reference_unusable'])

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

    def test_framework_startup_libraries_are_shared_by_both_interpreters(self):
        for mere in (False, True):
            env = run.side_environment(Path('/run/side'), '/stdlib', mere, {}, framework_bootstrap=True)
            self.assertEqual('--disable-gems -r' + str(run.ROOT / 'bootstrap.rb'), env['RUBYOPT'])

    def test_default_component_startup_keeps_application_bootstrap(self):
        for mere in (False, True):
            env = run.side_environment(Path('/run/side'), '/stdlib', mere, {})
            self.assertEqual('--disable-gems -r' + str(run.RAILSTEST / 'bootstrap.rb'), env['RUBYOPT'])

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

    def identity_record(self, reference_cases, mere_cases, mere_state=None):
        reference, mere = parsed(transcript(reference_cases)), parsed(transcript(mere_cases))
        if mere_state:
            mere['state'] = mere_state
        record = dict(case_identity_policy='opaque-class-addresses', files={
            'activesupport/test/x_test.rb': dict(sides=dict(reference=reference, mere=mere))})
        run.summarize(record)
        return record

    def compare_records(self, before, after):
        with tempfile.TemporaryDirectory() as directory:
            base, new = Path(directory) / 'base.json', Path(directory) / 'new.json'
            base.write_text(json.dumps(before))
            new.write_text(json.dumps(after))
            args = type('Args', (), dict(base=base, new=new))
            with open(os.devnull, 'w') as sink, patch('sys.stdout', sink):
                return run.compare(args)

    def test_compare_opaque_addresses_keeps_passes_and_detects_failures(self):
        a, b, c, d = [self.anonymous_case(x) for x in ('11', '22', '33', '44')]
        before = self.identity_record({a: '.'}, {b: '.'})
        self.assertEqual(0, self.compare_records(before, self.identity_record({c: '.'}, {d: '.'})))
        for verdict in 'FES':
            self.assertEqual(1, self.compare_records(before, self.identity_record({c: '.'}, {d: verdict})))
        self.assertEqual(1, self.compare_records(before, self.identity_record({c: 'F'}, {d: '.'})))

    def test_compare_opaque_addresses_rejects_incomplete_or_missing_tests(self):
        a, b, c, d = [self.anonymous_case(x) for x in ('11', '22', '33', '44')]
        before = self.identity_record({a: '.'}, {b: '.'})
        for state in ('INCOMPLETE', 'COUNT_MISMATCH', 'REPORT_MISMATCH', 'WALL_LIMIT', 'MEMORY_LIMIT'):
            self.assertEqual(1, self.compare_records(before, self.identity_record({c: '.'}, {d: '.'}, state)))
        self.assertEqual(1, self.compare_records(before, self.identity_record({c: '.'}, {})))
        self.assertEqual(1, self.compare_records(before, dict(files={}, case_identity_policy='opaque-class-addresses')))

    def test_compare_opaque_addresses_preserves_cross_case_relationships(self):
        make = self.anonymous_case
        old = {make('11', 'a'): '.', make('11', 'b'): '.'}
        consistent = {make('22', 'a'): '.', make('22', 'b'): '.'}
        inconsistent = {make('22', 'a'): '.', make('33', 'b'): '.'}
        before = self.identity_record(old, old)
        self.assertEqual(0, self.compare_records(before, self.identity_record(consistent, consistent)))
        self.assertEqual(1, self.compare_records(before, self.identity_record(inconsistent, inconsistent)))
        old = {make('11'): '.', make('22'): '.'}
        new = {make('33'): '.', make('44'): '.'}
        self.assertEqual(1, self.compare_records(self.identity_record(old, old), self.identity_record(new, new)))

    def test_compare_opaque_addresses_does_not_hide_extra_name_collisions(self):
        a, b, c = [self.anonymous_case(x) for x in ('11', '22', '33')]
        before = self.identity_record({a: '.'}, {b: '.'})
        after = self.identity_record({c: '.'}, {c: '.', a: '.'})
        self.assertEqual(1, self.compare_records(before, after))

    def test_compare_refuses_mixed_identity_policies(self):
        a, b = self.anonymous_case('11'), self.anonymous_case('22')
        before = self.identity_record({a: '.'}, {b: '.'})
        after = self.identity_record({a: '.'}, {b: '.'})
        after.pop('case_identity_policy')
        with self.assertRaisesRegex(ValueError, 'same supported case identity policy'):
            self.compare_records(before, after)

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


class ArgumentDescriptionCheck(unittest.TestCase):
    policy = 'rails-argument-descriptions'

    @staticmethod
    def names(second='20', offset='+0900'):
        prefix = 'ArgumentSerializationTest#test_serializes_Range_-_'
        return [prefix + f'2026-11-18_01:13:{second}.123456_{offset}..'
                '#<Date:_2026-11-28_((2461373j,0s,0n),+0s,2299161j)>_verbatim',
                prefix + f'2026-11-27_15:13:{second}.123456_{offset}..'
                f'2026-11-28_01:13:{second}.123457_{offset}_verbatim',
                prefix + f'Sat,_31_Oct_2026_01:13:{second}_{offset}..'
                f'Sat,_28_Nov_2026_01:13:{second}_{offset}_verbatim']

    def sides(self, verdict='.'):
        return (parsed(transcript(dict.fromkeys(self.names('20'), '.'))),
                parsed(transcript(dict.fromkeys(self.names('23'), verdict))))

    def test_clock_pairing_is_explicit_and_source_pinned(self):
        reference, mere = self.sides()
        for policy, digest in (('literal', run.ARGUMENT_SOURCE_SHA256),
                               ('opaque-class-addresses', run.ARGUMENT_SOURCE_SHA256),
                               (self.policy, None), (self.policy, 'changed-source')):
            self.assertEqual({}, run.case_identity_aliases(reference, mere, policy, digest))
        verdicts = run.classify(reference, mere, self.policy, run.ARGUMENT_SOURCE_SHA256)
        self.assertEqual(dict.fromkeys(self.names('20'), 'MATCH'), verdicts)
        self.assertEqual(self.names('23'), list(mere['cases']))

    def test_pairing_does_not_hide_failed_assertions(self):
        reference, mere = self.sides('F')
        self.assertEqual(dict.fromkeys(self.names('20'), 'RED'),
                         run.classify(reference, mere, self.policy, run.ARGUMENT_SOURCE_SHA256))

    def test_invalid_clock_values_do_not_become_matches(self):
        mutations = [
            (0, '2026-11-18', '2023-01-01'),
            (0, '2026-11-18', '2026-11-19'),
            (0, '2026-11-18', '2026-11-17'),
            (0, '2026-11-18', '2026-02-30'),
            (0, '2461373j', '2461374j'),
            (1, '2026-11-27', '2026-11-20'),
            (1, '2026-11-28_01:13:23', '2026-11-28_01:13:28'),
            (1, '15:13:23', '25:13:23'),
            (1, '+0900', '+0060'),
            (2, 'Sat,_31_Oct_2026', 'Mon,_31_Oct_2026'),
            (2, 'Sat,_31_Oct_2026', 'Sat,_07_Nov_2026'),
            (2, 'Sat,_31_Oct_2026', 'Sat,_31_Nov_2026'),
        ]
        for index, old, new in mutations:
            with self.subTest(index=index, old=old, new=new):
                reference, _ = self.sides()
                names = self.names('23')
                names[index] = names[index].replace(old, new, 1)
                mere = parsed(transcript(dict.fromkeys(names, '.')))
                aliases = run.case_identity_aliases(reference, mere, self.policy,
                                                     run.ARGUMENT_SOURCE_SHA256)
                self.assertNotIn(names[index], aliases)
                verdicts = run.classify(reference, mere, self.policy, run.ARGUMENT_SOURCE_SHA256)
                self.assertEqual('MISSING', verdicts[self.names('20')[index]])
                self.assertEqual('EXTRA', verdicts[names[index]])

    def test_clock_values_are_validated_on_both_sides(self):
        reference, mere = self.sides()
        bad = self.names('20')[2].replace('Sat,_31_Oct', 'Mon,_31_Oct')
        reference['cases'] = {bad: '.'}
        mere['cases'] = {self.names('23')[2]: '.'}
        self.assertEqual({}, run.case_identity_aliases(reference, mere, self.policy,
                                                       run.ARGUMENT_SOURCE_SHA256))

    def test_subsecond_precision_is_not_a_clock_identity(self):
        reference, _ = self.sides()
        names = [name.replace('.123456', '.12345') for name in self.names('23')]
        mere = parsed(transcript(dict.fromkeys(names, '.')))
        self.assertEqual(3, len(run.case_identity_aliases(reference, mere, self.policy,
                                                        run.ARGUMENT_SOURCE_SHA256)))

    def test_hours_use_utc_elapsed_time_across_offset_changes(self):
        prefix = 'ArgumentSerializationTest#test_serializes_Range_-_'
        def name(second):
            return prefix + f'2026-11-01_00:13:{second}_-0400..2026-11-01_09:13:{second}_-0500_verbatim'
        reference = parsed(transcript({name('20'): '.'}))
        mere = parsed(transcript({name('23'): '.'}))
        self.assertEqual({name('23'): name('20')}, run.case_identity_aliases(
            reference, mere, self.policy, run.ARGUMENT_SOURCE_SHA256))

    def test_date_clock_reads_can_cross_midnight(self):
        prefix = 'ArgumentSerializationTest#test_serializes_Range_-_'
        def name(second):
            return prefix + f'2026-11-18_23:59:{second}_+0900..#<Date:_2026-11-29_((2461374j,0s,0n),+0s,2299161j)>_verbatim'
        reference = parsed(transcript({name('58'): '.'}))
        mere = parsed(transcript({name('59'): '.'}))
        self.assertEqual({name('59'): name('58')}, run.case_identity_aliases(
            reference, mere, self.policy, run.ARGUMENT_SOURCE_SHA256))

    def test_offsets_remain_part_of_the_identity(self):
        reference, _ = self.sides()
        mere = parsed(transcript(dict.fromkeys(self.names('23', '+0800'), '.')))
        self.assertEqual({}, run.case_identity_aliases(reference, mere, self.policy,
                                                       run.ARGUMENT_SOURCE_SHA256))

    def test_ambiguous_and_incomplete_cases_stay_unpaired(self):
        reference, mere = self.sides()
        for side, extra in ((reference, '21'), (mere, '24')):
            side['cases'].update(dict.fromkeys(self.names(extra), '.'))
        self.assertEqual({}, run.case_identity_aliases(reference, mere, self.policy,
                                                       run.ARGUMENT_SOURCE_SHA256))
        reference, mere = self.sides()
        mere['state'] = 'INCOMPLETE'
        self.assertEqual({}, run.case_identity_aliases(reference, mere, self.policy,
                                                       run.ARGUMENT_SOURCE_SHA256))

    def test_other_tests_are_not_clock_descriptions(self):
        reference = parsed(transcript({self.names('20')[0].replace('ArgumentSerializationTest', 'OtherTest'): '.'}))
        mere = parsed(transcript({self.names('23')[0].replace('ArgumentSerializationTest', 'OtherTest'): '.'}))
        self.assertEqual({}, run.case_identity_aliases(reference, mere, self.policy,
                                                       run.ARGUMENT_SOURCE_SHA256))
        rname, mname = 'T#test_#<Class:0x0011>', 'T#test_#<Class:0xabcd>'
        reference, mere = parsed(transcript({rname: '.'})), parsed(transcript({mname: '.'}))
        self.assertEqual({mname: rname}, run.case_identity_aliases(reference, mere, self.policy))

    def test_summarize_all_pass_and_compare_keep_the_same_policy(self):
        name = 'activejob/test/cases/argument_serialization_test.rb'
        def record(second):
            sides = {s: parsed(transcript(dict.fromkeys(self.names(second if s == 'reference' else '24'), '.')))
                     for s in ('reference', 'mere')}
            r = dict(case_identity_policy=self.policy, files={name: dict(
                sides=sides, source_sha256=run.ARGUMENT_SOURCE_SHA256)})
            run.summarize(r)
            self.assertEqual(3, r['components']['activejob']['MATCH'])
            self.assertTrue(run.all_pass(r, [name]))
            return r
        before, after = record('20'), record('23')
        with tempfile.TemporaryDirectory() as directory:
            base, new = Path(directory) / 'base.json', Path(directory) / 'new.json'
            base.write_text(json.dumps(before))
            new.write_text(json.dumps(after))
            args = type('Args', (), dict(base=base, new=new))
            with open(os.devnull, 'w') as sink, patch('sys.stdout', sink):
                self.assertEqual(0, run.compare(args))
                after['files'][name]['sides']['mere']['cases'][self.names('24')[0]] = 'F'
                run.summarize(after)
                self.assertFalse(run.all_pass(after, [name]))
                new.write_text(json.dumps(after))
                self.assertEqual(1, run.compare(args))


if __name__ == '__main__':
    unittest.main()
