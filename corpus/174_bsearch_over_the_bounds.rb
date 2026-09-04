# Range#bsearch searches the BOUNDS, never a materialized range.
#
# The array path built the whole range first, so `(0...Float::INFINITY)
# .bsearch` recursed until the stack went, an endless range refused with
# "cannot convert endless range to an array", and a Float range refused with
# "can't iterate from Float". None of those is a search: they are all the
# answer to a question about building a list.
#
# The two MODES are separate. `true` from the block means "this element
# satisfies, look for a smaller one", and find-minimum keeps it as the running
# answer. A negative NUMBER means only "the target is to the left"; find-any
# answers nothing but an exact zero, which is why ruby gives nil for
# `(0..3).bsearch { |x| x <=> 3 }` even though 3 is in the range.

def t
  p yield
rescue => e
  p [e.class, e.message]
end

# find-minimum: a boolean block
t { (0...3).bsearch { |x| x > 3 } }
t { (0..3).bsearch { |x| nil } }
t { (-2..4).bsearch { |x| x < 4 } }
t { (0..4).bsearch { |x| x >= 2 } }
t { (-1..4).bsearch { |x| x >= 1 } }
t { (0..4).bsearch { |x| x >= 4 } }
t { (0...4).bsearch { |x| x >= 3 } }
t { (0..2**70).bsearch { |x| x >= 3 } }

# find-any: a three-way numeric block
t { (0..3).bsearch { |x| x <=> 5 } }
t { (0..3).bsearch { |x| x <=> -1 } }
t { (0..3).bsearch { |x| x <=> 3 } }
t { (0..3).bsearch { |x| x < 2 ? 1 : -1 } }
t { (0..4).bsearch { Float::INFINITY } }
t { (0..4).bsearch { -Float::INFINITY } }
t { (0..4).bsearch { |x| x < 2 ? 1.0 : x > 2 ? -1.0 : 0.0 } }
t { [1, 2].include?((0..4).bsearch { |x| x < 1 ? 1 : x > 3 ? -1 : 0 }) }

# no array to build: endless, infinite, and Float bounds
t { (0..).bsearch { |x| x >= 2 } }
t { (0...Float::INFINITY).bsearch { |x| x >= 2 } }
t { (0.0..1.0).bsearch { |x| x >= 0.5 } }
t { (0.0..1.0).bsearch { |x| x >= 0.0 } }
t { (0.0..1.0).bsearch { |x| x >= 1.0 } }
t { (0.0...1.0).bsearch { |x| x >= 1.0 } }
t { (0.0..1.0).bsearch { |x| x <=> 1.0 } }
t { (0.0..1.0).bsearch { |x| true } }
t { (0.0..1.0).bsearch { |x| false } }
t { (-Float::INFINITY..0).bsearch { |x| x >= -3 } }
t { (-Float::INFINITY..Float::INFINITY).bsearch { |x| x >= 3 } }

# an EMPTY range has nothing to search, and its bounds are not a bracket:
# (inf..-inf) halves to NaN, and a NaN answer is worse than nil.
inf = Float::INFINITY
t { (inf..0).bsearch { true } }
t { (0..-inf).bsearch { true } }
t { (inf..-inf).bsearch { true } }
t { (inf...inf).bsearch { true } }
t { (-inf...-inf).bsearch { true } }
t { (inf..inf).bsearch { true } }
t { (-inf..-inf).bsearch { true } }

# what cannot be bisected is refused -- with a block and without one
t { (0..1).bsearch.class }
t { (1..3).bsearch.size }
t { (0..1).bsearch { Object.new } }
t { (0..1).bsearch { "1" } }
t { (0.0..1.0).bsearch { "1" } }
t { ("a".."e").bsearch { true } }
t { ("a".."e").bsearch }

# a break leaves the SEARCH, so it cannot be read as an answer
t { (0..10).bsearch { |x| break 42 if x == 5; x >= 3 } }
