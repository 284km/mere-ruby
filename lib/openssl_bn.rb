module OpenSSL
  class BNError < OpenSSLError; end
  class BN
    include Comparable
    def initialize(value, base = 10)
      if value.is_a?(BN) || value.is_a?(Integer)
        @value = value.to_i
      elsif value.is_a?(String)
        case base
        when 10, 16
          raise BNError, 'invalid numeric string' unless value.match?(base == 10 ? /\A-?[0-9]+\z/ : /\A-?[0-9a-fA-F]+\z/)
          @value = value.to_i(base)
        when 2, 0
          bytes = value.bytes
          if base == 0
            raise BNError, 'invalid MPI' if bytes.length < 4
            count = bytes.shift(4).inject(0) { |n, b| n * 256 + b }
            raise BNError, 'invalid MPI length' unless bytes.length == count
          end
          negative = base == 0 && !bytes.empty? && bytes[0] >= 128
          bytes[0] &= 127 if negative
          @value = bytes.inject(0) { |n, b| n * 256 + b }
          @value = -@value if negative
        else raise ArgumentError, 'invalid radix'
        end
      else
        raise ArgumentError, 'invalid value for BN'
      end
    end

    def to_i; @value; end
    alias to_int to_i
    def to_bn; self; end
    def to_s(base = 10)
      return @value.to_s if base == 10
      bytes = []
      number = @value.abs
      while number > 0
        bytes.unshift(number & 255)
        number >>= 8
      end
      case base
      when 16
        text = bytes.empty? ? '0' : bytes.pack('C*').unpack1('H*').upcase
        (@value < 0 ? '-' : '') + text
      when 2 then bytes.pack('C*')
      when 0
        bytes.unshift(0) if !bytes.empty? && bytes[0] >= 128
        bytes[0] |= 128 if @value < 0 && !bytes.empty?
        [bytes.length].pack('N') + bytes.pack('C*')
      else raise ArgumentError, 'invalid radix'
      end
    end

    def <=>(other)
      @value <=> (other.is_a?(BN) ? other.to_i : other)
    end
    def ==(other)
      other.is_a?(BN) ? @value == other.to_i : @value == other
    end
    def hash; @value.hash; end
    def eql?(other); other.is_a?(BN) && @value.eql?(other.to_i); end
    def coerce(other)
      return [other, to_s] if other.is_a?(String)
      return [other, @value] if other.is_a?(Integer)
      raise TypeError, 'cannot coerce into BN'
    end
  end
end

class Integer
  def to_bn
    OpenSSL::BN.new(self)
  end
end

module OpenSSL
  class BN
    CONSTTIME = 4
    def self.number(value)
      return value.to_i if value.is_a?(BN) || value.is_a?(Integer)
      raise TypeError, 'Cannot convert into OpenSSL::BN'
    end
    def native_math(operation, *others)
      values = [@value.to_s] + others.map { |n| BN.number(n).to_s }
      result = Backend.call('bn.' + operation, *values)
      result.is_a?(Array) ? result.map { |n| BN.new(n) } : BN.new(result)
    end
    private :native_math
    def self.rand(bits, top = 0, bottom = false)
      new(Backend.call('bn.rand', Integer(bits), Integer(top), bottom))
    end
    def self.rand_range(range)
      new(Backend.call('bn.rand_range', number(range).to_s))
    end
    def self.pseudo_rand(*args); self.rand(*args); end
    def self.pseudo_rand_range(*args); self.rand_range(*args); end
    def self.generate_prime(bits, safe = true, add = nil, remainder = nil)
      new(Backend.call('bn.generate_prime', Integer(bits), safe,
                      add.nil? ? nil : number(add).to_s,
                      remainder.nil? ? nil : number(remainder).to_s))
    end
    def prime?(*args); Backend.call('bn.prime', @value.to_s); end
    alias prime_fasttest? prime?
    def zero?; @value == 0; end
    def one?; @value == 1; end
    def odd?; @value.odd?; end
    def negative?; @value < 0; end
    def num_bits; @value.abs.bit_length; end
    def num_bytes; (num_bits + 7) / 8; end
    def +@; BN.new(@value); end
    def -@; BN.new(-@value); end
    def abs; BN.new(@value.abs); end
    def cmp(other); @value <=> BN.number(other); end
    def ucmp(other); @value.abs <=> BN.number(other).abs; end
    def get_flags(flags); (@flags || 0) & Integer(flags); end
    def set_flags(flags)
      raise FrozenError, "can't modify frozen OpenSSL::BN" if frozen?
      @flags = (@flags || 0) | Integer(flags)
      nil
    end
    def mod_exp(exponent, modulus)
      flags = exponent.is_a?(BN) ? exponent.get_flags(CONSTTIME) : 0
      flags |= modulus.get_flags(CONSTTIME) if modulus.is_a?(BN)
      BN.new(Backend.call('bn.mod_exp', @value.to_s, BN.number(exponent).to_s,
                          BN.number(modulus).to_s, get_flags(CONSTTIME), flags))
    end
    def bit_set?(bit)
      bit = Integer(bit)
      raise BNError, 'negative bit index' if bit < 0
      (@value.abs & (1 << bit)) != 0
    end
    def change_value(value)
      raise FrozenError, "can't modify frozen OpenSSL::BN" if frozen?
      @value = value
      self
    end
    private :change_value
    def set_bit!(bit)
      bit = Integer(bit)
      raise BNError, 'negative bit index' if bit < 0
      value = @value.abs | (1 << bit)
      change_value(@value < 0 ? -value : value)
    end
    def clear_bit!(bit)
      bit = Integer(bit)
      raise BNError, 'negative bit index' if bit < 0
      value = @value.abs & ~(1 << bit)
      change_value(@value < 0 ? -value : value)
    end
    def mask_bits!(bits)
      bits = Integer(bits)
      raise BNError, 'negative bit count' if bits < 0
      value = @value.abs & ((1 << bits) - 1)
      change_value(@value < 0 ? -value : value)
    end
    def <<(bits)
      bits = Integer(bits)
      raise BNError, 'negative shift count' if bits < 0
      BN.new(@value << bits)
    end
    def >>(bits)
      bits = Integer(bits)
      raise BNError, 'negative shift count' if bits < 0
      value = @value.abs >> bits
      BN.new(@value < 0 ? -value : value)
    end
    def lshift!(bits); change_value((self << bits).to_i); end
    def rshift!(bits); change_value((self >> bits).to_i); end
  end
end

module OpenSSL
  class BN
    def +(b); native_math('add', b); end
    def -(b); native_math('sub', b); end
    def *(b); native_math('mul', b); end
    def /(b); native_math('div', b); end
    def %(b); native_math('mod', b); end
    def **(b); native_math('exp', b); end
    def sqr(); native_math('sqr'); end
    def gcd(b); native_math('gcd', b); end
    def mod_sqr(b); native_math('mod_sqr', b); end
    def mod_sqrt(b); native_math('mod_sqrt', b); end
    def mod_inverse(b); native_math('mod_inverse', b); end
    def mod_add(b, c); native_math('mod_add', b, c); end
    def mod_sub(b, c); native_math('mod_sub', b, c); end
    def mod_mul(b, c); native_math('mod_mul', b, c); end
    alias exp **
    alias mod %
  end
end
