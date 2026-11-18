#!/usr/bin/env python3
"""Check that missing tests, altered inputs and inherited gems cannot pass."""
import importlib.util
import os
from pathlib import Path
import tempfile
import sys
sys.dont_write_bytecode = True
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('rails_measure', Path(__file__).with_name('measure.py'))
measure = importlib.util.module_from_spec(spec)
spec.loader.exec_module(measure)


class MeasurementCheck(unittest.TestCase):
    def test_locked_inputs_and_archives(self):
        data = measure.lock()
        self.assertEqual(69, len(data['packages']))
        self.assertEqual('8.1.4.1', data['rails_version'])
        self.assertEqual({'ruby'}, {p['platform'] for p in data['packages']})
        self.assertEqual({'Gemfile', 'Gemfile.lock'}, set(data['inputs']))

    def test_changed_or_extra_archive_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            file = root / 'one.gem'
            file.write_bytes(b'original')
            data = dict(packages=[dict(file=file.name, sha256=measure.sha(file))])
            measure.verify(root, data)
            file.write_bytes(b'changed')
            with self.assertRaisesRegex(ValueError, 'changed archive'):
                measure.verify(root, data)
            file.write_bytes(b'original')
            (root / 'other.gem').write_bytes(b'extra')
            with self.assertRaisesRegex(ValueError, 'inventory'):
                measure.verify(root, data)

    def test_loaded_shell_environment_is_not_reused(self):
        with patch.dict(os.environ, dict(RUBYOPT='-rforeign', RUBYLIB='/foreign', GEM_PATH='/foreign',
                                        BUNDLE_PATH='/foreign', BUNDLE_WITHOUT='test', RAILS_ENV='production')):
            env = measure.environment(Path('/run/gems'), Path('/run/app'), '/stdlib', Path('/run/user'), None)
        self.assertEqual('/run/gems', env['GEM_PATH'])
        self.assertEqual('/stdlib', env['RAILS_SMOKE_RUBY_LIB'])
        self.assertNotIn('RUBYLIB', env)
        self.assertEqual('-r' + str(measure.ROOT / 'bootstrap.rb'), env['RUBYOPT'])
        self.assertEqual('test', env['RAILS_ENV'])
        self.assertNotIn('BUNDLE_PATH', env)
        self.assertNotIn('BUNDLE_WITHOUT', env)

    def test_zero_summary_or_missing_case_is_not_success(self):
        ok = dict(exit=0, limit=None)
        text = ''.join(name + ' = 0.01 s = .\n' for name in sorted(measure.TESTS))
        summary = '6 runs, 31 assertions, 0 failures, 0 errors, 0 skips\n'
        self.assertTrue(measure.successful('tests', ok, text + summary))
        self.assertFalse(measure.successful('tests', ok, '0 runs, 0 assertions, 0 failures, 0 errors, 0 skips\n'))
        self.assertFalse(measure.successful('tests', ok, text.replace('NoteTest#test_transaction_rollback', 'Unknown#test_other') + summary))
        self.assertFalse(measure.successful('tests', ok, text + summary.replace('0 skips', '1 skips')))
        self.assertFalse(measure.successful('tests', ok, text + summary.replace('31 assertions', '30 assertions')))

    def test_markers_do_not_override_exit_or_resource_failure(self):
        for outcome in [dict(exit=1, limit=None), dict(exit=0, limit='WALL_LIMIT'),
                        dict(exit=0, limit='MEMORY_LIMIT')]:
            self.assertFalse(measure.successful('boot', outcome, 'rails-boot-ok\n'))
        self.assertFalse(measure.successful('boot', dict(exit=0, limit=None), ''))


if __name__ == '__main__':
    unittest.main()
