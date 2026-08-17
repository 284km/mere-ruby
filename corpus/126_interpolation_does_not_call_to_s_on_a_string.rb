# `"#{x}"` uses a value that is ALREADY a String as it is, and only calls #to_s
# on everything else. This desugared to `.to_s` unconditionally, so a program
# that redefined String#to_s changed what every interpolation of every string
# produced -- `"#{s}"` and `s.to_s` are two different questions and both were
# asking the second one.
class String
  def to_s; "REDEFINED"; end
end
s = "plain"
p "#{s}"
p s.to_s

# a String SUBCLASS is a String too: interpolation takes its content, and #to_s
# is still the subclass's
class MyStr < String
  def to_s; super + "!"; end
end
m = MyStr.new("sub")
p "#{m}"
p m.to_s

# everything else converts, including a user class through its own to_s
p "#{1}"
p "#{nil}"
p "#{:sym}"
p "#{[1, 2]}"
class Point
  def initialize(x, y); @x = x; @y = y; end
  def to_s; "(#{@x}, #{@y})"; end
end
p "#{Point.new(1, 2)}"
p "a#{Point.new(3, 4)}b"

# an alias name built from an interpolation still folds to a constant
class Aliased
  def real; :real; end
  n = "re"
  alias_method :"#{n}named", :real
end
p Aliased.new.renamed
