# A backslash at the end of a line continues it: a `?` that starts the next
# line is the ternary's, not a stray character literal (rbs's
# value_object_generator.rb writes `x.nil? \` and then `? a : b`)
a = nil
r = a.nil? \
    ? :nil
    : :value
p r
b = 5
c = b \
  ? b * 2 : 0
p c
p(1.zero? \
  ? :z : :nz)
# a `?x` character literal and `%w` still start a value after a continued line
d = [?x, \
  ?y]
p d
e = \
  %w[p q]
p e
