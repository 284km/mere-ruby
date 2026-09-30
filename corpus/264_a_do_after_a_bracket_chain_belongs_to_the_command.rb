# A `do` after a paren-less argument belongs to the command, and that holds
# when the argument is a chain on an array literal too: `m [1].map do ... end`
# is m([1].map) { }. The chain used to take the block for its last call.
def m(*a, &b) = [a.size, b ? :block : :no_block]
p(m [1].map do |v| v end)
p(m [1, 2].first.to_s do end)
p(m [3].map { |v| v * 2 } do end)

# ...while a LOCAL in front of the bracket is indexed, and the block is the
# chain's: x [0].map do ... end is x[0].map { }
x = [[5, 6]]
p(x [0].map do |v| v * 10 end)

# define_method's own shape, with the name built from an array
class K
  [%w[a b], %w[c d]].each do |pair|
    define_method [pair.join].first.to_sym do pair end
  end
end
p K.new.ab, K.new.cd

# p and pp have a branch of their own for `p [..]`, and the same holds there:
# the block is p's, Kernel#p ignores it, and what p prints is the Enumerator
p [1, 2].map do |x| x end
p([3].each do end.class)
