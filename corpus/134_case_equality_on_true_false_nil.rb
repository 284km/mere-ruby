# true / false / nil have no `===` of their own in Ruby, so theirs is
# Object#===, which calls `==` -- a program that redefines TrueClass#== sees
# `true === x` follow it. This went straight to the primitive comparison and
# never asked, so `case` on those three ignored the redefinition entirely.
def eqq(a, b)
  a === b
rescue NoMethodError
  :error
end

p [eqq(true, true), eqq(true, false), eqq(true, :truthy)]

class TrueClass
  def ==(x); !x; end
end
# the first is still true: rb_equal compares identity BEFORE calling #==
p [eqq(true, true), eqq(true, false), eqq(true, :truthy)]

class TrueClass
  undef_method :==
end
# with nothing to call, it raises rather than quietly comparing
p [eqq(true, true), eqq(true, false), eqq(true, :truthy)]

# Integer HAS its own ===, so a redefined Integer#== is not consulted there
class Integer
  def ==(x); :int_eq; end
end
p(1 == 2)
p(1 === 2)
p(1 === 1)
