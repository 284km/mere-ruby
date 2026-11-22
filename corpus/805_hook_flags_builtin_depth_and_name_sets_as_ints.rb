# What the interpreter now asks as ints rather than by hashing a string: a
# TracePoint's being on (hook_bits slot 0), a builtin class's method_missing
# (slot 1), the depth of the builtin running (bi_reg_d), a builtin name's
# index (bi_nix's memo), a class's lookup generation (mro_now_class) and the
# sets of mutating and operator names. Each is turned on, off and on again,
# and asked through the doors that read it.
def m(x) = x + 1

events = []
tp = TracePoint.new(:call, :return) { |t| events << [t.event, t.method_id] }
tp.enable
m(1)
tp.disable
m(2)
tp.enable { m(3) }
m(4)
p events
p tp.enabled?

# a method_missing on a builtin class (slot 1)
p((1.zork rescue $!.class))
class Integer
  def method_missing(n, *a) = n == :zork ? [:mm, self] : super
end
p 1.zork
p((1.other rescue $!.class))

# frozen receivers and mutating names: frozen asked first, same answers
s = "abc".freeze
p((s << "d" rescue $!.class))
p((s.upcase! rescue $!.class))
p s.upcase
a = [1, 2].freeze
p((a.push(3) rescue $!.message))
p a.map { |x| x * 2 }
h = {k: 1}.freeze
p((h.store(:j, 2) rescue $!.class))
p((h.delete(:k) rescue $!.class))
p "a-b".delete("-")

# the builtin's depth: a lambda's own arity error inside a builtin, a rescue
# inside one, and the builtin a NoMethodError names
l = ->(x, y) { x + y }
p(([1, 2].map(&l) rescue $!.class))
p([[1, 2]].map { |x, y| x + y })
p([1, 2, 3].each_slice(2).map { |q| begin; q.fetch(5); rescue IndexError; :caught; end })
p((nil.foo rescue $!.message))
p [3, 1, 2].sort_by { |x| -x }

# builtin names asked over and over, colliding in the memo
v = []
200.times { |i| v << [i.to_s, i.succ, [i].size, {i => i}.key?(i)].size }
p v.uniq

# an anonymous class's own lookup generation
c = Class.new(Array)
o = c.new([1, 2])
p o.length
c.class_eval { def length = :own }
p o.length
d = Class.new(c)
p d.new([1]).length
c.class_eval { remove_method :length }
p d.new([1]).length

# operator and binary names
p 1.respond_to?(:+), [1].respond_to?(:<<), 1.method(:<=>).arity
p [[1, 2], [3]].sum([]), (1 <=> 2), (2 ** 10)
