# What a name means depends on whether it is a local variable assigned
# earlier in the scope -- ruby's rule, which the lexer now keeps a table for --
# and a handful of command shapes the stdlib and bundled gems write.

# a local followed by ` /`, ` %`, ` ?`, ` &`, ` [` is an operand
def eigen(c, s, g, r)
  p = c * 4 - s * g
  c = p / r
  w = 17
  [c, w %(5), p ?1:2, w &3, (lst = [7, 8]; lst [1])]
end
p eigen(10, 2, 3, 2)

# ...and a block or method parameter is one too
d = [8, 9].map { |q| q /2 }
p d
f = ->(z) { z /4 }
p f.(12)
def g2 x, y; x /y; end
p g2(9, 3)

# the method `p` with a regexp argument is still a call
p(/ab/.source)

# a heredoc may be named in lowercase, and `x <<eom` with x a local shifts
src = <<eom
hello
eom
p src
n = 1
p(n <<2)

# a method named like a constant, with a paren-less argument
module Conv
  def self.URI(x) = "uri:#{x}"
end
u = Conv::URI "a"
p u

# safe navigation takes a paren-less argument list, and continues a chain
# from the start of the next line
buf = []
buf&.push 1, 2
p buf
t = "Ab"
  &.upcase
  &.downcase
p t

# `next a, b` hands back an Array; a `when` value may be on the next line
p [1, 2].map { |x| next x, x * 10 }
case 3
when
  3 then p :three
end

# a multiple assignment in parens takes a rescue modifier
e = [1, 2].each
while (a, b = e.next rescue nil)
  p a
end

# paren-less parameters may open with `**` and wrap after a comma
def opts **kw
  kw
end
p opts(a: 1)
def reg *names,
        repeat: false
  [names, repeat]
end
p reg(:x, repeat: true)

# octal escapes keep the low byte; a label may be glued to its value
p "\666".bytes, "\400".bytes
p({ lvl:[1], neg:-1 })

# `case` as a command argument, and %W words keep an interpolation whole
def say(x) = x
p(say case 2 when 2 then :two end)
p %W[a#{1 + 1} b]

# a comma after `name [..] op rhs` settles it as a call
def pair(a, b) = [a, b]
size = 2
p(pair [1] * size, 3)
