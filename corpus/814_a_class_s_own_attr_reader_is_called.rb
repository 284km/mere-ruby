# A class's own attr_reader / attr_writer / attr_accessor / attr -- on its
# singleton class, in a module it was extended with or one prepended to the
# singleton -- is called however the call is written: in the class body, in
# a block there, through send, with self, in Module.new's block. Its super
# reaches Module's, which defines the methods public whatever the body's
# `private` says (the default visibility is the calling frame's, the
# override's) and fires method_added for each. (thor's `def attr_reader(*)
# = no_commands { super }`, which a Rails command class calls in a block.)
$log = []
module CM
  def nc; yield; end
  def attr_reader(*a) = ($log << [:r, a]; nc { super })
  def attr_writer(*a)
    $log << [:w, a]
    super
  end
  def attr_accessor(*a) = ($log << [:rw, a]; super(*a))
  def attr(*a) = ($log << [:attr, a]; super)
end
class B
  extend CM
  attr_reader :d1, :d2
  attr_writer :w1
  attr_accessor :a1
  self.attr :t1
  nc { attr_reader :blk; attr_accessor :blk2 }
  [1].each { attr_writer :each_w }
  send(:attr_reader, :sent)
  self.attr_accessor :expl
  private
  attr_reader :priv_r
  attr_accessor :priv_a
  public
  attr_reader "str"
end
p $log
p B.public_instance_methods(false).sort, B.private_instance_methods(false).sort
b = B.new; b.a1 = 3; p b.a1, (b.priv_r rescue $!.class)

# def self., a singleton class body, and one that does not call super
class C
  def self.attr_reader(*a) = (super; :c_own)
  class << self
    def attr_writer(*a) = :no_super
  end
  X = attr_reader(:x)
  Y = (attr_writer :y)
  attr_accessor :z
end
p C::X, C::Y, C.instance_methods(false).sort

# prepended to the singleton class, and the builtin's answer through super
module P
  def attr_accessor(*a) = [:p, super]
end
class D
  singleton_class.prepend(P)
  R = attr_accessor(:m, :n)
end
p D::R, D.instance_methods(false).sort

# Module.new and Class.new with a block; a module's own
m = Module.new do
  def self.attr_reader(*a) = [:mod, super]
  V = attr_reader(:q)
end
p m.instance_methods(false), V
k = Class.new(B) { attr_reader :sub_r }
p k.instance_methods(false), $log.last

# the hook sees each method, inside the override's super
class E
  def self.method_added(n) = ($log2 ||= []) << n
  def self.attr_accessor(*a) = ($log2 << :enter; r = super; $log2 << :leave; r)
  $log2 = []
  attr_accessor :h1
  attr_reader :h2
end
p $log2

# no override: nothing changes
class F; attr_reader :a; private; attr_accessor :b; end
p F.public_instance_methods(false), F.private_instance_methods(false).sort
