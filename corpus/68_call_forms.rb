# A space before `(` makes the group the FIRST argument of a paren-less
# argument list -- so a comma continues that list, and a trailing method
# binds to the group rather than to the call.
a = [1, 2]
a.insert (0 || -1), 9
p a

def two(x, y) = [x, y]
p two (1 + 1), 3

b = [3, 1, 2]
# the group is the first argument, so `.to_s` binds to it, not to the call
p two (b.size).to_s, :x

# Safe navigation reaches operator method names, and takes a do-block --
# `do` is a name token, so it used to fall past the block check entirely.
h = { d: [1, 2, 3] }
h[:d]&.each do |x|
  print x
end
puts

p h[:d]&.[](1)
p h[:e]&.[](1)

n = nil
p n&.[](0)
p n&.each { |x| x }

acc = []
h[:d]&.each_with_index do |x, i|
  acc << [i, x]
end
p acc

# a safe-nav chain still short-circuits at the first nil
p h[:e]&.first&.to_s
p h[:d]&.first&.to_s
