# A Method made of a class's BUILTIN class method -- Class#new, #allocate,
# Module#name -- runs that builtin after the class writes its own: the
# Method does not find the new body again. rspec-support's ReentrantMutex is
# `NEW_MUTEX_METHOD = Mutex.method(:new)` under `def self.new =
# NEW_MUTEX_METHOD.call`, which recursed to a SystemStackError.
class M < ::Mutex
  NM = M.method(:new)
  def self.new = NM.call
end
m = M.new
p m.class
m.synchronize { p [m.locked?, m.owned?] }
p m.locked?

$calls = []
class A
  NM = method(:new)
  NA = method(:allocate)
  NN = method(:name)
  attr_reader :args, :blk
  def initialize(*a, &b) = (@args = a; @blk = b)
  def self.new(*a, &b) = ($calls << :new; NM.call(*a, &b))
  def self.allocate = ($calls << :allocate; NA.call)
  def self.name = ($calls << :name; "A!" + NN.call)
end
a = A.new(1, 2) { :blk }
p [a.class, a.args, a.blk.call]
p A.new(3).args
p A.allocate.class
p A.name
p A::NM.(4).args
p $calls

# ...and a subclass inherits the override, the Method still builds an A
class B < A; end
p B.new(5).class, B.new(6).args
p $calls.size

# ...and an alias of the builtin taken in the singleton class
class C; end
class << C
  alias newobj new
  def new = [:own, newobj]
end
r = C.new
p [r[0], r[1].class]
class D
  def initialize(x) = (@x = x)
  attr_reader :x
end
class << D
  alias newobj new
  def new(x) = newobj(x * 2)
end
p D.new(21).x

# ...and the builtin's own #initialize may build an object whose class has its
# own `new`: that one runs (the skip is for the one dispatch only)
class E
  def self.new(*) = :e_own
end
class F
  NM = method(:new)
  attr_reader :e
  def initialize = (@e = E.new)
  def self.new = [:f_own, NM.call]
end
f = F.new
p [f[0], f[1].class, f[1].e]
