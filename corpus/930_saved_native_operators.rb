# A native operator saved by alias_method and called from a Ruby wrapper of
# the same name -- the shape of ActiveSupport's core_ext/time/calculations.rb:
#   alias_method :compare_without_coercion, :<=>
#   alias_method :<=>, :compare_with_coercion
# Every Time comparison in a Rails app went through that and said
# "unknown operator: <=>".

def try
  yield
rescue => e
  "#{e.class}: #{e.message}"
end

# 1. a saved operator before anything redefines the name
class Time
  alias_method :saved_cmp, :<=>
  alias_method :saved_eq, :==
  alias_method :saved_plus, :+
  alias_method :saved_minus, :-
  alias_method :saved_lt, :<
end
t1 = Time.at(1)
t2 = Time.at(2)
p try { t1.saved_cmp(t2) }, try { t2.saved_cmp(t1) }, try { t1.saved_cmp(Time.at(1)) }
p try { t1.saved_eq(Time.at(1)) }, try { t1.saved_eq(t2) }
p try { t1.saved_plus(10).to_i }, try { t2.saved_minus(t1) }, try { t2.saved_minus(1).to_i }
p try { t1.saved_lt(t2) }, try { t1.saved_cmp(5) }

# 2. the wrapper: the new #<=> reaches the old one, and only once
class Time
  CALLS = []
  def compare_with_coercion(other)
    CALLS << :wrapper
    other = other.to_time if other.respond_to?(:to_time) && !other.is_a?(Time)
    saved_cmp(other)
  end
  alias_method :<=>, :compare_with_coercion
end
p t1 <=> t2, t2 <=> t1, t1 <=> Time.at(1)
p Time::CALLS.size
p [t2, t1, Time.at(0)].sort.map(&:to_i)
p [t2, t1].max.to_i, [t2, t1].min.to_i
p t1.saved_cmp(t2)
p t1.method(:saved_cmp).call(t2)
p t1.send(:saved_cmp, t2)

# 3. a wrapper that calls the saved operator under a redefined #==
class Time
  def ==(other)
    other.is_a?(Time) ? saved_eq(other) : false
  end
end
p t1 == Time.at(1), t1 == t2, t1 == 1

# 4. values whose comparisons are not arith_bin's
class Float
  alias_method :saved_cmp, :<=>
  def <=>(other) = saved_cmp(other)
end
class Integer
  alias_method :saved_cmp, :<=>
  alias_method :saved_eq, :==
end
class String
  alias_method :saved_cmp, :<=>
end
class Rational
  alias_method :saved_cmp, :<=>
  alias_method :saved_plus, :+
end
class Complex
  alias_method :saved_eq, :==
  alias_method :saved_plus, :+
end
p 1.5 <=> 2, 2.5.saved_cmp(2), 1.saved_cmp(2), 3.saved_eq(3), "a".saved_cmp("b")
p Rational(1, 2).saved_cmp(1), Rational(1, 2).saved_plus(1), Complex(1, 2).saved_eq(Complex(1, 2)), Complex(1, 2).saved_plus(1)
p [3.5, 1.5, 2.5].sort

# 5. nothing redefines the name: the native call must not leave a bypass for a
#    nested call of the same name on another object that does redefine it
class Box
  include Comparable
  attr_reader :v
  def initialize(v) = @v = v
  def <=>(other) = (@@seen += 1; v <=> other.v)
  @@seen = 0
  def self.seen = @@seen
end
class Array
  alias_method :saved_cmp, :<=>
end
p [Box.new(1)].saved_cmp([Box.new(2)]), Box.seen
p [Box.new(3)].saved_cmp([Box.new(2)]), Box.seen

# 6. a builtin's Method of an object's operator is the native one too
t3 = Time.at(3)
p t3.method(:saved_cmp).call(Time.at(4)), t3.method(:saved_eq).call(Time.at(3))
p Time.instance_method(:saved_plus).bind_call(t3, 1).to_i
u = Time.at(5)
p u.method(:to_i).call, Time.instance_method(:year).bind_call(u)
p t3.method(:<).call(Time.at(4)), t3.method(:-).call(Time.at(1)), Time.instance_method(:>=).bind_call(t3, Time.at(3))

# 7. Comparable's operators ask the program's #<=> (ruby's Time#< is
#    Comparable#<), by operator and by name, and do not go round
class Time
  def <=>(other)
    CALLS << :again
    saved_cmp(other)
  end
end
n = Time::CALLS.size
p t1 < t2, t2 > t1, t1 <= t1, t1 >= t2, t1.send(:<, t2), t1.public_send(:>=, t1)
p Time::CALLS.size - n
p t1.between?(Time.at(0), t2), t2.clamp(t1, t1).to_i

# 8. an Object-level operator saved on a user class, then redefined
class Plainish
  alias_method :saved_eq, :==
  alias_method :saved_ne, :!=
  alias_method :saved_case, :===
  def ==(other) = :mine
end
pl = Plainish.new
p try { pl.saved_eq(pl) }, try { pl.saved_eq(Plainish.new) }, try { pl.saved_ne(pl) }
p try { pl.saved_case(pl) }, try { pl.saved_case(1) }

# 9. ActiveSupport also saves Time#eql? and puts its own in front
class Time
  alias_method :eql_without_coercion, :eql?
  def eql_with_coercion(other) = eql_without_coercion(other)
  alias_method :eql?, :eql_with_coercion
end
p try { Time.at(1).eql?(Time.at(1)) }, try { Time.at(1).eql?(Time.at(2)) }
p try { [Time.at(1), Time.at(1), Time.at(2)].uniq.size }, try { { Time.at(1) => :one }[Time.at(1)] }

# 10. a refinement of the saved name does not answer for the saved builtin
module RefineCmp
  refine Time do
    def <=>(other) = 7
  end
end
using RefineCmp
p try { Time.at(5).saved_cmp(Time.at(9)) }, try { Time.at(5) <=> Time.at(9) }
