# Extract (expected, code) pairs from a CRuby bootstraptest file by
# monkey-patching its assertion DSL to record instead of run — no fragile
# text parsing. Writes p<N>.exp / p<N>.rb into the output directory.
#
#   ruby extract.rb <path/to/bootstraptest/test_x.rb> <out_dir>
require 'fileutils'

PAIRS = []
Object.class_eval do
  define_method(:assert_equal) do |exp, code, *a, **k|
    # Some tests fix the frozen-string mode. The kwarg (a source magic-comment
    # default) wins over the positional CLI flag when both are given; otherwise
    # the positional "--enable/--disable-frozen-string-literal" applies. Emit
    # the effective flag so run.sh can pass it to mere-ruby.
    flag = if k.key?(:frozen_string_literal)
             k[:frozen_string_literal] ? "--enable-frozen-string-literal" : "--disable-frozen-string-literal"
           else
             a.find { |x| x.is_a?(String) && x.start_with?("--") }
           end
    PAIRS << [exp.to_s, code, flag]
  end
  define_method(:assert_normal_exit) { |*a, **k| }
  define_method(:assert_match)       { |*a, **k| }
  define_method(:assert_not_match)   { |*a, **k| }
  define_method(:assert_valid_syntax){ |*a, **k| }
  define_method(:assert_finish)      { |*a, **k| }
  define_method(:assert)             { |*a, **k| }
  define_method(:flunk)              { |*a, **k| }
end

out = ARGV[1] || "pairs"
FileUtils.mkdir_p(out)
begin
  load ARGV[0]
rescue Exception => e
  warn "load warning: #{e.class}: #{e.message}"
end
PAIRS.each_with_index do |(e, c, flag), i|
  File.write("#{out}/p#{i}.exp", e)
  File.write("#{out}/p#{i}.rb", c)
  File.write("#{out}/p#{i}.flags", flag) if flag
end
puts PAIRS.size
