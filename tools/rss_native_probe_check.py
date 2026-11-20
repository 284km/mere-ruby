#!/usr/bin/env python3
"""Reject incomplete ownership evidence using a captured real sample."""
import json
from pathlib import Path
import re
import unittest

from rss_native_probe import native_samples, emit_probe, policy_observed

FIXTURE = json.loads((Path(__file__).parent / 'fixtures/rss_native_sample.json').read_text())
POLICY = json.loads((Path(__file__).parent / 'fixtures/method_floor_policy.json').read_text())


class NativeEvidence(unittest.TestCase):
    def test_captured_sample_retains_real_ownership(self):
        sample, = native_samples(FIXTURE['raw_sample'])
        self.assertEqual(sample['begin']['rss_kb'], 91052)
        self.assertEqual(sample['end']['retired_capacity'], 17514240)
        self.assertEqual(sample['maps']['meths_g']['rows'], 1255)
        self.assertTrue(sample['pins'])
        self.assertTrue(all(pin['root'] == 1 for pin in sample['pins']))

    def test_truncated_sample_is_not_evidence(self):
        with self.assertRaises(ValueError):
            native_samples(FIXTURE['raw_sample'].rsplit('RSS_NATIVE_END', 1)[0])

    def test_missing_saved_pinner_is_not_complete(self):
        raw = re.sub(r'^RSS_NATIVE_PIN[^\n]*\n', '', FIXTURE['raw_sample'], count=1, flags=re.M)
        with self.assertRaises(ValueError):
            native_samples(raw)

    def test_wrong_pinner_arena_is_rejected(self):
        raw = re.sub(r'^(RSS_NATIVE_PIN sample=0 arena=)0 ', r'\g<1>999 ',
                     FIXTURE['raw_sample'], count=1, flags=re.M)
        with self.assertRaises(ValueError):
            native_samples(raw)

    def test_missing_current_method_table_is_rejected(self):
        raw = re.sub(r'^RSS_NATIVE_MAP sample=0 name=meths_g[^\n]*\n', '',
                     FIXTURE['raw_sample'], flags=re.M)
        with self.assertRaises(ValueError):
            native_samples(raw)

    def test_unavailable_rss_is_not_a_real_measurement(self):
        with self.assertRaises(ValueError):
            native_samples(FIXTURE['raw_sample'].replace('rss_kb=91052', 'rss_kb=-1'))

    def test_absent_native_observer_is_rejected(self):
        with self.assertRaises(ValueError):
            native_samples('RSS 0 91052\nMETHOD_COPY_LIFETIME_COMPLETE\n')

    def test_duplicate_observation_is_rejected(self):
        with self.assertRaises(ValueError):
            native_samples(FIXTURE['raw_sample'] * 2)

    def test_changed_native_runtime_must_not_omit_hooks(self):
        with self.assertRaises(ValueError):
            emit_probe('int main(void) { return 0; }')

    def test_real_policy_observation_is_accounted(self):
        samples = native_samples(POLICY['raw_parent_first_sample'])
        self.assertTrue(policy_observed(samples))
        self.assertEqual(samples[0]['policy']['calls'], 6)
        self.assertEqual(samples[0]['policy']['requested'], 2)
        self.assertEqual(POLICY['parent_final_policy']['raised_without_move'], 4)
        self.assertEqual(POLICY['candidate_final_policy']['raised_without_move'], 0)

    def test_historical_capture_does_not_establish_new_policy_evidence(self):
        self.assertFalse(policy_observed(native_samples(FIXTURE['raw_sample'])))

    def test_invalid_policy_accounting_is_rejected(self):
        raw = POLICY['raw_parent_first_sample'].replace('moved=1 deferred=1', 'moved=9 deferred=1')
        with self.assertRaises(ValueError):
            native_samples(raw)


if __name__ == '__main__':
    unittest.main()
