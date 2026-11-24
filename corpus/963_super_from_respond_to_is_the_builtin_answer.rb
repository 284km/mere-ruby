# `super` from an object's own #respond_to? is Kernel#respond_to?: a private
# method answers only with include_all, a protected one likewise, and
# #respond_to_missing? is asked for a name nobody defines. It used to answer
# "is there such a method at all", so every class whose respond_to? calls
# super said true for its private methods. ActiveRecord::Core defines a
# private #to_ary returning nil -- that is how Array.wrap(record) and
# flatten keep a record whole -- and every record has ActiveModel's
# respond_to? override: `Array.wrap(record)` called the private method and
# got NoMethodError 'to_ary'.
module Core
  def pub = 1
  protected def prot = 2
  private
  def to_ary = nil
  def helper = 3
end
module AM
  def respond_to?(m, include_private = false)
    if super then true
    elsif !include_private && super(m, true) then false
    else m.to_s.start_with?("attr_")
    end
  end
  alias :respond_to_without_attributes? :respond_to?
end
module AR
  def respond_to?(name, include_private = false)
    return false unless super
    true
  end
end
class Rec; include Core; include AM; include AR; end
r = Rec.new
[:to_ary, :helper, :prot, :pub, :nope].each do |n|
  p [n, r.respond_to?(n), r.respond_to?(n, true), r.respond_to_without_attributes?(n)]
end
m = r.method(:respond_to?)
while m
  p [m.owner, m.call(:to_ary), m.call(:to_ary, true)]
  m = m.super_method
end
p Kernel.instance_method(:respond_to?).bind_call(r, :to_ary)

# the forms of the call: zsuper, explicit arguments, a rest parameter
class Z1; def respond_to?(m, ip = false) = super; private def h = 1; end
class Z2; def respond_to?(m, ip = false) = super(m, ip); private def h = 1; end
class Z3; def respond_to?(m, *rest) = super; private def h = 1; end
class Z4; def respond_to?(*) = super; private def h = 1; def to_str = "s"; end
p [Z1, Z2, Z3, Z4].map { |k| [k.new.respond_to?(:h), k.new.respond_to?(:h, true), k.new.respond_to?(:to_s)] }

# respond_to_missing? is asked through the super, with the flag given
class Z5
  def respond_to?(m, ip = false) = super
  def respond_to_missing?(m, ip) = (m == :ghost) || (m == :hidden && ip) || super
end
z = Z5.new
p z.respond_to?(:ghost), z.respond_to?(:hidden), z.respond_to?(:hidden, true), z.respond_to?(:none)
begin
  Class.new { def respond_to?(*a) = super(*a, 1, 2) }.new.respond_to?(:x)
rescue ArgumentError => e
  p e.message
end

# what it is for: a record-like object stays whole
def wrap(o) = o.respond_to?(:to_ary) ? (o.to_ary || [o]) : [o]
p wrap(r).size, [[r]].flatten.size, Array(r).size
a, b = r
p a.equal?(r), b
