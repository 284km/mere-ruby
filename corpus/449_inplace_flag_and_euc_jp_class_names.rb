# $-i is defined (nil) without -i; ARGF reads it, and a nil in ARGV is a
# TypeError there, not a NameError about $-i [Bug #11610].
p $-i
p defined?($-i)
ARGV[0] = nil
begin
  gets
rescue TypeError => e
  p e.class
end
ARGV.clear

# A class named in an EUC-JP source keeps that encoding in its name, its
# to_s and inspect, and in the default message of an exception of it.
src = "class D\u{30a8} < RuntimeError; self; end".encode(Encoding::EUC_JP)
k = eval(src)
p k.name.encoding, k.to_s.encoding, k.inspect.encoding
p k.name.encode(Encoding::UTF_8).codepoints
e = k.new
p e.to_s.encoding, e.message.encoding
p e.message.encode(Encoding::UTF_8).codepoints
begin
  raise k
rescue k => x
  p x.message.encoding
  p x.message == k.name
end

m = Module.new
m.class_eval("class C\u{30a8}; end".encode(Encoding::EUC_JP))
c = m.constants.first
p c.encoding
p m.const_get(c).to_s.encoding

