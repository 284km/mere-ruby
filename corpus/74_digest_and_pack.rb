# Array#pack has MANY directives, each with its own count: "NN" is two 32-bit
# words, not one. Only the first was ever read, which is what made a
# pure-Ruby SHA-1 produce a 60-byte block instead of 64.
p [0, 24].pack("NN").bytes
p [1, 2].pack("N2").bytes
p [1, 2].pack("VV").bytes
p [1, 2].pack("CC").bytes
p [1, 2].pack("nn").bytes
p [65, 66].pack("cc")
p [1, 2, 3].pack("Cn").bytes
p [1, 2, 3, 4].pack("C2n").bytes
p [1, 2, 3].pack("C*").bytes
p [1, 2].pack("N").bytes
p "abcdefgh".unpack("NN")

# digest ships as source: SHA-1, SHA-256 and MD5, byte-identical to CRuby's
# C extension for these vectors.
require "digest"

["", "a", "abc", "message digest", "a" * 55, "a" * 56, "a" * 64, "a" * 65,
 "\x00\x01\xff\xfe"].each do |s|
  puts Digest::SHA1.hexdigest(s)
  puts Digest::SHA256.hexdigest(s)
  puts Digest::MD5.hexdigest(s)
end

d = Digest::SHA1.new
d << "a"
d.update("bc")
p d.hexdigest
p d.to_s
p Digest::SHA1.digest("abc").bytes
p Digest::SHA256.base64digest("abc")
p Digest::SHA1.new.digest_length
p Digest::SHA256.new.block_length

require "digest/sha1"
p Digest::SHA1.hexdigest("x")
