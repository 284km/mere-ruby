require "openssl"

# Empty and binary strings, including native-buffer boundaries and large input.
[0, 1, 65535, 65536, 65537, 1_000_000].each do |size|
  a = "\x00\xff".b * (size / 2) + "x" * (size % 2)
  p OpenSSL.fixed_length_secure_compare(a, a.dup)
  unless a.empty?
    first = a.dup
    first.setbyte(0, first.getbyte(0) ^ 1)
    last = a.dup
    last.setbyte(-1, last.getbyte(-1) ^ 1)
    p [OpenSSL.fixed_length_secure_compare(a, first),
       OpenSSL.fixed_length_secure_compare(a, last)]
  end
end

# Encoding labels do not affect a byte comparison.
p OpenSSL.fixed_length_secure_compare("\xff".b, "\xff".b.force_encoding("UTF-8"))
begin
  OpenSSL.fixed_length_secure_compare("a", "aa")
rescue ArgumentError => error
  p [error.class, error.message]
end

# Convert in argument order, once each. The second conversion may mutate the
# first string or collect an otherwise unreferenced first conversion result.
events = []
left = Object.new
left.define_singleton_method(:to_str) { events << :left; "abc".dup }
right = Object.new
right.define_singleton_method(:to_str) { events << :right; GC.start; "abc" }
p [OpenSSL.fixed_length_secure_compare(left, right), events]

first = "A" * 1_000_000
other = Object.new
other.define_singleton_method(:to_str) do
  first.replace("C" * 1_000_000)
  GC.start
  "B" * 1_000_000
end
p OpenSSL.fixed_length_secure_compare(first, other)

# Read the length after both conversions, including a changed length.
first = "a"
other.define_singleton_method(:to_str) { first.replace("bb"); "bb" }
p OpenSSL.fixed_length_secure_compare(first, other)
other.define_singleton_method(:to_str) { first.replace("ccc"); "bb" }
begin
  OpenSSL.fixed_length_secure_compare(first, other)
rescue ArgumentError => error
  p [error.class, error.message]
end

# Native comparison must not dispatch per-byte Ruby methods or trust overrides.
class CompareString < String
  def bytes = raise("must not allocate a Ruby byte array")
  def bytesize = raise("must read the underlying length")
  def getbyte(*) = raise("must read the underlying bytes")
  def ==(*) = raise("must compare every byte")
end
p OpenSSL.fixed_length_secure_compare(CompareString.new("same"), "same")
p OpenSSL.fixed_length_secure_compare(CompareString.new("same"), "diff")

bad_conversion = Object.new
bad_conversion.define_singleton_method(:to_str) { 7 }
[nil, 1, Object.new, bad_conversion].each do |value|
  begin
    OpenSSL.fixed_length_secure_compare(value, "")
  rescue TypeError => error
    p error.class
  end
end
[["a"], ["a", "a", "a"]].each do |args|
  begin
    OpenSSL.fixed_length_secure_compare(*args)
  rescue ArgumentError => error
    p error.class
  end
end

p [OpenSSL.secure_compare("same", "same"),
   OpenSSL.secure_compare("same", "diff"),
   OpenSSL.secure_compare("a", "aa")]
