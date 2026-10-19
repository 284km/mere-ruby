# Interpolated patterns put together as rb_reg_preprocess_dregexp does:
# pieces fix encodings (a mismatch is a RegexpError), Regexp#to_s carries
# the regexp's encoding, meta/control escapes in a piece are read whole

def e(s) = s.dup.force_encoding("EUC-JP")
def sj(x) = x.dup.force_encoding("Windows-31J")
def u(s) = s.dup.force_encoding("UTF-8")
def bin(s) = s.dup.force_encoding("ASCII-8BIT")
def t(label)
  r = yield
  p [label, :ok, r.source.bytes.take(12), r.encoding.to_s, r.fixed_encoding?]
rescue => ex
  p [label, ex.class, ex.message]
end
r = eval(e("/\xc2\xa1/"))
t(1) { eval(sj("/\xc2\xa1\#{r}/s")) }
t(2) { eval(sj("/\#{r}\xc2\xa1/s")) }
r = /\xc2\xa1/e
t(3) { eval(sj("/\xc2\xa1\#{r}/s")) }
t(4) { eval('/\xc2\xa1#{r}/s') }
r1 = Regexp.new('foo'.dup.force_encoding("ascii-8bit"))
t(5) { eval('/bar#{r1}/'.dup.force_encoding('ascii-8bit')) }
r1 = Regexp.new('foo'.dup.force_encoding("us-ascii"))
t(6) { eval('/bar#{r1}/'.dup.force_encoding('ascii-8bit')) }
t(7) { eval('/bar#{r1}/'.dup.force_encoding('us-ascii')) }
s1 = [0xff].pack("C"); s2 = "\u3042"
t(8) { /#{s1}#{s2}/ }
t(9) { /#{s2}#{s1}/ }
x = bin("\xc2\xa1")
t(10) { /#{x}/ }
t(11) { /a#{x}/ }
y = e("\xc2\xa1")
t(12) { /#{y}/ }
t(13) { /#{y}#{x}/ }
t(14) { /#{y}a\u3042/ }
z = "\u3042"
t(15) { /#{z}#{y}/ }
t(16) { /#{"a"}#{y}/ }
w = "\\" + "xa4\\" + "xa2"
t(17) { /#{w}/ }
t(18) { /#{e(w)}/ }
t(19) { /#{e(w)}#{z}/ }
t(20) { /#{"\\p{Alpha}"}/ }
t(21) { /#{"ab"}c/ }
t(22) { /#{1}#{:sym}/ }
t(23) { /#{bin("a")}/ }
t(24) { /#{bin("a")}/n }
t(25) { /#{y}/n }
t(26) { /#{x}/n }
t(27) { /#{"\\u3042"}#{y}/ }

def t2(s); r = /#{s}/; p [:ok, r.encoding]; rescue => e; p [e.class, e.message]; end
t2('\u3042' + [0xff].pack("C"))
t2([0xff].pack("C") + '\u3042')
t2('\u3042'.dup.force_encoding("EUC-JP") + "\xa4\xa2".dup.force_encoding("EUC-JP"))
t2("\xa4\xa2".dup.force_encoding("EUC-JP") + '\u3042'.dup.force_encoding("EUC-JP"))
t2('\u\{ 110000 }')
t2('\u\{ 1234567 }')
t2('\M-\C-\M-a')
t2('\C-\M-\C-a')
t2('\c\M-a')
t2('\M-\0')
t2('\M-\400')
t2('\M-\q')
t2('\C-\x41')


t2(('\u0041' + "\xa4\xa2").dup.force_encoding("EUC-JP"))
t2(('\u00e9' + "\xa4\xa2").dup.force_encoding("EUC-JP"))
t2(('\u{41 e9}' + "\xa4\xa2").dup.force_encoding("EUC-JP"))
t2(('\u{41 42}' + "\xa4\xa2").dup.force_encoding("EUC-JP"))

# meta and control escapes of one-letter escapes, in a pattern literal
p [0x00, 0x8a, 0xff].pack("C*")[eval('/\\M-\\n/'.b)]
p(/a/.to_s.encoding, /a/.inspect.encoding, /\xc2\xa1/e.to_s.encoding)
