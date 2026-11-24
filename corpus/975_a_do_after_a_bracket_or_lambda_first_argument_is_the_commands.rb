# A `do` after a paren-less argument list belongs to the COMMAND, whatever
# the arguments are:
#
#   tmp_yaml ["curious", "yml"], yaml do |t| ... end
#   assert_changes -> { topic.updated_at }, to: new_updated_at do ... end
#
# When the first argument was an array literal or a `->` lambda, the rest of
# the list was read without that rule, and the last argument took the block:
# `yaml do |t| ... end` was a call of a method named yaml (NoMethodError for
# a local), and `{...}.to_yaml do ... end` left tmp_yaml with no block
# (LocalJumpError). Both are activerecord's own tests.
def tmp(*a, **k)
  r = yield a, k
  [:tmp, r]
end
def zz(*a) = block_given? ? :zz_took_the_block : :zz_plain

yaml = "y"
nu = 5
h = { 1 => 2 }

p(tmp ["a", "b"], yaml do |a, k| a end)
x = tmp ["a"], yaml do |a, k| a end
p x
x = tmp [], yaml do |a, k| a end
p x
x = tmp ["a"], h.to_s do |a, k| a end
p x
x = tmp ["a"], zz do |a, k| a end
p x
x = tmp ["a"], zz(1) do |a, k| a end
p x
x = tmp [1], to: nu do |a, k| k end
p x
x = tmp [1].size, nu do |a, k| a end
p x
x = tmp [1, 2] + [3], nu do |a, k| a end
p x

x = tmp -> { 1 }, to: nu do |a, k| [a.size, k] end
p x
x = tmp -> { 1 }, nu do |a, k| [a.size, a.last] end
p x
x = tmp ->(v) { v }, zz do |a, k| a.last end
p x
# the lambda's own `do` body is still the lambda's
x = tmp -> do 7 end, nu do |a, k| [a.first.call, a.last] end
p x
# ...and with a brace block the block is the last argument's, as ever
x = begin
  tmp ["a"], zz { 1 }
rescue LocalJumpError => e
  e.class
end
p x

# the forms that were right stay right
x = tmp 1, yaml do |a, k| a end
p x
x = tmp "s", zz do |a, k| a end
p x
x = tmp to: nu do |a, k| k end
p x
# an enclosing command still owns the `do`
def outer(*a) = block_given? ? [:outer, a] : [:outer_no_block, a]
x = outer tmp(["a"], yaml) { |a, k| a }, nu do end
p x
