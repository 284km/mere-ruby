# A method that only reads an instance variable -- `def x = @x`,
# `def x; @x; end`, attr_reader's -- answers what the variable holds, through
# every way of calling it, and stops being one when it is redefined.
class R
  def initialize = (@a = 1; @b = :two)
  def a = @a
  def b
    @b
  end
  def unset = @nope
  attr_reader :a2
  private def secret = @a
  def peek = secret
  def peek_self = self.secret
end
r = R.new
p [r.a, r.b, r.unset, r.a2, r.peek, r.peek_self]
p((r.secret rescue $!.class))
p [r.send(:secret), (r.public_send(:secret) rescue $!.class)]
p [r.method(:a).call, R.instance_method(:b).bind(r).call, r.method(:a).owner]
r.remove_instance_variable(:@a)
p [r.a, r.instance_variables]
r.instance_variable_set(:@a, 10)
p r.a

class S < R
  def initialize = (super; @c = 3)
  def c = @c
end
s = S.new
p [s.a, s.b, s.c]
class R; alias aa a; end
p [R.new.aa, S.new.aa]
class R; def a = @a * 100; end
p [R.new.a, R.new.aa, S.new.a]

o = Object.new
o.instance_variable_set(:@z, 5)
def o.z = @z
p o.z
f = R.new.freeze
p [f.b, f.frozen?]
class CV; @@v = 7; def v = @@v; end
p CV.new.v
module Ref; refine(R) { def b = :refined }; end
using Ref
p R.new.b
class R; def b = (@b.to_s + "!"); end
p R.new.b

# the line and the file after a reader answers are the caller's: a raise on
# the next line and on the same one, and __LINE__ after it
class L
  def initialize = (@v = 1)
  def v = @v
  def w
    @v
  end
end
l = L.new
begin
  l.v
  raise "next line"
rescue => e
  p [e.message, e.backtrace_locations.first.lineno == __LINE__ - 2, File.basename(e.backtrace_locations.first.path)]
end
begin
  l.w; raise "same line"
rescue => e
  p [e.message, e.backtrace_locations.first.lineno == __LINE__ - 2]
end
x = l.v; y = __LINE__
p [x, y == __LINE__ - 1, caller_locations(0, 1).first.lineno == __LINE__]

# a Method and an UnboundMethod keep the body they were taken from: a method
# redefined as a reader afterwards does not make the old body one
class M
  def initialize = (@x = 1)
  def x
    @y = 2
    @x
  end
end
mo = M.new
mm = mo.method(:x)
um = M.instance_method(:x)
class M
  def x = @x
end
m2 = M.new
p [m2.x, m2.instance_variable_get(:@y)]
p [mm.call, mo.instance_variable_get(:@y)]
m3 = M.new
p [um.bind_call(m3), m3.instance_variable_get(:@y)]
