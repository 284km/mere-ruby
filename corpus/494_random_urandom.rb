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

# The public singleton method is inherited; the native helper belongs to Random.
class EntropyRandom < Random; end
[0, 7, 65537].each do |size|
  bytes = EntropyRandom.urandom(size)
  p [bytes.bytesize, bytes.encoding == Encoding::BINARY]
end

# Primitive-backed subclasses still participate in implicit integer conversion.
class EntropyStringSize < String
  attr_reader :calls
  def to_int
    @calls = (@calls || 0) + 1
    7
  end
end
class EntropyArraySize < Array
  def to_int = 65537
end
class EntropyHashSize < Hash
  private
  def to_int = 0
end
size = EntropyStringSize.new
p [Random.urandom(size).bytesize, size.calls]
p EntropyRandom.urandom(EntropyArraySize.new).bytesize
p Random.urandom(EntropyHashSize.new).bytesize

class InvalidEntropyStringSize < String
  def to_int = nil
end
class InvalidEntropyArraySize < Array
  def to_int = 1.5
end
class RaisingEntropySize < String
  def to_int = raise(ArgumentError, "conversion failed")
end
class LargeEntropySize < Array
  def to_int = 2**64
end
[InvalidEntropyStringSize.new, InvalidEntropyArraySize.new, RaisingEntropySize.new, LargeEntropySize.new].each do |size|
  begin
    Random.urandom(size)
  rescue Exception => error
    p [error.class, error.message]
  end
end

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
