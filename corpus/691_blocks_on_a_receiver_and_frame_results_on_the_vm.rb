# A call on a receiver with a literal block, which the VM now makes in the
# frame itself (the block's env is the frame, not a scope of it), and what a
# method's or a block's frame leaves, now copied out of the stack's arena
# without a region of the frame's own (LOOP (81)).

# the frame's locals, read and written by the block
s = 0
[1, 2, 3].each { |x| s += x }
p s
t = "a"
%w[b c].each { |w| t = t + w }
p t

# `$~` set in the block is the method's
def m691a
  %w[xa yb].each { |w| w =~ /(.)b/ }
  $1
end
p m691a

# break and next out of the block
p([1, 2, 3].each { |x| break x * 10 if x == 2 })
p [1, 2, 3].map { |x| next 0 if x == 2; x }

# a block-local name shadows the frame's
y = 5
[1].each { |x; y| y = x }
p y

# a block of the Symbol shape and one that is not
p [1, 2].map { |x| x.to_s }
p [1, 2].map { |x| x.to_s + "!" }

# a private method called on a written receiver with a block
class C691
  private def each_p = yield(1)
end
begin
  C691.new.each_p { }
rescue NoMethodError => e
  p e.message
end

# `new` with a block of definitions
p Struct.new(:a) { def b = a * 2 }.new(3).b

# a Proc made in a method that is then removed: its frame and program stay
class K691
  def mk
    v = 7
    proc { v += 1 }
  end
end
pr = K691.new.mk
K691.send(:remove_method, :mk)
GC.start
p pr.call, pr.call

# a method with no block in it, from a file of its own (its own tree),
# removed while its frame waits in a Fiber, and a collection: the frame's
# program is still there when the Fiber goes on
require "tmpdir"
Dir.mktmpdir do |d|
  File.write(File.join(d, "f691.rb"), <<~'R')
    class F691
      def go
        Fiber.yield 1
        i = 0
        s = 0
        while i < 100
          s += i
          i += 1
        end
        s
      end
    end
  R
  require File.join(d, "f691.rb")
end
fb = Fiber.new { F691.new.go }
p fb.resume
F691.send(:remove_method, :go)
GC.start
p fb.resume

# what a method and a block leave, while a :return hook runs Ruby of its own
def big691 = [1, 2, 3].map { |x| "s#{x}" * 3 }
seen = []
tp = TracePoint.new(:return) do |tr|
  next unless tr.method_id == :big691
  a = []
  300.times { |i| a << ("h#{i}" * 40) }
  seen << a.size
end
r = tp.enable { big691 }
p r, seen
p((1..3).map { |i| [i, big691.last] }.last)

# a block's value in a loop on a receiver, many times
acc = 0
20_000.times { |i| acc += [i].map { |z| z * 2 }.first }
p acc
