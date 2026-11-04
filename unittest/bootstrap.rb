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
