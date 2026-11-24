# What a required file says of itself is the same on either execution, and
# whether or not the evaluator's parser read it first: its lines and file,
# where its methods, procs and blocks were written, the frames of a
# backtrace through it and what error_highlight points at, its magic
# comments, its __END__, its top-level locals -- and its warnings and its
# syntax errors: a file that does not parse, and one whose regexp literal
# does not, are SyntaxErrors that name the file, and neither is loaded.
require "tmpdir"
dir = Dir.mktmpdir("c816")
w = ->(name, src) { File.write(File.join(dir, name), src); File.join(dir, name) }
short = ->(s) { s.to_s.gsub(dir, "D").gsub(/c816\d*-\d+-\w+/, "D") }

w.("where.rb", <<~'RUBY')
  # frozen_string_literal: true
  $w816 = {line: __LINE__, file: File.basename(__FILE__), dir: File.realpath(__dir__) == File.realpath(File.dirname(__FILE__)), frozen: "lit".frozen?}
  top_local816 = 1
  def w816_plain(a, b = 2, *r, k: 1, &blk)
    [__method__, __LINE__, caller_locations(1, 1)[0].lineno]
  end
  W816_PROC = proc { |x|
    x
  }
  W816_LAM = ->(y) { y }
  class W816
    def one = __LINE__
    def two
      raise ArgumentError, "from two"
    end
    define_method(:three) { __LINE__ }
    attr_reader :four
  end
  def w816_deep = [1].map { |v| W816.new.two }
  def w816_nil(o) = o.foo.bar
  $w816[:heredoc] = <<~TXT.lines.size + __LINE__
    a
    b
  TXT
  $w816[:locals] = binding.local_variables
  $w816[:defined] = [defined?(top_local816), defined?(DATA), defined?(yield), defined?(super)]
  END { puts "end block of where.rb" }
  __END__
  not code: 1 +
RUBY
w.("warn.rb", "def w816_warn\n  h = {a: 1, a: 2}\n  h\nend\n$w816[:warned] = w816_warn\n")
w.("bad.rb", "class W816Bad\n  def m(\n    1 +\n  end\nend\n")
w.("badrx.rb", "W816_RX = /(unclosed/\n")
w.("ret.rb", "$w816[:ret] = 1\nreturn\n$w816[:ret] = 2\n")

require File.join(dir, "where")
p $w816
p w816_plain(1), method(:w816_plain).source_location.then { [File.basename(_1[0]), _1[1]] }, method(:w816_plain).parameters
p W816_PROC.source_location[1], W816_LAM.source_location[1], W816_LAM.lambda?, W816.instance_method(:one).source_location[1]
p W816.new.one, W816.new.three, W816.instance_method(:three).source_location[1], W816.instance_method(:four).source_location[1]
p defined?(top_local816), (binding.local_variables.include?(:top_local816))
begin
  w816_deep
rescue => e
  puts e.backtrace_locations.first(4).map { "#{File.basename(_1.path)}:#{_1.lineno}:#{_1.label}" }
  p e.backtrace.first(2).map(&short)
end
begin
  w816_nil(nil)
rescue NoMethodError => e
  puts short.(e.detailed_message(highlight: false)).lines.first
  p e.backtrace_locations[0].lineno
end

err = $stderr
[["warn", nil], ["bad", SyntaxError], ["badrx", SyntaxError], ["ret", nil]].each do |name, exc|
  rd, wr = IO.pipe; $stderr = wr
  r = begin
    require File.join(dir, name)
  rescue exc || NilClass => x
    [x.class, x.path == File.join(dir, name + ".rb"), x.message[/bad\.rb:\d+/], x.message.include?("unmatched parenthesis")]
  ensure
    $stderr = err; wr.close
  end
  p [name, r, rd.read.lines.map { short.(_1).sub(/\A.*?D\//, "D/") }]
end
p $w816[:warned], $w816[:ret], defined?(W816Bad), defined?(W816_RX)
p $LOADED_FEATURES.grep(/c816/).map { File.basename(_1) }.sort
at_exit { Dir.glob(File.join(dir, "*")).each { File.delete(_1) }; Dir.rmdir(dir) }
