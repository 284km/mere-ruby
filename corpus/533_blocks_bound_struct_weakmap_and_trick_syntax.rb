# A frame's block is not the block of a builtin iterator it calls: a method
# called through `&:sym` or a `|x, &b|` parameter sees no block.
class Integer; def bg? = block_given?; end
def g = [1].map(&:bg?)
p g { }, g
def g2 = [1].map { |x, &b| b }
p g2 { }
def k = [1].map { block_given? }
p k { }
def y = [1].map { yield }
p y { 5 }

# A singleton #instance_variables_to_inspect is reached by a bare call from a
# module method (pp's pretty_print_instance_variables).
module IvarHook
  def shown = respond_to?(:instance_variables_to_inspect) ? instance_variables_to_inspect : instance_variables
end
class Object; include IvarHook; end
o = Object.new
def o.instance_variables_to_inspect = [:@b]
o.instance_eval { @a = 1; @b = 2 }
p o.shown, Object.new.shown

# Struct's own methods bound to a struct answer from its members, even when a
# member of the same name replaced the method.
S1 = Struct.new(:a, :b)
s1 = S1.new(1, 2)
p Struct.instance_method(:members).bind_call(s1), Struct.instance_method(:size).bind_call(s1)
S2 = Struct.new(:members, :class, :size)
s2 = S2.new(1, 2, 3)
p s2.members, s2.size
p Struct.instance_method(:members).bind_call(s2)
p Struct.instance_method(:size).bind_call(s2), Struct.instance_method(:to_a).bind_call(s2)
p s2[:members], s2[:class], s2[2], s2.to_h, s2.dig(:size)

# The table pp keeps of what it is printing is the one #inspect consults.
a = []
a << a.dup
key = Thread.current[:__recursive_key__] = {}.compare_by_identity
key[:inspect] = {}.compare_by_identity
key[:inspect][a] = true
p a.inspect
key[:inspect].delete(a)
p a.inspect
Thread.current[:__recursive_key__] = nil

# A class's alias of a builtin comes before a module's method of that name,
# for method(:name) and for a bare call alike (tsort's tsort_each_node).
module EachNode
  def each_node = raise(NotImplementedError)
  def via_method = method(:each_node).call { |x| print x, " " }
  def via_bare = each_node { |x| print x, " " }
end
class NodeHash < Hash; include EachNode; alias each_node each_key; end
h = NodeHash[{ 1 => 2, 3 => 4 }]
h.via_method; h.via_bare; puts
p h.method(:each_node).owner

# Exception#== asks an object of another class for its #exception.
e = RuntimeError.new("boom")
class AsException; def initialize(e) = @e = e; def exception(*) = @e; end
p e == AsException.new(e), e == AsException.new(RuntimeError.new("other")), e == Object.new

# ObjectSpace::WeakMap keeps entries by identity; WeakKeyMap is no WeakMap.
wm = ObjectSpace::WeakMap.new
k1 = "key"; k2 = "key"; v = Object.new
wm[k1] = v
p wm.key?(k1), wm.key?(k2), wm[k1].equal?(v), wm.size, wm.keys == [k1]
wm[k2] = nil
p wm.size, wm.include?(k2), wm[k2]
p wm.delete(k2), wm.size, wm.delete(:nope) { |x| [:missing, x] }
wm.each { |kk, vv| p [kk, vv.equal?(v)] }
p ObjectSpace::WeakKeyMap.superclass, ObjectSpace::WeakKeyMap.instance_methods(false).sort

# Kernel#select with no arguments is an ArgumentError, bare or called.
begin; select; rescue ArgumentError => x; p x.message; end
begin; select(); rescue ArgumentError => x; p x.message; end

# An op-assign as an expression declares its local, as the statement does.
p(z1 ||= 5)
p [z2 ||= 7, z2]

# After `..`, a local followed by ` -1` is the subtraction, not a call.
n = 3
p((0..n -1).to_a, (0...n -1).to_a)

# Array#* truncates a Float count.
p [1, 2] * 2.9
begin; [1] * -1.5; rescue ArgumentError => x; p x.message; end

# Braces inside a %-literal in an interpolation are text.
p "#{%@a}b@[1]}", "#{%q(a}b)}", /#{%@x}@}|y/.source

# A backslash at the end of a line inside a double-quoted string continues it.
p "ab\
cd"
w = "W"
p "#{w}\
x#{w}"

# RbConfig::MAKEFILE_CONFIG names the site directories under site_ruby.
p RbConfig::MAKEFILE_CONFIG["sitelibdir"] =~ /(?:\$\(|\/)site/ ? :site : :other
