# In a call without parentheses, `**opts` starts the call's keyword hash:
# what follows it -- more pairs, another `**`, a block-pass -- is the same
# hash, in source order, as it is with parentheses. It went on the
# positional list, so the pairs after it made a SECOND hash. activerecord's
# delegated_type does
#   belongs_to role, options.delete(:scope), **options, polymorphic: true
# and got "wrong number of arguments (given 3, expected 1..2)".
def bt(name, scope = nil, **options) = [name, scope, options]
def dt(role, types:, **options)
  bt role, options.delete(:scope), **options, polymorphic: true
end
p dt(:e, types: %w[a b]), dt(:e, types: [], scope: :s, x: 1)

o = {a: 1}
e = {}
r = bt :n, nil, **o, k: 2
p r
r = bt :n, nil, **e, k: 2
p r
r = bt :n, **o, k: 2, a: 3
p r
r = bt :n, **o, **{b: 2}, c: 3
p r
r = bt :n, nil, k: 2, **o
p r
r = bt :n, nil, **o
p r
r = bt :n, **e
p r
r = bt :n, **o, "s" => 1
p r

# with a block-pass after it, and a block
def blk(a, **kw, &b) = [a, kw, b ? b.call : :none]
pr = proc { :called }
r = blk 1, **o, &pr
p r
r = blk 1, **o, z: 9, &pr
p r
r = blk(2, **o) { :lit }
p r
# on a receiver, and as the last statement of a method
class Rcv; def m(a, b = :d, **kw) = [a, b, kw]; end
rc = Rcv.new
r = rc.m 1, **o, y: 2
p r
def last_stmt(h) = Rcv.new.m 1, 2, **h, w: 0
p last_stmt(o), last_stmt(e)

# a method that takes no keywords gets ONE trailing hash
def pos(*a) = a
r = pos 1, **o, k: 2
p r
r = pos 1, **e
p r
# Kernel#p and puts with a splatted hash, as ever
p(**o)
p 1, **o
h2 = {x: 1}
puts "#{pos(**h2, y: 2)}"
