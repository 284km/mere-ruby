# A CLASS's own instance_exec / instance_eval whose `super` reaches the
# builtin (corpus 901 is the instance's): the with-block class arm took the
# override again, to a stack overflow, and the string form never reached
# the override. And a saved Class.new / Module.new called with a block runs
# the builtin past a replacement (review of #178)
class K
  def self.instance_exec(*a, &b) = [:K, super]
end
p K.instance_exec(1) { |x| [self, x] }
class K2
  def self.instance_eval(*a, &b) = [:K2, super]
end
p K2.instance_eval { self }
p K2.instance_eval("self")
module MM
  def self.instance_exec(*a, &b) = [:MM, super]
  def self.class_exec(*a, &b) = [:MMc, super]
end
p MM.instance_exec(2) { |x| [self, x] }
p MM.class_exec(3) { |x| [self, x] }

SN = Class.method(:new)
class << Class
  def new(*a, &b) = [:own, SN.call(*a, &b)]
end
r = Class.new { def x = 1 }
p r[0], r[1].new.x
r2 = Class.new(String)
p r2[0], r2[1].superclass
class << Class
  remove_method :new
end
MN = Module.method(:new)
class << Module
  def new(*a, &b) = [:mod, MN.call(*a, &b)]
end
m = Module.new { def y = 2 }
p m[0]
class << Module
  remove_method :new
end
mod = m[1]
p Class.new { include mod }.new.y
class KC
  def self.class_eval(*a, &b) = [:KC, super]
  def self.module_exec(*a, &b) = [:KCm, super]
end
p KC.class_eval { self }
p KC.module_exec(4) { |x| [self, x] }
