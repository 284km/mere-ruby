# Every frame a backtrace names, and its label: a method is 'Owner#name', a
# block is 'block in X' (or 'block (N levels) in X') after where it was
# WRITTEN, a class body is '<class:K>', and a builtin is a frame too -- named
# after the class or module that defines it, which is not always the
# receiver's class ('Kernel#then' on an Integer, 'Enumerable#inject' on an
# Array, with the Array's own each under it).
def m1 = caller(0)
def m2 = [1].map { [2].each { return caller(0) } }
class K
  X = caller(0)
  def im = yield
  def self.cm = caller(0, 2)
  define_method(:dm) { caller(0, 2) }
  class << self
    Y = caller(0, 1)
  end
end
module Mo
  def self.mm = caller_locations(0, 1).map(&:label)
end
pr = proc { caller(0, 1) }
la = -> { caller(0, 1) }
p m1, m2, K::X, K.singleton_class::Y
p K.new.im { caller(0, 2) }
p K.cm, K.new.dm, Mo.mm
p pr.call, la.call, la.(), la[]
def lm = -> { caller(0, 2) }.call
p lm
p 1.then { caller(0, 2) }
p 3.times.to_a.each_slice(2).to_a.then { caller(0, 1) }
p [1].inject(0) { caller(0) }
# (these answer the receiver, so the frames are kept from inside the block)
f = nil
{a: 1}.each { f = caller(0) }; p f
(1..1).each { f = caller(0) }; p f
1.upto(1) { f = caller(0) }; p f
"a".each_char { f = caller(0) }; p f
[1].sort_by { f = caller(0) }; p f
[1].each_with_index { f = caller(0) }; p f

# A builtin that refuses is the top frame of what it raised, at the line of
# the call; Kernel#raise is not a frame, and neither is a method that does not
# exist.
def conv(s) = Integer(s)
begin; Integer("z"); rescue => e; p e.backtrace; end
begin; [1].each { Integer("z") }; rescue => e; p e.backtrace, e.backtrace_locations.map(&:label); end
begin; conv("z"); rescue => e; p e.backtrace; end
begin; {}.fetch(:k); rescue => e; p e.backtrace; end
begin; raise "x"; rescue => e; p e.backtrace; end
begin; 1.nope; rescue => e; p e.backtrace; end
begin; Integer("z"); rescue; end
begin; raise "after a rescued refusal"; rescue => e; p e.backtrace; end

# A fiber's and a thread's stack start at the block that is their body.
p Fiber.new { caller(0) }.resume
p Thread.new { caller(0) }.value
p Fiber.new { [1].map { caller(0) } }.resume
