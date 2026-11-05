#!/usr/bin/env python3
"""Exercise the real worker with competing native/shim extensions and children."""
import json
import os
import shlex
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import ci
import harness_check
from ci_check import FixtureFamily

REAL_RUBY = os.environ.get('UNITTEST_REAL_RUBY')
REAL_TOOL_LIB = os.environ.get('UNITTEST_REAL_TOOL_LIB')


@unittest.skipUnless(REAL_RUBY and REAL_TOOL_LIB, 'set real Ruby and Test::Unit paths')
class NativeReferenceCheck(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix='mere-native-reference-')
        cls.addClassCleanup(cls.build.cleanup)
        folder = Path(cls.build.name)
        (folder / 'probe.c').write_text('''#include "ruby.h"
static VALUE value(VALUE self) { return rb_str_new_cstr("native"); }
void Init_reference_probe(void) {
    VALUE mod = rb_define_module("NativeReferenceProbe");
    rb_define_singleton_method(mod, "value", value, 0);
}
''')
        subprocess.run([REAL_RUBY, '-rmkmf', '-e', 'create_makefile("reference_probe")'],
                       cwd=folder, capture_output=True, check=True, timeout=20)
        subprocess.run(['make'], cwd=folder, capture_output=True, check=True, timeout=30)
        extension = subprocess.check_output([REAL_RUBY, '-rrbconfig', '-e',
                                            'print RbConfig::CONFIG.fetch("DLEXT")'], text=True)
        cls.extension = folder / ('reference_probe.' + extension)

    def setUp(self):
        fixture = harness_check.HarnessCheck()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        self.fixture, self.root = fixture, fixture.root
        shutil.copytree(REAL_TOOL_LIB, self.root / 'src/tool/lib', dirs_exist_ok=True)
        for name in ('reference', 'mere-ruby'):
            (self.root / name).unlink()
            (self.root / name).symlink_to(Path(REAL_RUBY).resolve())
        self.version = subprocess.check_output([REAL_RUBY, '-e', 'print RUBY_VERSION'], text=True)
        (self.root / 'tools/ref_ruby.sh').write_text(
            'REF_RUBY_VERSION=' + shlex.quote(self.version) + '\nREF_RUBY_BIN='
            + shlex.quote(str(self.root / 'reference')) + '\n')
        self.ext = self.root / 'native extensions'
        (self.ext / '-test-').mkdir(parents=True)
        shutil.copyfile(self.extension, self.ext / '-test-' / self.extension.name)
        shim = self.root / 'unittest/shim/-test-/reference_probe.rb'
        shim.parent.mkdir(parents=True)
        shim.write_text('module NativeReferenceProbe; def self.value; "shim"; end; end\n')
        (self.root / 'src/test/ruby/test_reference_probe.rb').write_text('''require '-test-/reference_probe'
require 'socket'
require 'tmpdir'
class TestReferenceProbe < Test::Unit::TestCase
  def test_native_and_child
    expected = ENV['RUBY'] == ENV['MR_BIN'] ? 'shim' : 'native'
    assert_equal(expected, NativeReferenceProbe.value)
    out, status = Open3.capture2e(ENV.fetch('RUBY'), '-r-test-/reference_probe', '-e', 'print NativeReferenceProbe.value')
    assert(status.success?, out)
    assert_equal(expected, out)
    assert_equal(ENV.fetch('RUBY'), EnvUtil.rubybin)
  end
  def test_absolute_file
    assert_equal(File.realpath(__FILE__), __FILE__)
  end
  def test_short_socket_path
    assert_operator(File.join(Dir.tmpdir, 'ruby_test_unix_socket_long_suffix').bytesize, :<, 104)
    Dir.mktmpdir('socket') do |dir|
      server = UNIXServer.new(File.join(dir, 'test.sock'))
      assert(File.socket?(server.path))
      server.close
    end
  end
end
''')

    def measure(self, file='ruby/test_reference_probe.rb'):
        output = self.root / 'result'
        with patch.object(ci, 'ROOT', self.root), patch.object(ci, 'ProcessFamily', FixtureFamily), \
                patch.dict(os.environ, dict(self.fixture.env, REF_RUBY_BIN=str(self.root / 'reference'),
                                            UNITTEST_REF_EXT_PATH=str(self.ext), GITHUB_OUTPUT='', GITHUB_STEP_SUMMARY='')):
            ci.save(self.root / 'plan.json', dict(source_ref='a'*40, mere_ref='b'*40, ruby_ref='c'*40,
                                                 ruby_version=self.version, shards=1, files=[file]))
            ci.save(self.root / 'build.json', dict(source_ref='a'*40, mere_ref='b'*40,
                                                  binary_sha256=ci.digest(self.root / 'mere-ruby'), optimization='O2'))
            ci.save(self.root / 'reference.json', dict(ruby_ref='c'*40, version=self.version,
                                                      binary_sha256=ci.digest(self.root / 'reference')))
            code = ci.run_shard(SimpleNamespace(plan=self.root/'plan.json', build_info=self.root/'build.json',
                                                reference_info=self.root/'reference.json', shard=0,
                                                ruby_src=self.root/'src', output=output, wall=15, rss_kb=2097152))
        self.assertEqual(code, 0)
        return json.loads((output / 'result.json').read_text())['rows'][0]

    def test_native_reference_shim_mere_children_and_absolute_short_paths(self):
        row = self.measure()
        self.assertEqual((row['ref_state'], row['mere_state']), ('COMPLETE', 'COMPLETE'), row)
        self.assertEqual((row['tests'], row['match'], row['red'], row['both'], row['extra']), (3, 3, 0, 0, 0), row)

    def test_path_and_env_shebang_children_use_each_selected_side(self):
        poison = self.root / 'bin/ruby'
        poison.write_text('#!/bin/sh\necho wrong-host-ruby >&2\nexit 93\n')
        poison.chmod(0o755)
        (self.root / 'src/test/ruby/test_path_child.rb').write_text('''require 'open3'
require 'tmpdir'
class TestPathChild < Test::Unit::TestCase
  def test_path_ruby
    expected = ENV['RUBY'] == ENV['MR_BIN'] ? 'shim' : 'native'
    out, status = Open3.capture2e('ruby', '-r-test-/reference_probe', '-e', 'print NativeReferenceProbe.value')
    assert(status.success?, out)
    assert_equal(expected, out)
  end
  def test_env_shebang
    expected = ENV['RUBY'] == ENV['MR_BIN'] ? 'shim' : 'native'
    Dir.mktmpdir do |dir|
      script = File.join(dir, 'fixture')
      File.write(script, "#!/usr/bin/env ruby\\nrequire '-test-/reference_probe'\\nprint NativeReferenceProbe.value\\n")
      File.chmod(0700, script)
      out, status = Open3.capture2e(script)
      assert(status.success?, out)
      assert_equal(expected, out)
    end
  end
end
''')
        row = self.measure('ruby/test_path_child.rb')
        self.assertEqual((row['ref_state'], row['mere_state']), ('COMPLETE', 'COMPLETE'), row)
        self.assertEqual((row['tests'], row['match']), (2, 2), row)

    def test_missing_native_reference_does_not_fall_back_to_mere_shim(self):
        (self.ext / '-test-' / self.extension.name).unlink()
        row = self.measure()
        self.assertEqual((row['ref_state'], row['mere_state']), ('INCOMPLETE', 'COMPLETE'), row)
        self.assertEqual((row['match'], row['extra']), (0, 3))

    def test_standalone_prerequisite_is_loaded_for_both_sides(self):
        (self.root / 'src/test/ruby/test_enum.rb').write_text('''class TestStandalone < Test::Unit::TestCase
  def test_delegate
    assert_equal('hello', SimpleDelegator.new('hello').to_s)
  end
end
''')
        row = self.measure('ruby/test_enum.rb')
        self.assertEqual((row['ref_state'], row['mere_state']), ('COMPLETE', 'COMPLETE'), row)
        self.assertEqual((row['match'], row['red'], row['both']), (1, 0, 0), row)

    def test_source_library_path_is_kept_in_parent_and_child(self):
        (self.root / 'src/lib').mkdir()
        (self.root / 'src/lib/source_fixture.rb').write_text('SOURCE_FIXTURE = "pinned-source"\n')
        (self.root / 'src/test/rubygems').mkdir()
        (self.root / 'src/test/rubygems/test_source.rb').write_text('''require 'source_fixture'
class TestSource < Test::Unit::TestCase
  def test_source
    assert_equal('pinned-source', SOURCE_FIXTURE)
    out, status = Open3.capture2e(ENV.fetch('RUBY'), '-rsource_fixture', '-e', 'print SOURCE_FIXTURE')
    assert(status.success?, out)
    assert_equal('pinned-source', out)
  end
end
''')
        row = self.measure('rubygems/test_source.rb')
        self.assertEqual((row['ref_state'], row['mere_state']), ('COMPLETE', 'COMPLETE'), row)
        self.assertEqual(row['match'], 1, row)

    def test_rake_uses_each_selected_interpreter_with_its_library(self):
        (self.root / 'src/test/ruby/test_rake_command.rb').write_text('''require 'shellwords'
class TestRakeCommand < Test::Unit::TestCase
  def test_rake_command
    command = Shellwords.split(ENV.fetch('rake'))
    assert_equal(ENV.fetch('RUBY'), command.first)
    assert_equal(Gem.bin_path('rake', 'rake'), command.last)
    assert_equal('-I' + File.dirname(command.last) + '/../lib', command[1])
    out, status = Open3.capture2e(*command, '--version')
    assert(status.success?, out)
    assert_match(/rake, version /, out)
  end
end
''')
        row = self.measure('ruby/test_rake_command.rb')
        self.assertEqual((row['ref_state'], row['mere_state']), ('COMPLETE', 'COMPLETE'), row)
        self.assertEqual((row['match'], row['red'], row['both']), (1, 0, 0), row)

    def test_reference_default_gem_activation_in_parent_and_child(self):
        (self.root / 'src/test/ruby/test_default_activation.rb').write_text('''require 'json'
class TestDefaultActivation < Test::Unit::TestCase
  def test_activation
    assert_equal({}, JSON.parse('{}'))
    unless ENV['RUBY'] == ENV['MR_BIN']
      refute_nil(Gem.loaded_specs['json'])
      out, status = Open3.capture2e(ENV.fetch('RUBY'), '-rjson', '-e', "print Gem.loaded_specs.fetch('json').name")
      assert(status.success?, out)
      assert_equal('json', out)
    end
  end
end
''')
        row = self.measure('ruby/test_default_activation.rb')
        self.assertEqual((row['ref_state'], row['mere_state']), ('COMPLETE', 'COMPLETE'), row)
        self.assertEqual((row['match'], row['red'], row['both']), (1, 0, 0), row)

    def test_rake_builder_can_select_its_installed_fixture_gem(self):
        (self.root / 'src/test/rubygems').mkdir()
        (self.root / 'src/test/rubygems/test_gem_ext_rake_builder.rb').write_text('''require 'rubygems/ext'
require 'tmpdir'
require 'fileutils'
class TestRakeFixture < Test::Unit::TestCase
  def test_fixture_selection
    Dir.mktmpdir('rake-fixture') do |home|
      spec = Gem::Specification.new do |s|
        s.name = 'rake'
        s.version = '999.0'
        s.summary = 'fixture'
        s.authors = ['fixture']
        s.executables = ['rake']
        s.files = ['bin/rake']
      end
      FileUtils.mkdir_p(File.join(home, 'specifications'))
      bin = File.join(home, 'gems', spec.full_name, 'bin')
      FileUtils.mkdir_p(bin)
      File.write(File.join(bin, 'rake'), "puts 'selected-fixture-rake'\\n")
      File.write(File.join(home, 'specifications', spec.full_name + '.gemspec'), spec.to_ruby)
      Gem.use_paths(home)
      Gem::Specification.reset
      output = []
      Gem::Ext::RakeBuilder.build('Rakefile', home, output, [], nil, home)
      assert_include(output.join, 'selected-fixture-rake')
    end
  end
end
''')
        row = self.measure('rubygems/test_gem_ext_rake_builder.rb')
        self.assertEqual((row['ref_state'], row['mere_state']), ('COMPLETE', 'COMPLETE'), row)
        self.assertEqual((row['match'], row['red'], row['both']), (1, 0, 0), row)

    def test_gem_assertion_contract_requires_an_exception_and_preserves_typed_checks(self):
        (self.root / 'src/test/rubygems').mkdir()
        (self.root / 'src/test/rubygems/test_assertion_contract.rb').write_text('''class TestGemAssertionContract < Test::Unit::TestCase
  def test_contract
    error = assert_raise { raise ArgumentError, 'any exception' }
    assert_equal(ArgumentError, error.class)
    assert_raise('message') { raise TypeError }
    assert_raise(Test::Unit::AssertionFailedError) { assert_raise {} }
    assert_raise(Test::Unit::AssertionFailedError) { assert_raise(TypeError) { raise ArgumentError } }
    assert_raise(Test::Unit::PendedError) { assert_raise { raise Test::Unit::PendedError, 'keep skip' } }
  end
end
''')
        row = self.measure('rubygems/test_assertion_contract.rb')
        self.assertEqual((row['ref_state'], row['mere_state']), ('COMPLETE', 'COMPLETE'), row)
        self.assertEqual((row['match'], row['red'], row['both']), (1, 0, 0), row)

    def test_core_assertion_contract_is_unchanged(self):
        (self.root / 'src/test/ruby/test_assertion_contract.rb').write_text('''class TestCoreAssertionContract < Test::Unit::TestCase
  def test_contract
    assert_raise(Test::Unit::AssertionFailedError) { assert_raise { raise ArgumentError } }
    assert_raise(Test::Unit::AssertionFailedError) { assert_raise {} }
    assert_raise(ArgumentError) { raise ArgumentError }
  end
end
''')
        row = self.measure('ruby/test_assertion_contract.rb')
        self.assertEqual((row['ref_state'], row['mere_state']), ('COMPLETE', 'COMPLETE'), row)
        self.assertEqual((row['match'], row['red'], row['both']), (1, 0, 0), row)


if __name__ == '__main__':
    unittest.main()
