# A method defined in an instance of a Module subclass is OWNED by that
# instance: Method#owner and UnboundMethod#owner answer the object, not a
# nameless Module behind it.
#
# ActiveRecord keeps each model's attribute methods in a
# GeneratedAttributeMethods (a Module subclass) and its #method_missing finds
# the generated method with
#
#   method = self.class.public_instance_method(name)
#   method = method.super_method while method && !method.owner.is_a?(GeneratedAttributeMethods)
#
# The owner was a plain Module, so the walk ran off the end and every
# attribute read after `undefine_attribute_methods` was a NoMethodError.
class GM < Module; end
g = GM.new
class C; end
C.include(g)
g.module_eval { def name = 1 }
m = C.public_instance_method(:name)
p m.owner.equal?(g), m.owner.is_a?(GM), m.owner.class
p C.instance_method(:name).owner.equal?(g), C.new.method(:name).owner.equal?(g)
p C.ancestors[1].equal?(g), m.bind_call(C.new)

# through an override that calls super: the walk ActiveRecord does
class D < C; def name = super + 1; end
m2 = D.public_instance_method(:name)
p m2.owner, m2.super_method.owner.equal?(g)
walk = m2
walk = walk.super_method while walk && !walk.owner.is_a?(GM)
p walk.bind_call(D.new), D.new.name

# undefined and defined again in the same module
g.module_eval { undef_method(*instance_methods) }
p C.method_defined?(:name), (C.public_instance_method(:name) rescue :name_error)
g.module_eval { def name = 2 }
p C.method_defined?(:name), C.public_instance_method(:name).owner.is_a?(GM), C.new.name, D.new.name

# with a name, once a constant gives it one
C.const_set(:Generated, g)
p C.instance_method(:name).owner, C.instance_method(:name).owner.name
# a plain module is as it was
module Plain; def pm = 1; end
class E; include Plain; end
p E.instance_method(:pm).owner, E.new.method(:pm).owner
anon = Module.new { def am = 1 }
class F; end
F.include(anon)
p F.instance_method(:am).owner.equal?(anon), F.instance_method(:am).owner.class
