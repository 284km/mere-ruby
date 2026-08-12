# A paren-less parameter list takes keyword parameters, same encoding as the
# parenthesised form -- `def initialize class_loader, strict_integer: false`
# is how psych writes it.
def kw a, k: 1
  [a, k]
end
p kw(2)
p kw(2, k: 3)

def kw_req a, k:
  [a, k]
end
p kw_req(1, k: 9)

def kw_all a, *r, k: 5, **o, &b
  [a, r, k, o, b ? b.call : nil]
end
p kw_all(1, 2, 3, k: 7, z: 8)
p kw_all(1) { :blk }

class Sing
  def self.mk y, a: [Symbol], b: false
    [y, a, b]
  end
end
p Sing.mk("x")
p Sing.mk("x", b: true)

# An operator method takes paren-less parameters too (psych's Coder).
class Coder
  def []= k, v
    (@h ||= {})[k] = v
  end
  def [] k
    (@h ||= {})[k]
  end
  def << v
    (@a ||= []) << v
    self
  end
end
c = Coder.new
c[:a] = 1
p c[:a]
p((c << 1 << 2)[:a])

# A keyword splat belongs to the SAME keyword hash as the explicit pairs --
# as a positional argument it made the callee see one argument too many.
def opts(x, **o)
  [x, o.sort.to_h]
end
h = { b: 2 }
p opts(9, a: 1, **h)
p opts 9, a: 1, **h
p opts(9, **h)
g = { a: 99 }
p opts(9, a: 1, **g)

def fwd(f, **kwargs)
  opts f, filename: f, **kwargs
end
p fwd("n")
p fwd("n", extra: true)

# `f !x` can only be a negated argument: a method named f! is one token.
def neg(a, b = 0)
  [a, b]
end
x = false
p neg !x
p neg !x, 1
p neg(!x)
y = 1
p y != 2
