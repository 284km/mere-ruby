# Round 27 of note 545 (stage 10): Coverage. A file required while coverage
# is set up is covered: its lines are counted where TracePoint's :line fires
# (nil where none can), its methods by their calls -- an alias's for its
# original -- under their definition's first and last line and column. The
# measurement starts, suspends, resumes, peeks, clears and stops as ruby's.
require "coverage"
require "tmpdir"

src = <<~'RUBY'
  def foo; end
  def bar
    1.times do
      foo
    end
  end
   def baz; end
  class K
    def m = :m
    alias n m
    def self.s = nil
  end
  define_method(:dm) {}
  f = proc {}
  define_method(:dp, &f)

  foo
  bar
  K.new.n
  K.new.m
  dm
  dm
RUBY

p Coverage.supported?(:lines), Coverage.supported?(:all), Coverage.state
p((Coverage.result rescue $!.message), (Coverage.resume rescue $!.message))
p((Coverage.start(lines: true, oneshot_lines: true) rescue $!.message))

Dir.mktmpdir do |dir|
  path = File.join(dir, "covered.rb")
  File.write(path, src)
  Coverage.setup(lines: true, methods: true)
  p Coverage.state, Coverage.running?
  Coverage.resume
  require path
  r = Coverage.peek_result[path]
  p r[:lines]
  p r[:methods].sort_by { |k, _| k.drop(1) }
  bar
  p Coverage.peek_result[path][:lines][0, 6]
  Coverage.suspend
  bar
  p Coverage.state, Coverage.peek_result[path][:lines][0, 6]
  Coverage.resume
  p Coverage.result(stop: false, clear: true)[path][:lines][0, 6]
  p Coverage.peek_result[path][:lines][0, 6], Coverage.peek_result.frozen?
  p Coverage.result.size, Coverage.state

  # oneshot lines: each line once, in the order first run
  path2 = File.join(dir, "oneshot.rb")
  File.write(path2, "a = 1\nif a == 2\n  :no\nelse\n  :yes\nend\nb = 2\n")
  Coverage.start(oneshot_lines: true)
  load path2
  p Coverage.result[path2]

  # the compatible mode is the bare Array; an eval given a file name counts
  # with eval: true, numbered from the line it was given
  Coverage.start
  load path2
  p Coverage.result[path2]
  Coverage.start(eval: true, lines: true)
  eval("x = 1\nx += 1\nx\n", binding, "evaled.rb", -1)
  p Coverage.result["evaled.rb"]
  p Coverage.line_stub(path2)
end

# a proc handed to define_method is where the proc was written
pr = proc {}
define_method(:from_proc, &pr)
p method(:from_proc).source_location[1] == __LINE__ - 2
# an object whose #inspect answers itself, inside a container
class Shown < String; def inspect = self; end
p [Shown.new("bare")], { Shown.new("k") => 1 }
# an eval numbered from below 1 tells TracePoint its own numbers
lines = []
TracePoint.new(:line) { |t| lines << t.lineno if t.path == "neg.rb" }.enable do
  eval("1\n2\n3\n", binding, "neg.rb", -1)
end
p lines.first(2)
