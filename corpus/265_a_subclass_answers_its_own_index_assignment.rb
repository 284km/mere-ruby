# A subclass's own #[]= (and #<<) answers index assignment and appending --
# test-unit's StringifyKeyHash is `class StringifyKeyHash < Hash` with #[] and
# #[]= that turn the key into a String, and `h[k] ||= []; h[k] << x` stored
# under the Symbol and read under the String.
class SKH < Hash
  def self.stringify(o) = o.to_s
  def [](k) = super(self.class.stringify(k))
  def []=(k, v)
    super(self.class.stringify(k), v)
  end
end
h = SKH.new
h[:a] = 1
h[:b] ||= []
h[:b] << :x
p h, h[:a], h[:b]
class Holder
  @@h = SKH.new
  def self.reg(name, v) = (@@h[name] ||= []; @@h[name] << v; @@h)
end
p Holder.reg(:obs, 1), Holder.reg("obs", 2)

class LoudStr < String
  def <<(x) = super(x.to_s.upcase)
  def []=(i, v)
    super(i, v * 2)
  end
end
s = LoudStr.new("ab")
s << "cd"
s[0] = "z"
p s

# a class compared with != asks the CLASS's ==, not its instances' #==
class Comparing
  def ==(other) = :instance_eq
end
p Comparing != Object, Comparing != Comparing
class SelfEq
  def self.==(other) = true
end
p SelfEq != Object

# a bare call with a block pass reaches a private method of the module the
# class extends (test-unit's setup -> register_fixture)
module Fixtures
  def setup(*names, &cb) = register(:setup, *names, &cb)
  private
  def register(kind, *names, &cb) = [kind, names, cb ? :block : nil]
end
class Case
  extend Fixtures
  p setup(:a)
  p(setup { })
end

# Object's public instance methods are reachable bare
class Obj
  def clean
    @a = 1
    @b = 2
    [:@a].each { |n| remove_instance_variable(n) }
    instance_variables
  end
end
p Obj.new.clean
