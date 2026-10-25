# How a Method names itself, a lambda that absorbs keywords, a frozen proc's
# ruby2_keywords, super from a String subclass's ===, and the numbered
# globals of the last match

def addr(s) = s.gsub(/0x\h+/, "X")

# Method#inspect: a builtin on a class names the singleton and the owner, or
# the class and a dot; a Method made by bind names its owner
p String.method(:prepend).inspect, String.method(:new).inspect, Class.method(:new).inspect
mod = Module.new { def foo; end }
cls = Class.new { include mod }
o = cls.new
p addr(o.method(:foo).unbind.bind(o).inspect).sub(/ \S+:\d+>/, ">")
p addr(o.method(:foo).inspect).sub(/ \S+:\d+>/, ">")

# a lambda without keyword parameters takes a `key:` hash as a Hash
def kwa(*c, **kw) = [c, kw]
l = ->(*a, b) { kwa(*a, b) }
p l.({foo: 1}, bar: 1)
begin; ->(*args) {}.freeze.ruby2_keywords; rescue FrozenError => e; p e.class; end

# super from a String subclass's === reaches String#===
class IterStr < ::String
  def ===(other) = (super if !block_given?)
end
p ["a", "b", "c"].grep(IterStr.new("b")) { |s| s }
p IterStr.new("x") === "x", IterStr.new("x") === :x

# global_variables lists the groups of the last match that took part
/(\w)(\d)?(.)(.)(.)(.)(.)(.)(.)(.)(\d)?(.)/ =~ "globalglobalglobal"
p global_variables.select { _1.to_s =~ /\A\$\d/ }.sort_by { _1.to_s[1..].to_i }
/(a)/ =~ "a"
p global_variables.select { _1.to_s =~ /\A\$\d/ }.sort_by { _1.to_s[1..].to_i }
