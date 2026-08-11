# A multiple-assignment target list may wrap across lines, right after a comma.
a, b,
  c = [7, 8, 9]
p a, b, c
d, *e,
  f = [1, 2, 3, 4]
p d, e, f
@p, @q,
  @r = [1, 2, 3]
p @p, @q, @r
x, y = 1, 2
p x, y

class Reader
  def read_signed(_n); [1, 2, 3]; end
  def read(_a, _b); [4]; end
  def parse!
    @version = read(4, "N").first
    @ascent, @descent, @line_gap = read_signed(3)
    @one, @two, @three,
      @four, @five, @six = [1, 2, 3, 4, 5, 6]
    [@version, @ascent, @line_gap, @one, @six]
  end
end
p Reader.new.parse!

# `self.attr, self.attr = ...` — self is a keyword, but here it is just the
# receiver of an attribute writer.
class Pair
  attr_accessor :a, :b, :c
  def go(t)
    self.a, self.b = {}, t
    self.c = 3
    z, self.b = 9, 8
    [a, b, c, z]
  end
end
p Pair.new.go(:x)

# `include` takes a module VALUE, not only a constant path
module Helpers
  def helped; :yes; end
end
class Holder
  def self.mod; Helpers; end
end
class User
  include Holder.mod
end
p User.new.helped, User.ancestors.include?(Helpers)
module Plain
  def q; 1; end
end
class Direct
  include Plain
end
p Direct.new.q
