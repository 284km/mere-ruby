#!/usr/bin/env python3
"""Regressions for inspected names, interleaved output and interrupted runs."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import transcript as tr


class TranscriptCheck(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='mere-ruby-transcript-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def parse(self, data, code=0, name='stdout'):
        path = self.root / name
        path.write_bytes(data.encode() if isinstance(data, str) else data)
        return tr.parse(path, code)

    def passing(self, name='stdout'):
        return self.parse('[1/1] Example#test_ok = 0.01 s\n'
                          '1 tests, 1 assertions, 0 failures, 0 errors, 0 skips\n', name=name)

    def test_quoted_symbols_and_spaced_report_names_are_the_same_cases(self):
        result = self.parse('[1/2] Example#"test_a-b" = 0.01 s\n'
                            '[2/2] Example#"test_has spaces" = 0.01 s\n'
                            '  1) Skipped:\nExample#test_a-b [test.rb:2]:\noptional\n'
                            '2 tests, 1 assertions, 0 failures, 0 errors, 1 skips\n')
        self.assertEqual(result['state'], 'COMPLETE')
        self.assertEqual(result['cases'], {'Example#test_a-b': 'S', 'Example#test_has spaces': '.'})

    def test_inline_cargo_style_diagnostics_do_not_extend_a_case_name(self):
        result = self.parse('[1/1] Example#test_cargo["error: workspace mismatch\\n" +\n'
                            ' "details"]\n = 0.01 s\n'
                            '  1) Error:\nExample#test_cargo:\nRuntimeError: workspace\n'
                            '1 tests, 0 assertions, 0 failures, 1 errors, 0 skips\n', 1)
        self.assertEqual(result['state'], 'COMPLETE')
        self.assertEqual(result['cases'], {'Example#test_cargo': 'E'})

    def test_bare_test_method_and_known_header_with_clipped_location(self):
        result = self.parse('[1/1] Example#test = 0.01 s\n'
                            '  1) Skipped:\nExample#test [HOME\noptional\n'
                            '1 tests, 0 assertions, 0 failures, 0 errors, 1 skips\n')
        self.assertEqual(result['state'], 'COMPLETE')
        self.assertEqual(result['cases'], {'Example#test': 'S'})

    def test_escaped_quotes_unicode_and_binary_symbol_bytes(self):
        for token, raw in [(b'"test_quoted\\\"name"', b'test_quoted"name'),
                           (b'"test_\\u{1F600}"', 'test_😀'.encode()),
                           (b'"test_\\xFF"', b'test_\xff'),
                           (b'"test_literal\\\\xFF"', b'test_literal\\xFF')]:
            with self.subTest(token=token):
                data = (b'[1/1] Example#' + token + b' = 0.01 s\n'
                        b'  1) Failure:\nExample#' + raw + b':\nfailed\n'
                        b'1 tests, 1 assertions, 1 failures, 0 errors, 0 skips\n')
                result = self.parse(data, 1)
                self.assertEqual(result['state'], 'COMPLETE')
                self.assertEqual(result['cases'], {tr.identity(b'Example#' + raw): 'F'})
        self.assertNotEqual(tr.identity(b'Example#test_\xff'), tr.identity(b'Example#test_\\xff'))

    def test_unrecognized_failure_header_cannot_become_a_pass(self):
        result = self.parse('[1/1] Example#test_ok = 0.01 s\n'
                            '  1) Failure:\nmissing header\nfailed\n'
                            '1 tests, 1 assertions, 1 failures, 0 errors, 0 skips\n', 1)
        self.assertEqual(result['state'], 'REPORT_MISMATCH')
        self.assertEqual(result['cases']['Example#test_ok'], 'X')

    def test_missing_exit_and_missing_summary_cannot_become_passes(self):
        result = self.passing()
        path = self.root / 'stdout'
        self.assertEqual(tr.parse(path, None)['cases']['Example#test_ok'], 'X')
        result = self.parse('[1/1] Example#test_ok = 0.01 s\n', 137)
        self.assertEqual(result['state'], 'INCOMPLETE')
        self.assertEqual(result['cases']['Example#test_ok'], 'X')

    def test_summary_and_exit_inconsistencies_remain_visible(self):
        self.passing()
        self.assertEqual(tr.parse(self.root / 'stdout', 139)['state'], 'EXIT_ERROR')
        result = self.parse('[1/2] Example#test_one = 0.01 s\n'
                            '2 tests, 0 assertions, 0 failures, 0 errors, 0 skips\n')
        self.assertEqual(result['state'], 'COUNT_MISMATCH')
        self.assertEqual(result['cases']['Example#test_one'], 'X')

    def test_long_diagnostic_lines_are_discarded_in_bounded_chunks(self):
        data = (b'[1/1] Example#test_ok["' + b'x' * (tr.LINE_BYTES * 3)
                + b'"]\n = 0.01 s\n1 tests, 1 assertions, 0 failures, 0 errors, 0 skips\n')
        result = self.parse(data)
        self.assertEqual(result['state'], 'COMPLETE')
        self.assertEqual(result['cases'], {'Example#test_ok': '.'})

    def test_input_and_case_limits_never_silently_complete(self):
        data = b'[1/1] Example#test_ok["' + b'x' * 4096 + b'"]\n'
        with patch.object(tr, 'INPUT_BYTES', 1024):
            result = self.parse(data)
        self.assertEqual(result['state'], 'PARSE_LIMIT')
        self.assertIn('input_limit', result['issues'])
        with patch.object(tr, 'CASE_LIMIT', 1):
            result = self.parse('[1/2] Example#test_one = 0.01 s\n[2/2] Example#test_two = 0.01 s\n'
                                '2 tests, 0 assertions, 0 failures, 0 errors, 0 skips\n')
        self.assertEqual(result['state'], 'PARSE_LIMIT')
        self.assertEqual(result['discovered'], 1)
        with patch.object(tr, 'PARSE_SECONDS', 0):
            result = self.passing()
        self.assertEqual(result['state'], 'PARSE_LIMIT')
        self.assertEqual(result['issues'], ['time_limit'])

    def test_large_unterminated_recovery_input_has_bounded_peak_memory(self):
        worker = '''import json, resource, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import transcript
result = transcript.parse(Path(sys.argv[2]), None)
scale = 1024 if sys.platform == "darwin" else 1
print(json.dumps(dict(rss_kb=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / scale,
                      state=result["state"], issues=result["issues"], cases=result["discovered"])))
'''
        samples = []
        for size_mb in (8, 128):
            source = self.root / f'{size_mb}.stdout'
            with source.open('wb') as stream:
                stream.write(b'[1/1] Example#test_ok["')
                block = b'x' * 65536
                for _ in range(size_mb * 16):
                    stream.write(block)
            output = subprocess.check_output([sys.executable, '-c', worker, str(Path(tr.__file__).parent),
                                              str(source)], text=True, timeout=15)
            samples.append(json.loads(output))
        print('Transcript peak RSS KiB (8/128 MiB input): ' + json.dumps(samples), file=sys.stderr)
        self.assertLess(samples[1]['rss_kb'] - samples[0]['rss_kb'], 16 * 1024, samples)
        self.assertEqual(samples[1]['state'], 'PARSE_LIMIT')
        self.assertEqual(samples[1]['issues'], ['input_limit'])
        self.assertTrue(all(sample['cases'] == 1 for sample in samples))

    def test_snapshot_validation_refuses_bad_verdicts_and_oversized_input(self):
        result = self.passing()
        path = self.root / 'side.json'
        tr.save(path, result)
        self.assertEqual(tr.load(path), result)
        result['cases']['Example#test_ok'] = 'PASS'
        tr.save(path, result)
        with self.assertRaises(ValueError):
            tr.load(path)
        with patch.object(tr, 'SNAPSHOT_BYTES', 64):
            with self.assertRaises(ValueError):
                tr.load(path)

    def test_phase_switch_does_not_reuse_reference_stdout_as_mere_output(self):
        reference = self.passing('0.ref.stdout')
        tr.save(self.root / '0.ref.json', reference)
        pair = tr.recover(self.root, 0, 'mere', 'MEMORY_LIMIT')
        self.assertEqual(pair[0]['state'], 'COMPLETE')
        self.assertEqual(pair[1]['state'], 'MEMORY_LIMIT')
        self.assertEqual(pair[1]['cases'], {})
        counts, tags = tr.compare(*pair)
        self.assertEqual(counts, dict(tests=1, match=0, red=1, both=0, extra=0))
        self.assertIn('ABSENT', tags)

    def test_completed_reference_is_recovered_if_killed_before_snapshot_write(self):
        self.passing('0.ref.stdout')
        (self.root / '0.ref.exit').write_text('0\n')
        pair = tr.recover(self.root, 0, 'ref', 'WALL_LIMIT')
        self.assertEqual(pair[0]['state'], 'COMPLETE')
        self.assertEqual(pair[1]['state'], 'NOT_RUN')
        self.assertEqual(tr.compare(*pair)[0]['tests'], 1)

    def test_interrupted_mere_summary_requires_a_saved_exit_status(self):
        tr.save(self.root / '0.ref.json', self.passing('0.ref.stdout'))
        self.passing('0.mere.stdout')
        pair = tr.recover(self.root, 0, 'mere', 'WALL_LIMIT')
        self.assertEqual(pair[1]['state'], 'WALL_LIMIT')
        self.assertEqual(tr.compare(*pair)[0]['match'], 0)
        (self.root / '0.mere.exit').write_text('0\n')
        pair = tr.recover(self.root, 0, 'mere', 'WALL_LIMIT')
        self.assertEqual(pair[1]['state'], 'COMPLETE')
        self.assertEqual(tr.compare(*pair)[0]['match'], 1)


if __name__ == '__main__':
    unittest.main()
