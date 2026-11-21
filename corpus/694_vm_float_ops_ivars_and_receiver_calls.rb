# Two Floats (or a Float and an Integer) under + - * / and the comparisons,
# an instance variable read, and a call of positional values on a receiver:
# the VM answers them without building the evaluator's expression for each.
# What a redefinition, a refinement, a private method or $~ asks still holds.

x = 1.5
y = 2.25
p x + y, x - y, x * y, x / y, x < y, x > y, x <= y, x >= y, x == y, x != y
p x + 2, x - 2, x * 2, x / 2, 2 + x, 2 - x, 2 * x, 7 / 2.0, 7.0 / 2
p 1.0 / 0, -1.0 / 0, (0.0 / 0).nan?, 0.0 * -1, -0.0 == 0.0
nan = 0.0 / 0
p nan == nan, nan != nan, nan < 1.0, nan > 1.0, nan <= nan
p 0.1 + 0.2, 1e308 * 10, 2**62 * 1.0, 2.5 == 2.5
p 3 < 2.5, 2.5 < 3, 3 == 3.0, (2**53 + 1) == (2**53 + 1).to_f
z = 0.0
10.times { |i| z += i * 0.5 }
p z

# instance variables, and a class variable beside them
class Pt
  @@made = 0
  def initialize(a, b) = (@a = a; @b = b; @@made += 1)
  def sum = @a + @b
  def unset = @nope
  def self.made = @@made
end
pt = Pt.new(1.5, 2)
p pt.sum, pt.unset, Pt.made, Pt.new(3, 4).sum, Pt.made

# calls on a receiver
s = +""
%w[a b c].each { |w| s << w }
p s, s.length, s.upcase
o = Object.new
def o.m(v) = v * 3
p o.m(1), o.m(2.5)
class Ghost
  def method_missing(name, *args) = [:missing, name, args]
  def respond_to_missing?(*) = true
end
p Ghost.new.anything(1, 2)
class Secret
  def pub = priv + 1
  private def priv = 41
  protected def prot = 1
end
p Secret.new.pub
begin
  Secret.new.priv
rescue NoMethodError => e
  p e.message
end
begin
  Secret.new.prot
rescue NoMethodError => e
  p e.message
end

# $~ from a call on a receiver lands in this frame
def caught(str)
  str =~ /(b+)/
  first = $1
  str.sub(/c/, "C")
  m = str.match(/(a)/)
  [first, $~ && $~[1], m[1]]
end
p caught("abbc")

# Float#+ redefined, and a refinement of Float#*, take over the operator
module Tw
  refine Float do
    def *(o) = :refined
  end
end
module UseTw
  using Tw
  def self.go(a, b) = a * b
end
p UseTw.go(1.5, 2.0), 1.5 * 2.0
class Float
  alias_method :__orig_add, :+
  def +(o) = :redefined
end
p 1.5 + 2.5, 1.5 - 0.5

# `s << t` of two Strings: a frozen one, encodings that cannot meet, an
# empty BINARY one taking UTF-8, a subclass with its own <<
fz = "fixed".freeze
begin
  fz << "x"
rescue FrozenError => e
  p e.message
end
bin = "\xff".b
begin
  bin << "é"
rescue Encoding::CompatibilityError => e
  p e.message
end
eb = "".b
eb << "é"
p eb, eb.encoding
class Loud < String
  def <<(o) = super(o.upcase)
end
l = Loud.new("a")
l << "b"
p l
acc = +""
3.times { |k| acc << k.to_s << "," }
p acc
