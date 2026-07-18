# Extract (expected, code) pairs from a CRuby bootstraptest file by
# monkey-patching its assertion DSL to record instead of run — no fragile
# text parsing. Writes p<N>.exp / p<N>.rb into the output directory.
#
#   ruby extract.rb <path/to/bootstraptest/test_x.rb> <out_dir>
require 'fileutils'

PAIRS = []
Object.class_eval do
  define_method(:assert_equal)       { |exp, code, *a, **k| PAIRS << [exp.to_s, code] }
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
PAIRS.each_with_index do |(e, c), i|
  File.write("#{out}/p#{i}.exp", e)
  File.write("#{out}/p#{i}.rb", c)
end
puts PAIRS.size
