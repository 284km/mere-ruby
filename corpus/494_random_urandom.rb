# Host entropy is a binary string, including across the native 64 KiB buffer.
require "securerandom"

[0, 1, 65535, 65536, 65537, 1048576].each do |size|
  bytes = Random.urandom(size)
  p [bytes.bytesize == size, bytes.encoding == Encoding::BINARY, bytes.frozen?]
end

class EntropySize
  def to_int = 7
end
class InvalidEntropySize
  def to_int = "7"
end
p Random.urandom(EntropySize.new).bytesize
p Random.urandom(1.9).bytesize
[-1, nil, true, "1", InvalidEntropySize.new, 2**63, 2**64, -2**63-1].each do |size|
  begin
    Random.urandom(size)
  rescue Exception => error
    p error.class
  end
end
begin
  Random.urandom
rescue ArgumentError => error
  p error.class
end
begin
  Random.urandom(1, 2)
rescue ArgumentError => error
  p error.class
end

# Reading entropy must not consume the generator seeded by srand.
srand(123)
expected = Random.bytes(16)
srand(123)
Random.urandom(65537)
p Random.bytes(16) == expected

original_stress = GC.stress
begin
  GC.stress = true
  p SecureRandom.random_bytes(1048576).bytesize
ensure
  GC.stress = original_stress
end

# The old Ruby implementation delegated each byte to Random.rand.
class << Random
  def rand(*) = raise("urandom must not call rand")
end
p SecureRandom.random_bytes(17).bytesize
