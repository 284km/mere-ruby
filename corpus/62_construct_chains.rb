# `x = if ... end.method` — a control construct on the right of an assignment
# is a receiver, the same way it is as a statement.
x = if true then "a" else "b" end.upcase
p x
y = if false
      "a"
    else
      "b"
    end.upcase
p y
z = case 1 when 1 then "a" else "b" end.upcase
p z
w = begin
  "a"
end.upcase
p w
v = if true then [1, 2] else [] end[0]
p v
u = if true then "a" else "b" end
p u
t = if true then 1 else 2 end + 10
p t

# a line ending in `and` / `or` continues
a = 1
b = 2
if (a == 1) and
   (b == 2)
  p :both
end
if false or
   true
  p :either
end

# a setter whose parameter destructures
class Loc
  def location=((filename, lineno))
    @f = filename
    @l = lineno
  end
  def location; [@f, @l]; end
  def plain=(v); @p = v; end
  def plain; @p; end
  def anon=(*); @a = :anon; end
  def a; @a; end
end
loc = Loc.new
loc.location = ["f.rb", 4]
loc.plain = 5
loc.anon = 9
p loc.location, loc.plain, loc.a

# endless methods still parse as endless methods
class Endless
  def val = 42
  def sum = (1 + 2)
end
p Endless.new.val, Endless.new.sum

# File's open-mode and lock constants
p File::RDONLY, File::WRONLY, File::CREAT, File::BINARY, File::LOCK_EX
