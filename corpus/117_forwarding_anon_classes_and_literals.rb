# `def m(...)` forwards everything the caller passed -- positional, keyword AND
# block -- and forwards NO block when the caller gave none.
def inner(a, b = nil, c: nil)
  [a, b, c, block_given? ? yield : :noblock]
end
def forward(...)
  inner(...)
end
p forward(1)
p forward(1, 2, c: 3)
p forward(1) { :blk }
def forward_bare(...) = inner(...)
p forward_bare(9) { :blk2 }

# an anonymous class takes the name of the constant it is assigned to, and is
# a perfectly good superclass even though that name is not itself a constant
Anon = Class.new
class Sub < Anon
  def hi; :hi; end
end
p [Sub.new.hi, Sub.superclass == Anon, Anon.name, "#{Anon}"]
Mod = Module.new
p [Mod.name, Mod.class]

# `**` inside an array literal: the hash items after it merge into ONE element,
# and an empty merge contributes nothing at all
h = { b: 2 }
p [**{ x: 1 }]
p [**{}]
p [1, **{ a: 2 }, b: 3]
p [**h, **{ c: 3 }]
p [1, a: 2]
p ["a", "b" => 1]

# character literals carry the same escapes a string does
p [?\001, ?\x41, ?\n, ?\s, ?a, ?\0, ?/]
p [?\001.ord, "\001" == ?\001]

# top-level instance_eval rebinds self to main
@at_main = :main_ivar
p instance_eval { @at_main }
p instance_eval { 40 + 2 }

# a constant holding an anonymous module is REOPENED by `module X`, not
# shadowed by a new one
Reopened = Module.new
module Reopened
  def self.hi; :hi; end
end
p [Reopened.hi, Reopened.name]

# a capture global takes all of its digits
p("ab" =~ /(a)(b)/)
p [$1, $2, $3, $128]

# a named struct becomes a constant under Struct
Struct.new("Named", :a)
p [Struct::Named, Struct::Named.new(1).a, Struct.new(:b).name]

# Warning's category switches read false and remember a write
p Warning[:deprecated]
Warning[:deprecated] = true
p Warning[:deprecated]

# an alias to a builtin keeps hold of the original
class Array
  alias _orig_pack pack
  def pack(fmt, buffer: nil)
    buffer ||= +""
    buffer << "y"
    _orig_pack(fmt, buffer: buffer)
  end
end
p [1.5].pack("E")

# bytes that are not text inspect as \xNN, not as mojibake
p [1.23].pack("E")
p "\xff\xfe".b

# a struct's inspect is the one object shape with no address in it
Point = Struct.new(:x, :y)
pt = Point.new(1, "a")
p pt
p pt.inspect
p [pt.to_s, Struct.new(:z).new(9)]
