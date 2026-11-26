# An object's instance variables are listed in the order they were first set
# (note 559 step 2b keeps them in a shape). A removed one is gone from every
# listing, and set again it comes LAST; dup, clone and Marshal keep the order,
# the removals included.
class P1064
  def initialize; @a = 1; @b = 2; @c = 3; end
end
o = P1064.new
p o.instance_variables
o.remove_instance_variable(:@b)
p o.instance_variables, o.instance_variable_defined?(:@b), o.instance_variable_get(:@b)
o.instance_variable_set(:@d, 4)
p o.instance_variables
o.instance_variable_set(:@b, 5)
p o.instance_variables, o.inspect.sub(/0x\h+/, "X")
o.remove_instance_variable(:@a)
p o.instance_variables

d = o.dup
c = o.clone
p d.instance_variables, c.instance_variables
d.instance_variable_set(:@a, 6)
p d.instance_variables, o.instance_variables
m = Marshal.load(Marshal.dump(o))
p m.instance_variables, m.instance_variable_get(:@b)

# two objects of one class that set the same names in other orders
x = P1064.new
y = P1064.allocate
y.instance_variable_set(:@c, 1)
y.instance_variable_set(:@a, 2)
p x.instance_variables, y.instance_variables

# removing every one, then setting again
z = P1064.new
z.instance_variables.each { |n| z.remove_instance_variable(n) }
p z.instance_variables
z.instance_variable_set(:@c, 7)
z.instance_variable_set(:@a, 8)
p z.instance_variables, z.inspect.sub(/0x\h+/, "X")

# an unset name reads nil, many times over (the "not there" answer is
# remembered per shape)
class Q1064
  def memo; @memo ||= 0; @memo += 1; end
  def peek; @nothing; end
end
q = Q1064.new
3.times { q.memo; q.peek }
p q.memo, q.peek, q.instance_variables

# a class that makes many orders: past ruby's eight variations its objects
# are kept another way, and still answer the same
class V1064; end
vs = (0...12).map do |i|
  v = V1064.new
  v.instance_variable_set("@k#{i}", i)
  v.instance_variable_set(:@shared, i * 2)
  v
end
p vs.map(&:instance_variables).last(3), vs.map { |v| v.instance_variable_get(:@shared) }.sum
w = vs[11].dup
w.remove_instance_variable(:@k11)
w.instance_variable_set(:@k11, 0)
p w.instance_variables, vs[11].instance_variables
