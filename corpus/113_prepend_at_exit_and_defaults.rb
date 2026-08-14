# `prepend` puts a module IN FRONT of the class: its methods win, and their
# `super` reaches the class's own definition. (`include` puts it behind.)
module Loud
  def greet(x)
    "<<" + super + ">>"
  end
end
class Base
  def greet(x)
    "hi #{x}"
  end
end
class Base
  prepend Loud
end
p Base.new.greet("a")
p Base.ancestors.first(3)
p [Base.new.is_a?(Loud), Base.include?(Loud)]
p [Base.instance_method(:greet).owner, Base.new.method(:greet).owner]

module M2
  def self.prepended(base)
    $hook = base.name
  end

  def v
    "m2-" + super
  end
end
class B2
  def v
    "b2"
  end
  prepend M2
end
p [B2.new.v, $hook]

# a method the module does not override still comes from the class
module Only
  def a
    "A"
  end
end
class C3
  prepend Only
  def b
    "B"
  end
end
p [C3.new.a, C3.new.b, C3.ancestors.first(2)]

# Module.prepend called as a method, from outside the class body
module Twice
  def n
    super * 2
  end
end
class C4
  def n
    21
  end
end
C4.prepend(Twice)
p C4.new.n

# ...and Array#prepend is still Array#unshift, which takes every argument
arr = [2, 3]
arr.prepend(1)
p arr
p [9].prepend(7, 8)
p [1].unshift(9, 8)

# Hash's default and default_proc are two ways to set ONE default: each
# replaces the other.
h = Hash.new
h.default_proc = proc { |hash, key| hash[key] = "v:#{key}" }
p [h[:a], h, h.default_proc.class, h.default]
g = Hash.new { |hash, k| k.to_s * 2 }
p [g[:ab], g.default]
g.default = 9
p [g[:zz], g.default, g.default_proc]
g.default_proc = proc { |hash, k| :from_proc }
p [g.default, g[:qq]]
begin
  g.default_proc = 7
rescue TypeError => e
  p e.class
end

# at_exit runs its blocks in the reverse of the order they were given, after
# everything else -- so these three lines are the last output of this program.
at_exit { puts "bye1" }
at_exit { puts "bye2" }
p at_exit { puts "bye3" }.class
puts "body"
