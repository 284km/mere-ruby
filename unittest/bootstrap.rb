# frozen_string_literal: true

# These files rely on libraries loaded earlier by the upstream whole-suite
# runner. Keep the standalone prerequisites explicit and identical per side.
module MereRubyTestBootstrap
  PRELOADS = {
    "fiber/test_io_buffer.rb" => %w[tempfile],
    "fiber/test_scheduler.rb" => %w[tmpdir],
    "objspace/test_objspace.rb" => %w[tempfile],
    "open-uri/test_ssl.rb" => %w[tmpdir],
    "ruby/test_enum.rb" => %w[delegate],
    "ruby/test_eval.rb" => %w[tmpdir],
    "ruby/test_defined.rb" => %w[rubygems/path_support],
    "ruby/test_settracefunc.rb" => %w[fileutils tmpdir],
    "ruby/test_yjit.rb" => %w[tempfile],
    "ruby/test_zjit.rb" => %w[tempfile tmpdir],
    "ruby/test_io_timeout.rb" => %w[socket],
  }.freeze

  PRELOADS.fetch(ENV["UNITTEST_TEST_FILE"], []).each { |library| require library }
end

# RubyGems' tests request test-unit 3, where an unqualified assert_raise accepts
# any exception. The already-loaded ruby-core runner instead treats its empty
# expected-class list as a mismatch. Bridge only that API difference for gem
# tests, retaining explicit class checks and the core runner's skip handling.
if ENV.fetch("UNITTEST_TEST_FILE", "").start_with?("rubygems/")
  module MereRubyGemAssertionContract
    def assert_raise(*expected, &block)
      if expected.empty? || (expected.size == 1 && String === expected[0])
        assert_raise_kind_of(Exception, *expected, &block)
      else
        super
      end
    end
  end
  Test::Unit::TestCase.prepend(MereRubyGemAssertionContract)
end
