# `K.singleton_class === K` was false while `K.is_a?(K.singleton_class)` was
# true: Module#=== asked for the class of a class operand, which is Class, and
# never looked at the operand's own singleton class. So `case` could not
# select on a singleton class, and neither could anything built on ===.
base = Class.new
kid = Class.new(base)
obj = kid.new
p base.singleton_class === base, base.singleton_class === kid, kid.singleton_class === base
p base.singleton_class === obj.singleton_class, obj.singleton_class === obj
def kind(k, base)
  case k
  when base.singleton_class then :a_base
  when Class then :some_class
  else :other
  end
end
p kind(kid, base), kind(String, base), kind(3, base)
ext = Module.new
extended = Class.new { extend ext }
p ext === extended, Class === extended, Module === Comparable, Comparable === String
