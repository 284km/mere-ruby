# dup / clone carry the instance variables over. For a String, Array or Hash
# they are keyed by the value handle rather than an object id, and the primitive
# that makes the copy has no world to read them from -- so the copy came back
# without them, and `s.dup` lost an @ivar that `s.instance_variable_set` had
# just put there.
s = "str"
s.instance_variable_set(:@ivar, "ivar")
d = s.dup
p [d, d.instance_variable_get(:@ivar)]
c = s.clone
p [c, c.instance_variable_get(:@ivar)]
a = [1, 2]
a.instance_variable_set(:@x, 9)
p a.dup.instance_variable_get(:@x)
h = {k: 1}
h.instance_variable_set(:@y, :yy)
p h.clone.instance_variable_get(:@y)
p "plain".dup.instance_variables

# A conversion asks for #to_ary regardless of VISIBILITY -- rb_check_funcall
# does not consult respond_to? -- so a private to_ary still destructures. This
# is right for respond_to? and wrong for a conversion, and the two were sharing
# one answer.
class NilClass
  private
  def to_ary; [1, 2]; end
end
x, y = nil
p [x, y]
p nil.respond_to?(:to_ary)          # still false: private
p nil.respond_to?(:to_ary, true)    # true with include_all
