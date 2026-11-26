# A String's, an Array's and a Hash's instance variables (note 559 step 2b'):
# kept in a shape and the slab as an object's are. The order they were set in,
# a removed one set again going last, dup and clone, -str and $/ asking whether
# a String has any -- and a String that died: a new String made in its place
# starts with none.
s = "text"
s.instance_variable_set(:@a, 1)
s.instance_variable_set(:@b, [2])
a = [1, 2]
a.instance_variable_set(:@x, "x")
h = { k: 1 }
h.instance_variable_set(:@y, :y)
p s.instance_variables, a.instance_variables, h.instance_variables
p s.instance_variable_get(:@b), s.instance_variable_defined?(:@a), s.instance_variable_get(:@none)
s.remove_instance_variable(:@a)
p s.instance_variables
s.instance_variable_set(:@a, 3)
p s.instance_variables

d = s.dup
c = s.clone
p d.instance_variables, c.instance_variable_get(:@b), a.dup.instance_variable_get(:@x), h.clone.instance_variables
d.instance_variable_set(:@c, 4)
p d.instance_variables, s.instance_variables

# -str interns a String with no variables, and dups one that has some
plain = +"plain#{1}"
p (-plain).frozen?, (-plain).instance_variables
withiv = +"withiv#{1}"
withiv.instance_variable_set(:@m, 1)
u = -withiv
p u.frozen?, u.instance_variables

# a String subclass setting its own in initialize
class Tagged1066 < String
  def initialize(s, tag) = (super(s); @tag = tag)
  attr_reader :tag
end
t = Tagged1066.new("q", :t1)
p t.tag, t.instance_variables, t.dup.tag

# many Strings with variables made and dropped; the new ones have none
xs = (1..3000).map { |i| x = "s#{i}"; x.instance_variable_set(:@v, [i]); x }
xs = nil
GC.start
GC.start
fresh = (1..3000).map { |i| "n#{i}" }
p fresh.count { |x| !x.instance_variables.empty? }
keep = "keep"
keep.instance_variable_set(:@w, "w")
GC.start
p keep.instance_variable_get(:@w), s.instance_variable_get(:@b), a.instance_variable_get(:@x)

# a 'P' and a 'p' pack keep the Strings they point at on the packed String
pk_src = "abcdef"
pk = [pk_src].pack("P")
pk_p = ["xyz"].pack("p")
GC.start
p pk.unpack("P3"), pk.unpack1("P6")
p pk_p.unpack("p")
p pk.instance_variables, pk.dup.unpack("P2")
p [pk_src, "q"].pack("PP").unpack("P2P1")
