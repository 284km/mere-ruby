# =begin / =end block comments (both markers at column 0)
p 1
=begin
this is a comment
x = = broken
  even indented junk
=end
p 2
y = 3
=begin comment with a tag
more
=end trailing text
p y
z = 4 # =begin is not a comment here
p z

# the unary method-name symbols
p :-@, :+@
p :[], :[]=, :<=>, :==, :<<, :**
p "".respond_to?(:-@), 1.respond_to?(:-@), 1.respond_to?(:nope)
class Neg
  def -@; :neg; end
end
p(-Neg.new)
p Neg.new.respond_to?(:-@)
p Neg.instance_methods(false)

# `for (a, b) in pairs` — the parens only group the destructuring
pairs = [[1, :a], [2, :b]]
out = []
for (n, sym) in pairs
  out << [n, sym]
end
p out
out2 = []
for n, sym in pairs
  out2 << sym
end
p out2
for v in [1, 2]
  # `for` shares the enclosing scope, so v outlives the loop
end
p v

# character literals as hash keys
h = {}
h.update({
  ?"  => '"',
  ?\\ => '\\',
  ?/  => '/',
  ?b  => "\b",
  ?u  => nil,
})
p h.size, h['"'], h["\\"], h['/'], h['b'], h['u']
