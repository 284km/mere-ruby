# `n.chr` was the largest single cause in the whole ruby/spec record: 774 of
# core/integer's failing examples came from this one method answering UTF-8 for
# everything, and every form that takes an encoding failed outright.
#
# With no encoding it is a BYTE -- US-ASCII under 128, ASCII-8BIT at or above it,
# RangeError outside. With one it is a CODEPOINT in that encoding.
p [65.chr, 65.chr.encoding, 65.chr.bytes]
p [200.chr.encoding, 200.chr.bytes, 255.chr.bytes]
p [0.chr.encoding, 127.chr.encoding, 128.chr.encoding]
p [12.to_s.encoding, (-3).to_s.encoding, 255.to_s(16).encoding]

def t; yield; rescue => e; [e.class, e.message]; end
p t { (-1).chr }
p t { 256.chr }
p t { 300.chr }

p [256.chr("UTF-8").bytes, 0x10FFFF.chr("UTF-8").bytes, 65.chr("UTF-8").encoding]
p t { 0x110000.chr("UTF-8") }
p t { (-1).chr("UTF-8") }
p [65.chr("US-ASCII").encoding, 127.chr("US-ASCII").bytes]
p t { 128.chr("US-ASCII") }
p [200.chr("ASCII-8BIT").bytes, 200.chr("BINARY").encoding]
p t { 256.chr("ASCII-8BIT") }

# ... and the encoding a string carries is what String#encoding answers, so a
# tagged string keeps its tag through the operations that preserve it
s = 200.chr
p [s.encoding, s.dup.encoding, s.frozen?, (s + 65.chr).encoding]
p [65.chr.force_encoding("ASCII-8BIT").encoding, 65.chr.b.encoding]
p "abc".encoding
