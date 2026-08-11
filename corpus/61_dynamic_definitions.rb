# `undef_method` and the `attr_*` family are methods, not keywords: they take
# a name computed at run time, and a statement modifier.
class Undefs
  def a; 1; end
  def b; 2; end
  undef_method :b
  undef_method(:a) if method_defined?(:a)
end
p Undefs.new.respond_to?(:a), Undefs.new.respond_to?(:b)

class Dynamic
  def x; 1; end
  n = :x
  undef_method(n) if method_defined?(n)
end
p Dynamic.new.respond_to?(:x)

class Keyword
  def y; 1; end
  undef y
end
p Keyword.new.respond_to?(:y)

class Attrs
  attr_accessor :a, :b
  n = :c
  attr_accessor n
  m = "d"
  attr_reader m
  attr_writer :e
end
o = Attrs.new
o.a = 1
o.c = 3
p o.a, o.c
p Attrs.new.respond_to?(:d), Attrs.new.respond_to?(:e=), Attrs.new.respond_to?(:e)

class Looped
  %w[x y].each { |nm| attr_accessor nm }
end
d = Looped.new
d.x = 9
p d.x, d.respond_to?(:y=)

# an alias keeps the ORIGINAL's lexical scope, so constants its body names
# still resolve where they were written
module Space
  MARK = :from_space
  def original; MARK; end
end
class UsesIt
  include Space
end
module Space
  alias_method :aliased, :original
end
p UsesIt.new.aliased
class Keeper
  K = :k
  def a; K; end
  alias b a
end
p Keeper.new.b
