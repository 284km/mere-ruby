# Round 4 of note 533 (thread, fiber, tracepoint, process): a thread killed
# from a rescue or an ensure clause; TracePoint#parameters inside a :b_call
# hook; a Proc target with no block events; Fiber#raise with nothing; the
# "(X#m gives Y)" refusals; the main script's __dir__ and require_relative
# after a Dir.chdir.
require "tmpdir"
require "rbconfig"

# --- a thread killed while an exception is in flight dies quietly, keeps $!
[-> { begin; raise "x"; ensure; Thread.current.kill; end },
 -> { begin; raise "x"; rescue; Thread.exit; end },
 -> { begin; raise "x"; ensure; begin; Thread.current.kill; ensure; $seen = $!.message; end; end }].each do |body|
  t = Thread.new(&body)
  p [t.join.equal?(t), t.status, t.value]
end
p $seen

# --- TracePoint#parameters in a :b_call hook names the block's parameters
seen = []
tp = TracePoint.new(:b_call) { |t| seen << t.parameters }
tp.enable
[1].each { |a, b| }
proc { |x, y = 1, *z| }.call
->(q, r:) {}.(1, r: 2)
tp.disable
p seen
# ...and a Proc target with none of a block's events cannot be hooked
blk = proc {}
[[:call], [:c_return, :raise], [:b_call]].each do |ev|
  TracePoint.new(*ev) {}.enable(target: blk) { blk.call }
  p [ev, :enabled]
rescue ArgumentError => e
  p [ev, e.message]
end

# --- Fiber#raise with nothing is a RuntimeError with no message
f = Fiber.new { Fiber.yield }
f.resume
begin
  f.raise
rescue => e
  p [e.class, e.message]
end

# --- "(X#m gives Y)" refusals say "to", as rb_convert_type does
o = Object.new
def o.to_a = "s"
def o.to_ary = 1
def o.to_hash = 1
def o.to_int = :sym
def o.to_f = "f"
def o.to_i = "i"
[-> { Queue.new(o) }, -> { Array.try_convert(o) }, -> { Hash.try_convert(o) }, -> { Process.detach(o) },
 -> { Float(o) }, -> { Integer(o) }].each do |c|
  c.call
rescue TypeError => e
  p e.message
end

# --- the main script's __dir__ and require_relative are where it IS, after a
# Dir.chdir away from where it was started
Dir.mktmpdir do |d|
  Dir.mkdir("#{d}/subdir")
  File.write("#{d}/subdir/sibling.rb", "puts 'sibling loaded'\n")
  File.write("#{d}/subdir/main.rb", <<~'RUBY')
    puts __FILE__
    a = __dir__
    Dir.chdir __dir__
    puts a == __dir__
    require_relative 'sibling'
  RUBY
  out = Dir.chdir(d) { IO.popen([RbConfig.ruby, "subdir/main.rb"], err: [:child, :out], &:read) }
  p out
end

# --- ...but an eval's synthetic file name is read against where the program
# is NOW, and it has no absolute_path
Dir.mktmpdir do |d|
  File.write("#{d}/near.rb", "$near = :loaded\n")
  Dir.chdir(d) { p Object.new.instance_eval("require_relative('near')", "foo.rb"), $near }
end
p eval("caller_locations(0)[0].absolute_path", nil, "foo.rb"), eval("caller_locations(0)[0].absolute_path", nil, "foo/bar.rb")

# --- a TracePoint target that is no Method, UnboundMethod or Proc is refused
begin
  TracePoint.new(:call) {}.enable(target: Object.new) {}
rescue ArgumentError => e
  p e.message
end
