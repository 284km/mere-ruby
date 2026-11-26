# An ivar write the VM's inline cache answers (note 559, step 2c) can move an
# object to the shape that adds the name: the slot is written and the
# object's record changes. With step 2b' the records are keyed by the owner
# key (an object's id times 8); the cache wrote it under the bare id -- some
# other owner's key. The object kept its old shape (@z went unlisted), and the
# objects made after it read wrong values (the sum of 50 x's was 40349).
# The first object fills the cache through the door; the rest take it.
class Pt1067
  def initialize(x, y)
    @x = x
    @y = y
  end
  attr_reader :x, :y
  def add_z(z) = (@z = z; self)
end
pts = (1..50).map { |i| Pt1067.new(i, i * 2) }
p pts.map(&:y).sum, pts.last.instance_variables
zs = pts.map { |pt| pt.add_z(pt.x + 1) }
p zs.count { |pt| pt.instance_variable_get(:@z) == pt.x + 1 }
GC.start
p pts[7].instance_variables, pts[7].dup.instance_variable_get(:@z)
# a String's and an Array's beside them: their records are keyed by their own
# owner keys, which an object's bare id could have been
s = +"s1067"; s.instance_variable_set(:@t, 1)
a = [1067]; a.instance_variable_set(:@u, 2)
more = (1..50).map { |i| Pt1067.new(i, i).add_z(i) }
GC.start
p s.instance_variables, a.instance_variable_get(:@u), more.sum(&:x), more[3].instance_variables
