# A Symbol is its name AND the encoding it was written in: the same bytes in
# EUC-JP and in UTF-8 are two Symbols, two methods, two constants.
def e(s) = s.dup.force_encoding("EUC-JP")
def u(s) = s.dup.force_encoding("UTF-8")
def iso(s) = s.dup.force_encoding("ISO-8859-1")

s1 = e("\xc2\xa1").intern
s2 = u("\xc2\xa1").intern
p s1 == s2, s1.encoding, s2.encoding, s1.to_s.bytes, s2.to_s.bytes
p s1.inspect, s1.length, s2.length

eval(e("def \xc2\xa1() @nm = :e end"))
eval(u("def \xc2\xa1() @nm = :u end"))
eval(e("\xc2\xa1()"))
p @nm
eval(u("\xc2\xa1()"))
p @nm
me = method(e("\xc2\xa1"))
mu = method(u("\xc2\xa1"))
p me.name == mu.name, me.name.to_s == e("\xc2\xa1"), mu.name.to_s == u("\xc2\xa1")
p send(e("\xc2\xa1")), respond_to?(e("\xc2\xa1"), true)

# an ISO-8859-1 constant beside a UTF-8 one of the same text
module M458
  U = eval("class R\u{e9}sum\u{e9}; self; end")
  const_set(iso("R\xe9sum\xe9"), Struct.new(iso("r\xe9sum\xe9").to_sym))
end
iso_c = M458.const_get(iso("R\xe9sum\xe9"))
p iso_c.equal?(M458::U), M458::U.name.encoding, iso_c.name.encoding
p M458.constants.map { |c| [c.encoding.to_s, c.to_s.bytes] }.sort
a = iso_c.new(10)
p a.members.map(&:encoding), a.to_a
p Marshal.load(Marshal.dump(a)) == a
p Marshal.load(Marshal.dump(M458::U.new)).class.equal?(M458::U)
a.__send__("#{iso_c.members[0]}=", 20)
p a.to_a

# an ivar named by an ISO-8859-1 String
o = Object.new
o.instance_variable_set(iso("@r\xe9sum\xe9"), 1)
p o.instance_variables.map { |v| [v.encoding.to_s, v.to_s.bytes] }
p o.instance_variable_get(iso("@r\xe9sum\xe9"))

# a UTF-16 name, and ruby2_keywords of a builtin and of another module's
c = Class.new
utf16 = "abcdef".encode("UTF-16LE").to_sym
p utf16.encoding
c.send(:define_method, utf16, c.instance_method(:itself))
$stderr = $stdout
c.send(:ruby2_keywords, utf16)
Class.new(Class.new { def bar(*a) = a }).send(:ruby2_keywords, :bar)
Module.new.send(:ruby2_keywords, :system)

# the same character in two encodings is two Symbols, each dumped in its own
ae = "→".encode("euc-jp").to_sym
as = "→".encode("sjis").to_sym
p ae == as, ae.encoding, as.encoding
p Marshal.dump(ae).b, Marshal.dump(as).b
p "\u{10FFFF}".to_sym.to_s.bytes
