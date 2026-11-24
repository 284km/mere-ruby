"""Negative controls for coverage, classification, and locked source integrity."""
import copy
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from types import SimpleNamespace
from pathlib import Path
import unittest
from unittest.mock import patch

import suites


class SuiteChecks(unittest.TestCase):
    def side(self):
        return dict(exit=0, limit=None, tally=dict(tests=3, assertions=4, failures=0, errors=0, skips=0))

    def test_zero_or_all_skipped_is_never_match(self):
        good = self.side()
        for tests, skips in ((0, 0), (3, 3)):
            empty = copy.deepcopy(good)
            empty['tally'].update(tests=tests, skips=skips)
            self.assertEqual(suites.verdict(good, empty), 'RED')
            self.assertEqual(suites.verdict(empty, empty), 'BOTH')

    def test_early_exit_and_fewer_assertions_are_red(self):
        good = self.side()
        for change in ({'tally': None}, {'exit': 1}):
            broken = dict(good, **change)
            self.assertEqual(suites.verdict(good, broken), 'RED')
        fewer = copy.deepcopy(good)
        fewer['tally']['assertions'] -= 1
        self.assertEqual(suites.verdict(good, fewer), 'RED')

    def test_limits_take_precedence_on_either_side(self):
        good = self.side()
        for limit, expected in (('WALL_LIMIT', 'TIMEOUT'), ('MEMORY_LIMIT', 'MEMORY')):
            broken = dict(good, limit=limit, exit=-9)
            self.assertEqual(suites.verdict(good, broken), expected)
            self.assertEqual(suites.verdict(broken, good), expected)

    def test_reporter_ansi_and_summary(self):
        self.assertEqual(suites.tally('\x1b[32m3 tests, 4 assertions, 0 failures, 0 errors, 0 skips\x1b[0m', ''), self.side()['tally'])
        self.assertIsNone(suites.tally('Finished without a summary', ''))

    def test_reference_failure_cannot_hide_a_regression(self):
        row = dict(gem='fixture', file='test.rb', classification='MATCH', reference=self.side(), mere=self.side())
        broken = copy.deepcopy(row)
        broken['classification'] = 'BOTH'
        broken['reference']['exit'] = 1
        errors = suites.compare([broken], dict(rows=[row]))
        self.assertEqual(len(errors), 2)
        self.assertTrue(suites.compare([], dict(rows=[row])))

    def test_test_unit_retains_every_count_and_rejects_all_omitted(self):
        text = '3 tests, 4 assertions, 0 failures, 0 errors,\n1 pendings, 1 omissions, 2 notifications'
        counts = suites.tally(text, '', 'test-unit-gem')
        self.assertEqual(counts, dict(tests=3, assertions=4, failures=0, errors=0,
                                      pendings=1, omissions=1, notifications=2, skips=2))
        good = dict(self.side(), tally=counts)
        self.assertEqual(suites.verdict(good, good), 'MATCH')
        omitted = dict(good, tally=dict(counts, tests=2))
        self.assertEqual(suites.verdict(omitted, omitted), 'BOTH')
        changed = dict(good, tally=dict(counts, notifications=3))
        self.assertEqual(suites.verdict(good, changed), 'RED')
        self.assertIsNone(suites.tally('0 failures', '', 'test-unit-gem'))

    def test_a_baseline_must_match_the_lock_and_platform(self):
        row = dict(gem='fixture', file='test.rb', classification='MATCH', reference=self.side(), mere=self.side())
        result = dict(rows=[row], lock_sha256='locked', platform='Linux')
        self.assertEqual(suites.baseline_errors(result, result), [])
        with self.assertRaisesRegex(ValueError, 'platform differs'):
            suites.baseline_errors(result, dict(result, platform='Darwin'))
        with self.assertRaisesRegex(ValueError, 'lock differs'):
            suites.baseline_errors(result, dict(result, lock_sha256='changed'))
        broken = copy.deepcopy(result)
        broken['rows'][0]['classification'] = 'MEMORY'
        self.assertTrue(suites.baseline_errors(broken, result))

    def test_reference_upgrade_preserves_locked_inputs_and_regression_checks(self):
        old_lock = dict(schema=1, ruby_version='4.0.9',
                        ruby_source_sha='3e93b23afcec3433f6aecc34b5d832799d754238',
                        sources=[dict(name='fixture', sha='original')])
        new_lock = dict(old_lock, ruby_version='4.0.10',
                        ruby_source_sha='a704b7cd95a42cc0cf5f307137bf3aac0285b915')
        digest = lambda lock: hashlib.sha256((json.dumps(lock, indent=2) + '\n').encode()).hexdigest()
        row = dict(gem='fixture', file='test.rb', classification='MATCH',
                   reference=self.side(), mere=self.side())
        old = dict(rows=[row], lock_sha256=digest(old_lock), platform='Darwin', reference_version='4.0.9')
        new = dict(old, lock_sha256=digest(new_lock), reference_version='4.0.10')
        self.assertEqual(suites.baseline_errors(new, old, new_lock), [])
        changed = copy.deepcopy(new_lock)
        changed['sources'][0]['sha'] = 'different source'
        with self.assertRaisesRegex(ValueError, 'lock differs'):
            suites.baseline_errors(new, old, changed)
        with self.assertRaisesRegex(ValueError, 'lock differs'):
            suites.baseline_errors(new, old, dict(new_lock, ruby_source_sha='wrong revision'))
        broken = copy.deepcopy(new)
        broken['rows'][0]['classification'] = 'RED'
        self.assertTrue(suites.baseline_errors(broken, old, new_lock))
        self.assertTrue(suites.baseline_errors(dict(new, rows=[]), old, new_lock))
        with self.assertRaisesRegex(ValueError, 'lock differs'):
            suites.baseline_errors(dict(new, reference_version='4.0.11'), old, new_lock)

    def test_untracked_shadow_and_source_mutation_change_digest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'lib').mkdir()
            file = root / 'lib/fixture.rb'
            file.write_text('VALUE = 1\n')
            original = suites.tree(root)
            file.write_text('VALUE = 2\n')
            self.assertNotEqual(original, suites.tree(root))
            file.write_text('VALUE = 1\n')
            (root / 'lib/shadow.rb').write_text('raise "shadow"\n')
            self.assertNotEqual(original, suites.tree(root))

    def test_a_passing_summary_from_another_library_tree_is_rejected(self):
        ruby = shutil.which('ruby')
        self.assertIsNotNone(ruby)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ('locked', 'other'):
                (root / name / 'lib').mkdir(parents=True)
                (root / name / 'lib/probe.rb').write_text('SOURCE_PROBE = true\n')
            for name in ('other', 'locked', 'exit'):
                record = root / (name + '.source.txt')
                env = dict(os.environ, MERE_SUITE_RUBY_LIB=str(root / 'fallback'),
                           MERE_SUITE_SOURCE_ROOT=str(root / 'locked'), MERE_SUITE_SOURCE_RECORD=str(record))
                code = ('require "probe"; ' if name != 'exit' else '') + 'puts "3 runs, 4 assertions, 0 failures, 0 errors, 0 skips"'
                if name == 'exit':
                    code += '; STDOUT.flush; exit! 0'
                result = subprocess.run([ruby, '--disable-gems', '-I', str(root / name / 'lib'),
                                         '-r', str(suites.ROOT / 'gemtest/suite_bootstrap.rb'), '-e', code],
                                        env=env, text=True, capture_output=True)
                measured = dict(exit=result.returncode, limit=None, tally=suites.tally(result.stdout, result.stderr),
                                source_verified=record.exists() and bool(record.read_text().split()))
                self.assertEqual(suites.verdict(self.side(), measured), 'MATCH' if name == 'locked' else 'RED')
                self.assertEqual(record.read_text().strip() if record.exists() else '', 'lib/probe.rb' if name == 'locked' else '')

    def test_child_ruby_uses_the_selected_interpreter_and_locked_libraries(self):
        ruby = str(Path(shutil.which('ruby')).resolve())
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'cache/probe'
            (source / 'lib').mkdir(parents=True)
            (source / 'lib/probe.rb').write_text('CHILD_LIBRARY = "locked"\n')
            fallback = root / 'fallback/lib'
            fallback.mkdir(parents=True)
            (fallback / 'fallback_probe.rb').write_text('CHILD_FALLBACK = "fallback"\n')
            (source / 'test.rb').write_text('''require "probe"
child = IO.popen(["ruby", "--disable-gems", "-e", 'require "probe"; require "fallback_probe"; print CHILD_LIBRARY + CHILD_FALLBACK'], &:read)
abort "wrong child or library" unless child == "lockedfallback" && $?.success?
puts "3 runs, 4 assertions, 0 failures, 0 errors, 0 skips"
''')
            shadow = root / 'shadow'
            shadow.mkdir()
            (shadow / 'ruby').write_text('#!/bin/sh\nexit 23\n')
            (shadow / 'ruby').chmod(0o755)
            output = root / 'output'
            output.mkdir()
            args = SimpleNamespace(cache=root / 'cache', ruby_src=root / 'fallback',
                                   binary=Path(ruby), reference=shadow / 'ruby', verbose=False,
                                   runtime_paths={'mere': suites.call(['sh', str(suites.ROOT / 'tools/runtime_load_path.sh'), ruby]).split(os.pathsep)})
            suite = dict(name='probe', load_sources=['probe'], load_paths=['lib'])
            env = dict(os.environ, PATH=str(shadow) + os.pathsep + os.defpath, LANG='en_US.UTF-8')

            def run(command, environment, log, rss, wall):
                result = subprocess.run(command, env=environment, capture_output=True, timeout=10)
                return dict(exit=result.returncode, limit=None)

            with patch.object(suites, 'supervise', side_effect=run):
                result = suites.run_side(args, suite, 'test.rb', 'mere', env, output, {})
            self.assertEqual(suites.verdict(self.side(), result), 'MATCH',
                             (output / 'mere.stderr').read_text())


if __name__ == '__main__':
    unittest.main()
