#!/usr/bin/env python3
"""Keep failures, input identity and every resource prefix in iclass replay."""
import copy
import json
from pathlib import Path
import unittest

from iclass_resource_assess import assess, CASE

CAPTURE = json.loads((Path(__file__).resolve().parents[1] / 'bench/iclass_resource_r88.json').read_text())


class ReplayEvidence(unittest.TestCase):
    def test_captured_original_case_is_complete(self):
        self.assertTrue(assess(CAPTURE)['passed'])

    def test_larger_child_timeout_is_rejected(self):
        data = copy.deepcopy(CAPTURE)
        data['bounds']['child_seconds'] = 11
        self.assertFalse(assess(data)['passed'])

    def test_changed_source_is_rejected(self):
        data = copy.deepcopy(CAPTURE)
        data['source_ref'] = '0' * 40
        self.assertFalse(assess(data)['passed'])

    def test_modified_child_input_is_rejected(self):
        data = copy.deepcopy(CAPTURE)
        data['selected'][2]['canonical_input_sha256'] = '0' * 64
        self.assertFalse(assess(data)['passed'])

    def test_missing_trial_is_rejected(self):
        data = copy.deepcopy(CAPTURE)
        data['selected'].pop()
        self.assertFalse(assess(data)['passed'])

    def timeout(self, row):
        row['execution']['exit'] = row['usage']['exit'] = 1
        row['parsed']['cases'][CASE] = 'E'
        row['parsed']['summary'] = dict(tests=1, assertions=0, failures=0, errors=1, skips=0)

    def test_candidate_timeout_cannot_become_success(self):
        data = copy.deepcopy(CAPTURE)
        self.timeout(data['selected'][2])
        data['candidate_selected_passed'] = True
        self.assertFalse(assess(data)['passed'])

    def test_failed_parent_control_is_retained(self):
        data = copy.deepcopy(CAPTURE)
        self.timeout(data['selected'][1])
        self.assertTrue(assess(data)['passed'])
        self.assertEqual(data['selected'][1]['parsed']['cases'][CASE], 'E')

    def test_missing_cpu_observation_is_rejected(self):
        data = copy.deepcopy(CAPTURE)
        data['selected'][2]['usage'] = None
        self.assertFalse(assess(data)['passed'])

    def test_lost_module_case_is_rejected(self):
        data = copy.deepcopy(CAPTURE)
        data['module']['repair']['parsed']['cases'].pop(next(iter(data['module']['repair']['parsed']['cases'])))
        self.assertFalse(assess(data)['passed'])

    def test_failed_method_prefix_cannot_become_success(self):
        data = copy.deepcopy(CAPTURE)
        side = data['method']['repair']['result']['sides']['mere']
        side['samples_kb'][8][1] = side['samples_kb'][0][1] * 3
        side['post_gc_peak_to_initial'] = 3.0
        side['healthy'] = True
        self.assertFalse(assess(data)['passed'])

    def test_missing_method_prefix_is_rejected(self):
        data = copy.deepcopy(CAPTURE)
        data['method']['repair']['result']['sides']['mere']['samples_kb'].pop()
        self.assertFalse(assess(data)['passed'])

    def test_missing_before_method_pair_is_rejected(self):
        data = copy.deepcopy(CAPTURE)
        del data['method']['before']
        self.assertFalse(assess(data)['complete'])
        self.assertFalse(assess(data)['passed'])

    def test_before_method_reference_failure_is_rejected(self):
        data = copy.deepcopy(CAPTURE)
        pair = data['method']['before']
        pair['driver_exit'] = 1
        side = pair['result']['sides']['reference']
        side['execution']['exit'] = 1
        side['healthy'] = False
        side['samples_kb'][8][1] = side['samples_kb'][0][1] * 3
        side['post_gc_peak_to_initial'] = 3.0
        result = assess(data)
        self.assertTrue(result['complete'])
        self.assertFalse(result['reference_passed'])
        self.assertFalse(result['passed'])

    def test_before_reference_forged_health_cannot_hide_prefix_growth(self):
        data = copy.deepcopy(CAPTURE)
        side = data['method']['before']['result']['sides']['reference']
        side['samples_kb'][8][1] = side['samples_kb'][0][1] * 3
        side['post_gc_peak_to_initial'] = 3.0
        self.assertFalse(assess(data)['reference_passed'])
        self.assertFalse(assess(data)['passed'])

    def test_before_reference_resource_limit_is_rejected(self):
        data = copy.deepcopy(CAPTURE)
        data['method']['before']['result']['sides']['reference']['execution']['limit'] = 'WALL_LIMIT'
        self.assertFalse(assess(data)['passed'])

    def test_before_method_evidence_is_required(self):
        for change in ['program', 'bounds', 'mere_prefix', 'reference_prefix']:
            with self.subTest(change=change):
                data = copy.deepcopy(CAPTURE)
                pair = data['method']['before']
                if change == 'program':
                    pair['program_sha256'] = '0' * 64
                elif change == 'bounds':
                    pair['result']['bounds']['post_gc_growth'] = 3.0
                else:
                    side = 'mere' if change == 'mere_prefix' else 'reference'
                    pair['result']['sides'][side]['samples_kb'].pop()
                self.assertFalse(assess(data)['complete'])
                self.assertFalse(assess(data)['passed'])

    def test_failed_before_interpreter_with_healthy_reference_is_retained(self):
        data = copy.deepcopy(CAPTURE)
        pair = data['method']['before']
        pair['driver_exit'] = 1
        side = pair['result']['sides']['mere']
        side['healthy'] = False
        side['samples_kb'][8][1] = side['samples_kb'][0][1] * 3
        side['post_gc_peak_to_initial'] = 3.0
        self.assertTrue(assess(data)['passed'])

    def test_native_hosted_capture_is_complete(self):
        self.assertTrue(assess(CAPTURE['hosted_native_validation']['result'])['passed'])


if __name__ == '__main__':
    unittest.main()
