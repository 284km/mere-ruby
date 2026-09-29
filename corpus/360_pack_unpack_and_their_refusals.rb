# Array#pack / String#unpack directive by directive, and the sentences ruby
# refuses with (m_pack.mere is pack.c's loop)

def try
  yield
rescue => e
  "#{e.class}: #{e.message}"
end

p [1, -2, 3.7].pack("s<l>C").bytes
p [2**64 + 5, -1].pack("Qq").unpack("Qq")
p ["abc", "de"].pack("a5A3").unpack("Z*A*")
p ["4142", "1010"].pack("H*B4").unpack("H*")
p [1.5, -0.25].pack("eG").unpack("eG")
p ["hello world"].pack("m").unpack1("m")
p ["a=b\tc \n"].pack("M"), ["a=3Db"].first.unpack1("M")
p [0x3042, 0x61].pack("U*"), [0x3042].pack("U").encoding
p [300, 2**70].pack("w*").unpack("w*")
p "\x01\x02\x03\x04".unpack("C@1n x C"), "abc".unpack1("a", offset: 2)
p "\xFF\xFE".unpack("c*"), "ab".unpack("C3")
p "\x01\x02".unpack("C*") { |b| print b, " " }
puts

p try { [].pack("C") }
p try { [1].pack("K") }
p try { [1].pack("a!") }
p try { [1].pack("S<>") }
p try { ["x"].pack("C") }
p try { [nil].pack("d") }
p try { [-1].pack("U") }
p try { "a".unpack("a\x01") }
p try { "\xE3\x81".unpack("U") }
p try { "abc".unpack("C", offset: 4) }
p try { "ab".unpack("x3") }
