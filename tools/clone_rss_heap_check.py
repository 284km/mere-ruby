#!/usr/bin/env python3
"""Reject incomplete heap evidence using a captured original-program trace."""
import json
from pathlib import Path
import re
import unittest

from clone_rss_heap import heap_samples
from rss_native_probe import native_samples

FIXTURE = json.loads((Path(__file__).parent / 'fixtures/clone_heap_sample.json').read_text())


class HeapEvidence(unittest.TestCase):
    def parse(self, raw):
        return heap_samples(raw, native_samples(raw))

    def test_complete_capture_keeps_region_names_with_spaces(self):
        rows = self.parse(FIXTURE['raw'])
        self.assertEqual(len(rows), 4)
        calls = [r for r in rows[2]['active'] if r['site'] == 'region MCALL']
        self.assertTrue(any(r['capacity'] == 16777216 and r['allocated'] == 0 for r in calls))

    def test_missing_final_allocator_sample_is_rejected(self):
        raw = re.sub(r'^RSS_HEAP sample=3[^\n]*\n', '', FIXTURE['raw'], flags=re.M)
        with self.assertRaises(ValueError):
            self.parse(raw)

    def test_missing_cache_block_is_rejected(self):
        raw = re.sub(r'^RSS_REGION sample=2 kind=cache[^\n]*\n', '', FIXTURE['raw'], count=1, flags=re.M)
        with self.assertRaises(ValueError):
            self.parse(raw)

    def test_missing_active_region_is_rejected(self):
        raw = re.sub(r'^RSS_ACTIVE sample=2[^\n]*\n', '', FIXTURE['raw'], count=1, flags=re.M)
        with self.assertRaises(ValueError):
            self.parse(raw)

    def test_duplicate_active_region_is_rejected(self):
        line = next(s for s in FIXTURE['raw'].splitlines() if s.startswith('RSS_ACTIVE sample=2 '))
        with self.assertRaises(ValueError):
            self.parse(FIXTURE['raw'] + line + '\n')

    def test_duplicate_allocator_observation_is_rejected(self):
        line = next(s for s in FIXTURE['raw'].splitlines() if s.startswith('RSS_HEAP sample=2 '))
        with self.assertRaises(ValueError):
            self.parse(FIXTURE['raw'] + line + '\n')

    def test_missing_capacity_cannot_hide_in_the_region_name(self):
        raw = re.sub(r'^(RSS_ACTIVE sample=2[^\n]*?) capacity=\d+', r'\1', FIXTURE['raw'], count=1, flags=re.M)
        with self.assertRaises(ValueError):
            self.parse(raw)


if __name__ == '__main__':
    unittest.main()
