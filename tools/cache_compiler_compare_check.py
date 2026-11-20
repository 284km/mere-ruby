#!/usr/bin/env python3
"""Replay a real failed compiler comparison and reject misleading evidence."""
import copy
import json
from pathlib import Path
import unittest

from cache_compiler_compare import assess, method_passed, clearing_only, LEGACY_SOURCE

FIXTURE = json.loads((Path(__file__).parent / 'fixtures/cache_compiler_failure.json').read_text())


class ComparisonEvidence(unittest.TestCase):
    def test_real_failed_prefix_remains_failed(self):
        result = assess(FIXTURE)
        self.assertTrue(result['complete'])
        self.assertTrue(result['candidate_core_passed'])
        self.assertTrue(result['references_passed'])
        self.assertFalse(result['candidate_method_passed'])
        self.assertFalse(result['passed'])

    def test_forged_healthy_flag_does_not_hide_actual_rss(self):
        value = copy.deepcopy(FIXTURE['method_runs'][1])
        value['driver_exit'] = 0
        value['result']['sides']['mere']['healthy'] = True
        self.assertFalse(method_passed(value))

    def test_forged_summary_ratio_does_not_hide_actual_rss(self):
        value = copy.deepcopy(FIXTURE['method_runs'][1])
        value['driver_exit'] = 0
        value['result']['sides']['mere'].update(healthy=True, post_gc_peak_to_initial=1.0)
        self.assertFalse(method_passed(value))

    def test_later_passing_sample_does_not_replace_failed_run(self):
        value = copy.deepcopy(FIXTURE)
        value['method_runs'].pop(1)
        self.assertFalse(assess(value)['complete'])

    def test_old_passing_cases_cannot_be_dropped(self):
        value = copy.deepcopy(FIXTURE)
        cases = value['core_cases']['module-candidate']['parsed']['cases']
        name = next(name for name, state in cases.items() if state == '.')
        cases.pop(name)
        result = assess(value)
        self.assertFalse(result['candidate_core_passed'])
        self.assertIn(name, result['lost_passing_cases']['module'])

    def test_modified_upstream_input_is_rejected(self):
        value = copy.deepcopy(FIXTURE)
        value['core_cases']['clone-candidate']['canonical_input_sha256'] = '0' * 64
        self.assertFalse(assess(value)['candidate_core_passed'])

    def test_missing_reference_control_is_rejected(self):
        value = copy.deepcopy(FIXTURE)
        value['core_cases'].pop('refinement-reference')
        self.assertFalse(assess(value)['complete'])

    def test_missing_post_gc_prefix_is_rejected(self):
        value = copy.deepcopy(FIXTURE['method_runs'][0])
        value['result']['sides']['mere']['samples_kb'].pop(5)
        self.assertFalse(method_passed(value))

    def test_relaxed_memory_bound_is_rejected(self):
        value = copy.deepcopy(FIXTURE['method_runs'][0])
        value['result']['bounds']['post_gc_growth'] = 3.0
        self.assertFalse(method_passed(value))

    def test_equal_but_incomplete_case_inventories_are_rejected(self):
        value = copy.deepcopy(FIXTURE)
        for side in ('reference', 'parent', 'candidate'):
            value['core_cases']['module-' + side]['parsed']['cases'] = {}
        self.assertFalse(assess(value)['candidate_core_passed'])

    def test_different_measured_binary_is_rejected(self):
        value = copy.deepcopy(FIXTURE)
        value['method_runs'][1]['result']['sides']['mere']['binary_sha256'] = '0' * 64
        self.assertFalse(assess(value)['complete'])

    def test_altered_parent_program_is_not_a_comparison(self):
        value = copy.deepcopy(FIXTURE)
        value['method_runs'][0]['program_sha256'] = '0' * 64
        self.assertFalse(assess(value)['complete'])

    def test_only_one_runtime_cannot_be_replaced_by_legacy_source(self):
        value = copy.deepcopy(FIXTURE)
        value['subject_ref'] = LEGACY_SOURCE
        value['source_refs']['parent'] = LEGACY_SOURCE
        self.assertFalse(assess(value)['complete'])

    def test_arbitrary_same_source_is_not_locked_evidence(self):
        value = copy.deepcopy(FIXTURE)
        value['subject_ref'] = '0' * 40
        value['source_refs'] = dict(parent='0' * 40, candidate='0' * 40)
        self.assertFalse(assess(value)['complete'])

    def test_legacy_label_does_not_waive_a_failed_method_prefix(self):
        value = copy.deepcopy(FIXTURE)
        value['subject_ref'] = LEGACY_SOURCE
        value['source_refs'] = dict(parent=LEGACY_SOURCE, candidate=LEGACY_SOURCE)
        result = assess(value)
        self.assertTrue(result['complete'])
        self.assertFalse(result['passed'])
        self.assertFalse(result['candidate_method_passed'])

    def test_instrumented_or_different_c_is_not_a_cache_only_change(self):
        self.assertFalse(clearing_only('int main(void) { return 0; }',
                                       'int main(void) { return 1; }'))


if __name__ == '__main__':
    unittest.main()
