# A block made into a Proc again and again is one body, found by the number
# the parser gives it rather than by comparing the trees (blk_intern). What
# has to hold is everything that reads the mark carrying that number beside
# the block's line: Proc#source_location, a backtrace's line, __LINE__, the
# lines a TracePoint reports -- and that a body with a Float literal, which
# was compared unequal to itself and added again for every Proc, is one
# body like any other.
def keep(&b) = b

procs = 3.times.map { keep { |x| x * 2 } }
p procs.map { |pr| pr.call(4) }, procs.map(&:source_location).uniq.size, procs[0].source_location[1]
p procs.map(&:arity), procs.map(&:lambda?), procs.map(&:parameters).uniq

lines = []
2.times do
  pr = keep do
    lines << __LINE__
    caller(0, 1)[0][/:(\d+):/, 1].to_i
  end
  lines << pr.call
end
p lines

floats = 5.times.map { keep { 0.5 + 1.5 } }
p floats.map(&:call), floats.map(&:source_location).uniq.size

# a block written on one line beside another: two bodies, two numbers
a, b = keep { :first }, keep { :second }
p a.call, b.call, a.source_location == b.source_location

# the same block text, read twice by eval: two blocks
src = "keep { |v| v + 1 }"
e1 = eval(src)
e2 = eval(src)
p e1.call(1), e2.call(2), e1.source_location, e2.source_location

# lambdas, define_method, and a block that raises
l = 2.times.map { ->(n) { n.fdiv(4) } }
p l.map { |f| f.call(2) }, l[0].lambda?
class Dm
  [1, 2].each { |i| define_method(:"m#{i}") { i * 10 } }
end
p Dm.new.m1, Dm.new.m2, Dm.instance_method(:m1).source_location[1]
2.times do |t|
  begin
    keep { raise "boom #{t}" }.call
  rescue => err
    p [err.message, err.backtrace[0][/:(\d+):/, 1].to_i]
  end
end

seen = []
tp = TracePoint.new(:b_call) { |t| seen << t.lineno }
pr = keep { :traced }
tp.enable { 2.times { pr.call } }
p seen
