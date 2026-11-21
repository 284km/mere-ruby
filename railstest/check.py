#!/usr/bin/env python3
"""Check that missing tests, altered inputs and inherited gems cannot pass."""
import importlib.util
import os
import json
import shutil
import subprocess
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
        self.assertEqual('--disable-gems -r' + str(measure.ROOT / 'bootstrap.rb'), env['RUBYOPT'])
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

    def test_extension_child_keeps_declared_stdlib_as_fallback(self):
        reference = Path(os.environ.get('REF_RUBY_BIN') or shutil.which('ruby')).resolve()
        env = measure.clean_environment()
        bootstrap = measure.ROOT / 'bootstrap.rb'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fallback, explicit = root / 'fallback', root / 'explicit'
            fallback.mkdir()
            explicit.mkdir()
            (fallback / 'monitor.rb').write_text('raise "foreign monitor wrapper selected"\n')
            (fallback / 'intake_priority.rb').write_text('raise "fallback displaced explicit source"\n')
            (explicit / 'intake_priority.rb').write_text('puts "explicit-source-ok"\n')
            env['RAILS_SMOKE_RUBY_LIB'] = str(fallback)
            command = [str(reference), '--disable-gems', '-I' + str(fallback), '-I' + str(explicit)]
            script = ('require "monitor"; puts "monitor-ok"; require "intake_priority"; '
                      'abort "RubyGems not initialized" unless defined?(Gem::VERSION)')
            failed = subprocess.run(command + ['-e', script], env=env, capture_output=True, text=True, timeout=10)
            self.assertNotEqual(0, failed.returncode)
            self.assertIn('foreign monitor wrapper selected', failed.stderr)
            result = subprocess.run(command + ['-r' + str(bootstrap), '-e', script],
                                    env=env, capture_output=True, text=True, timeout=10)
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            self.assertEqual('monitor-ok\nexplicit-source-ok\n', result.stdout)
            # Automatic RubyGems startup runs before a -r bootstrap. Exercise
            # the real inherited RUBYOPT contract with default CLI settings too.
            env['RUBYOPT'] = measure.environment(root / 'gems', root / 'app', str(fallback),
                                                   root / 'user', None)['RUBYOPT']
            actual_child = [str(reference), '-I' + str(fallback), '-I' + str(explicit), '-e', script]
            result = subprocess.run(actual_child, env=env, capture_output=True, text=True, timeout=10)
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            self.assertEqual('monitor-ok\nexplicit-source-ok\n', result.stdout)
            env.pop('RUBYOPT')
            stdlib = subprocess.check_output([str(reference), '--disable-gems', '-rrbconfig', '-e',
                                              'print RbConfig::CONFIG.fetch("rubylibdir")'],
                                             env=env, text=True, timeout=10)
            env['RAILS_SMOKE_RUBY_LIB'] = stdlib
            own = [str(reference), '--disable-gems', '-I' + str(explicit)]
            script = 'puts $LOAD_PATH'
            expected = subprocess.check_output(own + ['-rrubygems', '-e', script], env=env, text=True, timeout=10)
            actual = subprocess.check_output(own + ['-r' + str(bootstrap), '-e', script],
                                              env=env, text=True, timeout=10)
            self.assertEqual(expected, actual)

    def test_actual_entry_point_ignores_foreign_ruby_startup(self):
        reference = Path(os.environ.get('REF_RUBY_BIN') or shutil.which('ruby')).resolve()
        control_env = {k: v for k, v in os.environ.items()
                       if not k.startswith(('BUNDLE_', 'RBENV_'))
                       and k not in ('RUBYOPT', 'RUBYLIB', 'GEM_HOME', 'GEM_PATH', 'RUBYGEMS_GEMDEPS')}
        version = subprocess.check_output([str(reference), '--disable-gems', '-e', 'print RUBY_VERSION'],
                                          text=True, env=control_env, timeout=10)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / '.git').symlink_to(measure.REPO / '.git',
                                      target_is_directory=(measure.REPO / '.git').is_dir())
            harness = root / 'railstest'
            app = harness / 'app'
            app.mkdir(parents=True)
            for name in ('measure.py', 'bootstrap.rb'):
                shutil.copy(measure.ROOT / name, harness / name)
            (root / 'unittest').symlink_to(measure.REPO / 'unittest', target_is_directory=True)
            for name in ('Gemfile', 'Gemfile.lock'):
                shutil.copy(measure.ROOT / 'app' / name, app / name)
            archives = root / 'archives'
            archives.mkdir()
            archive = archives / 'bundler-4.0.20.gem'
            archive.write_bytes(b'not a gem: stop before any real install')
            data = dict(schema=1, ruby_version=version, rails_version='8.1.4.1',
                        inputs={n: measure.sha(app / n) for n in ('Gemfile', 'Gemfile.lock')},
                        packages=[dict(file=archive.name, sha256=measure.sha(archive))])
            (harness / 'archives.lock.json').write_text(json.dumps(data))
            binary = root / 'mere-ruby'
            binary.write_text('#!/bin/sh\nexit 99\n')
            binary.chmod(0o755)
            (root / '.build_mode').write_text('O2\n')
            foreign = root / 'foreign.Gemfile'
            foreign.write_text('source "https://rubygems.org"\nruby "0.0.1"\n')
            for index, rubyopt in enumerate(('-rforeign', '-rbundler/setup')):
                with self.subTest(RUBYOPT=rubyopt):
                    output = root / ('run-' + str(index))
                    env = dict(control_env, RUBYOPT=rubyopt, RUBYLIB=str(root / 'foreign'),
                               BUNDLE_GEMFILE=str(foreign), BUNDLE_WITHOUT='test')
                    result = subprocess.run([sys.executable, str(harness / 'measure.py'), 'measure',
                                             '--archives', str(archives), '--reference', str(reference),
                                             '--binary', str(binary), '--output', str(output)],
                                            env=env, capture_output=True, text=True, timeout=30)
                    self.assertEqual(2, result.returncode, result.stdout + result.stderr)
                    record = json.loads((output / 'results.json').read_text())
                    self.assertEqual(version, record['ruby_version'])
                    self.assertEqual('REFERENCE_UNAVAILABLE', record['state'])
                    self.assertEqual('FAIL', record['sides']['reference']['bundler']['state'])
                    self.assertEqual('NOT_RUN', record['sides']['reference']['dependencies']['state'])
                    error = (output / 'reference/bundler.stderr').read_text()
                    self.assertNotIn('RubyVersionMismatch', error)
                    self.assertNotIn('cannot load such file -- foreign', error)


if __name__ == '__main__':
    unittest.main()
