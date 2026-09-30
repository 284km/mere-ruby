# Four shapes from the stdlib that did not parse.
#
# A range's bound may be on the next line after `..`, and the colon of a
# ternary may open a line (matrix.rb, both in one expression):
count = 5
val = (1..-1)
canonical = (val.begin + (val.begin < 0 ? count : 0))..
            (val.end ? val.end + (val.end < 0 ? count : 0) - (val.exclude_end? ? 1 : 0)
                     : count - 1)
p canonical
setter = (true ?
            ->(k) { k.to_sym }
          : ->(k) { k })
p setter.call("a")
p [1..
]

# Right after an operand, with no space, % is modulo (prime.rb's
# `self%(p+4) == 0`); after a space or a keyword it opens a literal.
n = 35
p n%(5) == 0
p [n%(4), (n)%(3), [n][0]%(2)]
class Integer
  def div_by_7? = self%(7) == 0
end
p 35.div_by_7?
p %w[a b], %(x)
def words = %w[c d]
p words
p [1].map { %(lit) }
def pick(k)
  return%w[one] if k == 1
  %i[other]
end
p pick(1), pick(2)

# `recv&.(args)` is `recv&.call(args)` (net/ftp's `block&.(data)`)
blk = ->(d) { d * 2 }
p blk&.(21)
blk = nil
p blk&.(21)
