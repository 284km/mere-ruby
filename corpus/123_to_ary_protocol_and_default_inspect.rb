# Destructuring calls #to_ary on the right-hand side, and Ruby reaches it through
# the whole protocol -- a real method, a user respond_to?, respond_to_missing?,
# or method_missing. This stopped at the first two, so a method_missing mock did
# not destructure at all. (The block-argument path already had the fuller check;
# this was the poorer copy of it.)
class WithToAry
  def to_ary; [1, 2]; end
end
a, b = WithToAry.new
p [a, b]

class ViaRespondToMissing
  def method_missing(m, *args); m == :to_ary ? [:from_mm] : super; end
  def respond_to_missing?(m, priv = false); m == :to_ary || super; end
end
c, = ViaRespondToMissing.new
p c

class ViaMethodMissingOnly
  def method_missing(m, *args); m == :to_ary ? [:only_mm] : super; end
end
d, = ViaMethodMissingOnly.new
p d

class NoToAry; end
e, f = NoToAry.new
p e.class
p f

# The default #inspect names the class and shows the instance variables, and
# #to_s names the class alone -- this printed "#<object>" for every object of
# every class, which is the one thing an inspect is for. The address is an
# object id here, so the test normalises it away.
def norm(s); s.sub(/0x[0-9a-f]+/, "0xX"); end
class Shown
  def initialize; @a = 1; @b = "x"; end
end
puts norm(Shown.new.inspect)
puts norm(Shown.new.to_s)
class Empty; end
puts norm(Empty.new.inspect)

# and a class with its own to_s / inspect still wins
class Own
  def to_s; "mine"; end
  def inspect; "MINE"; end
end
puts Own.new.to_s
p Own.new
