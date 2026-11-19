#!/usr/bin/env python3
"""Replay captured transcripts through the real CLI to check coverage identity.

Only source/build preflight and subprocess execution are fixtures. Transcript
parsing, case acceptance, input comparison and persisted differences are real.
These controls do not execute or measure an interpreter.
"""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import module_rss_compare as compare

FIXTURE = json.loads((Path(__file__).parent / 'fixtures/module_rss_replay.json').read_text())


class ComparisonCheck(unittest.TestCase):
    def replay(self, replacement_mode=None):
        with tempfile.TemporaryDirectory(prefix='module-rss-replay-') as name:
            root = Path(name).resolve()
            binaries = {}
            for side in ('reference', 'main', 'pr90'):
                folder = root / side
                folder.mkdir()
                binaries[side] = folder / 'mere-ruby'
                binaries[side].write_text('replay fixture; never executed\n')
                (folder / '.build_mode').write_text('O2\n')
            source, compiler = root / 'source', root / 'compiler'
            test = source / 'test/ruby/test_module.rb'
            test.parent.mkdir(parents=True)
            test.write_text('source preflight fixture; transcripts are captured separately\n')
            executable = compiler / '_build/default/bin/mere.exe'
            executable.parent.mkdir(parents=True)
            executable.write_text('compiler preflight fixture; never executed\n')
            refs = {source: compare.RUBY_REF, compiler: compare.COMPILER_REF,
                    binaries['main'].parent: compare.BASE_REF,
                    binaries['pr90'].parent: compare.CANDIDATE_REF}
            output = root / 'output'
            observed_parses = {}

            def git(folder, *args):
                if args == ('rev-parse', 'HEAD'):
                    return refs[folder]
                self.assertEqual(args, ('diff', '--exit-code', 'HEAD', '--',
                                        '*.mere', '*.c', '*.h', 'tools/build.sh'))
                return ''

            def runtime(command, **options):
                self.assertEqual(command[:2], ['sh', str(compare.ROOT / 'tools/runtime_load_path.sh')])
                return '/fixture/runtime/lib'

            def supervise(command, env, log, rss, seconds):
                self.assertEqual((rss, seconds), (2097152, 600))
                side = Path(command[0]).parent.name
                mode = 'observed_original_case' if '-n' in command else 'complete_file'
                text = ''.join(FIXTURE[mode + '_lines'])
                if side == 'pr90' and mode == replacement_mode:
                    original = ('test_complemented_method_entry_memory_leak'
                                if mode == 'observed_original_case'
                                else 'test_uninitialized_instance_variable')
                    text = text.replace('TestModule#' + original,
                                        'TestModule#test_replay_replacement', 1)
                log.write_text(text)
                if mode == 'observed_original_case':
                    Path(env['MODULE_RSS_CAPTURE_INPUT']).write_text(
                        ''.join(FIXTURE['observed_child_input_lines']))
                # Parse the real replay stream before the CLI makes its decision.
                observed_parses[(mode, side)] = compare.transcript.parse(log, 0)
                return dict(exit=0, peak_rss_kb=1024, seconds=0.01, limit=None)

            argv = ['module_rss_compare.py', '--baseline', str(binaries['main']),
                    '--candidate', str(binaries['pr90']), '--reference', str(binaries['reference']),
                    '--ruby-src', str(source), '--compiler-root', str(compiler),
                    '--output', str(output)]
            with patch.object(compare, 'git', side_effect=git), \
                    patch.object(compare, 'TEST_SHA', compare.ci.digest(test)), \
                    patch.object(compare.subprocess, 'check_output', side_effect=runtime), \
                    patch.object(compare.ci, 'supervise', side_effect=supervise), \
                    patch.object(compare.sys, 'argv', argv), \
                    patch.dict(compare.os.environ), contextlib.redirect_stdout(io.StringIO()):
                status = compare.main()
            return status, json.loads((output / 'result.json').read_text()), observed_parses

    def test_matching_captured_files_are_accepted(self):
        status, result, _ = self.replay()
        self.assertEqual(status, 0)
        self.assertTrue(result['observed_inputs_equal_except_upstream_token'])
        self.assertTrue(all(value['passed'] for value in result['cases'].values()))

    def test_equal_full_file_counts_cannot_hide_a_replaced_case(self):
        self.check_replacement('complete_file', 'test_uninitialized_instance_variable', 195)

    def test_equal_selected_counts_cannot_hide_a_replaced_case(self):
        self.check_replacement('observed_original_case', 'test_complemented_method_entry_memory_leak', 1)

    def check_replacement(self, mode, original, count):
        status, result, parsed = self.replay(mode)
        before, after = parsed[(mode, 'reference')], parsed[(mode, 'pr90')]
        self.assertEqual((before['state'], after['state']), ('COMPLETE', 'COMPLETE'))
        self.assertEqual(before['summary'], after['summary'])
        self.assertEqual(before['discovered'], count)
        self.assertEqual(after['discovered'], count)
        self.assertEqual(status, 1)
        value = result['cases'][mode + '-pr90']
        self.assertFalse(value['passed'])
        self.assertEqual(value['case_differences_from_reference'], dict(
            missing=['TestModule#' + original], extra=['TestModule#test_replay_replacement'], different={}))
        self.assertIn('TestModule#test_replay_replacement', value['cases'])


if __name__ == '__main__':
    unittest.main()
