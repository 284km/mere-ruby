# coding: US-ASCII
# A Regexp literal is one frozen object; #dup, #clone and Regexp.new make new
# objects, unfrozen until frozen, equal to it but not it
a = //
c = a.dup
p c.frozen?, c.equal?(a), c == a, a.frozen?
c.freeze
begin
  c.instance_eval { initialize_copy(//) }
rescue => e
  p e.class
end
p Regexp.new("x").frozen?, /x/.clone.frozen?, /x/.dup.frozen?
p Regexp.new("x") == /x/, {Regexp.new("x") => 1}[/x/], Regexp.new("x").hash == /x/.hash
p "axb".sub(/x/.dup, "-")
class Regexp; def self.mk460(s) = new(s, 0); end
p(/foo/ == Regexp.mk460("foo"))
objs = Marshal.load(Marshal.dump(["foo", {}, /foo/, 1..2]), ->(o) { o.dup }, freeze: true)
p objs.map(&:frozen?), objs == ["foo", {}, /foo/, 1..2]
p Marshal.load(Marshal.dump(/foo/), freeze: true).frozen?

# a Range's dup is a new, unfrozen Range
r = (1..2).dup
p r, r.frozen?, r == (1..2), [r] == [1..2], (1..2).clone.frozen?, [1, 2, 3][r]

# a Complex / Rational of a subclass keeps its class
class CS462 < Complex; end
class RS462 < Rational; end
cs = CS462.send(:convert, 1)
p cs.class, cs, (cs + 1).class, (cs - 1).class, cs == Complex(1), Complex(1).eql?(cs), cs.hash == Complex(1).hash
p Marshal.load(Marshal.dump(cs)).class, Marshal.load(Marshal.dump(cs)) == cs
rs = RS462.send(:convert, 1)
p rs.class, (rs + 1).class, Rational(1) == rs, Marshal.load(Marshal.dump(rs)).class

# one interpolated string literal is folded before its escapes are read
p(/#{%q"\x80"}/.encoding, /#{"a"}/.encoding, /a#{%q"\x80"}/.encoding)
