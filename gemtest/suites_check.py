"""Negative controls for coverage, classification, and locked source integrity."""
import copy
import tempfile
from pathlib import Path
import unittest

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


if __name__ == '__main__':
    unittest.main()
