# Copies of classes and objects: the copy hooks a class defines, class
# variables in a dup, and the singleton class's own singleton class on clone

# initialize_clone / initialize_dup run on a whole copy
a = Class.new
seen = nil
a.define_singleton_method(:initialize_clone) do |x, **kw|
  seen = [ancestors.first.equal?(self), x.equal?(a), singleton_class.ancestors.first.equal?(singleton_class)]
  super(x, **kw)
end
c = a.clone
p seen, c.ancestors.size == a.ancestors.size

b = Class.new
dseen = nil
b.define_singleton_method(:initialize_dup) do |x|
  dseen = [ancestors[1].equal?(b), x.superclass.equal?(b)]
  super(x)
end
d = Class.new(b).dup
p dseen, d.superclass.equal?(b)

class B2
  def self.initialize_dup(x) = (puts "dup hook #{x}"; super)
end
p B2.dup.instance_methods(false)

# a dup's methods read and write the copy's class variables
class T
  def run
    a = Class.new do
      @@a = 'A'
      def a=(x); @@a = x; end
      def a = @@a
    end
    b = a.dup
    b.new.a = 'B'
    p a.new.a, b.new.a, a.class_variables, T.class_variables
  end
end
T.new.run

# clone keeps the singleton class's singleton class
k = Class.new { def self.bar = :bar }
o = k.new
o.singleton_class.singleton_class.define_method(:s2_method) { :s2 }
cl = o.clone
p o.singleton_class.s2_method, cl.singleton_class.s2_method
p cl.singleton_class.singleton_class.instance_methods(false), cl.singleton_class.instance_methods(false)
p o.dup.singleton_class.respond_to?(:s2_method)
