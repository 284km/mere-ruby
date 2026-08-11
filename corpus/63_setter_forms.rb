# A setter can be defined without parens, and aliased under a setter name.
class Cookie
  def value= value
    @value = value
  end
  def value; @value; end
  def name= n; @name = n; end
  def name; @name; end
  def path=(p); @path = p; end
  def path; @path; end

  alias reading value
  alias writing= value=
  alias_method :other_read, :value
  alias_method :other_write=, :value=
end
c = Cookie.new
c.value = 5
c.name = "n"
c.path = "/"
p c.value, c.name, c.path
c.writing = 9
p c.reading
c.other_write = 10
p c.other_read

# endless methods are still endless methods
class Endless
  def val = 42
  def name = "n"
  def sum = (1 + 2)
end
p Endless.new.val, Endless.new.name, Endless.new.sum

# a setter taking an anonymous splat, and one that destructures
class Odd
  def anon=(*); @a = :anon; end
  def a; @a; end
  def pair=((x, y)); @p = [x, y]; end
  def pair; @p; end
end
o = Odd.new
o.anon = 1
o.pair = [1, 2]
p o.a, o.pair

# an escaped break / return names itself
def from_block
  [1, 2].each { |x| return x }
  :no
end
p from_block
def broken
  [1, 2].each { |x| break x }
end
p broken
