# Public Zlib constants and checksums. The byte loops run in Mere; the stream
# and gzip protocols live in zlib_stream.rb and zlib_gzip.rb.
module Zlib
  class Error < StandardError; end
  class BufError < Error; end
  class NeedDict < Error; end
  class StreamError < Error; end
  class MemError < Error; end
  class VersionError < Error; end
  class InProgressError < Error; end
  class DataError < Error; end
  def self.zlib_version = ZLIB_VERSION

  def self.__uint(value)
    n = value.is_a?(Integer) ? value : value.to_int
    raise TypeError, 'to_int did not return Integer' unless n.is_a?(Integer)
    raise RangeError, "bignum too big to convert into 'unsigned long'" if n > 0xffffffffffffffff || n < -0x8000000000000000
    n & 0xffffffff
  end

  def self.__check(kind, str, seed)
    seed = __uint(seed)
    return kind if str.nil?
    if str.is_a?(IO)
      while (part = str.read(16384)) && !part.empty?
        seed = __checksum(kind, __string(part), seed)
      end
      seed
    else
      __checksum(kind, __string(str), seed)
    end
  end
  def self.crc32(str = nil, seed = 0) = __check(0, str, seed)
  def self.adler32(str = nil, seed = 1) = __check(1, str, seed)

  def self.adler32_combine(a, b, length)
    a = __uint(a)
    b = __uint(b)
    n = Integer(length)
    raise RangeError, 'integer too big to convert to `long\'' if n > 0x7fffffffffffffff
    return 0xffffffff if n < 0
    base = 65521
    low = (a & 65535) + (b & 65535) - 1
    high = ((a >> 16) + (b >> 16) + (n % base) * ((a & 65535) - 1)) % base
    (high << 16) | (low % base)
  end

  def self.__gf_times(matrix, vector)
    sum = 0
    i = 0
    while vector != 0
      sum ^= matrix[i] if (vector & 1) != 0
      vector >>= 1
      i += 1
    end
    sum
  end
  def self.__gf_square(matrix) = matrix.map { |v| __gf_times(matrix, v) }
  def self.crc32_combine(a, b, length)
    a = __uint(a)
    b = __uint(b)
    n = Integer(length)
    raise RangeError, 'integer too big to convert to long' if n > 0x7fffffffffffffff || n < -0x8000000000000000
    raise ArgumentError, 'negative length' if n < 0
    return a if n == 0
    odd = [0xedb88320] + (0...31).map { |i| 1 << i }
    even = __gf_square(odd)
    odd = __gf_square(even)
    while n != 0
      even = __gf_square(odd)
      a = __gf_times(even, a) if (n & 1) != 0
      n >>= 1
      break if n == 0
      odd = __gf_square(even)
      a = __gf_times(odd, a) if (n & 1) != 0
      n >>= 1
    end
    a ^ b
  end
  def self.crc_table
    (0...256).map do |n|
      8.times { n = (n & 1) == 1 ? 0xedb88320 ^ (n >> 1) : n >> 1 }
      n
    end
  end

  # ruby's are module functions (rb_define_module_function): each is a
  # private instance method too, for a class that includes Zlib
  def zlib_version = Zlib.zlib_version
  def crc32(...) = Zlib.crc32(...)
  def adler32(...) = Zlib.adler32(...)
  def adler32_combine(...) = Zlib.adler32_combine(...)
  def crc32_combine(...) = Zlib.crc32_combine(...)
  def crc_table = Zlib.crc_table
  private :zlib_version, :crc32, :adler32, :adler32_combine, :crc32_combine, :crc_table
end
