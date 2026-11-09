# DER/BER values are Ruby objects. Cryptographic operations live in the provider.
module OpenSSL
  module ASN1
    class ASN1Error < OpenSSLError; end
    TAG_CLASSES = [:UNIVERSAL, :APPLICATION, :CONTEXT_SPECIFIC, :PRIVATE].freeze
    # Object identifier is tag 6; descriptor is tag 7.
    UNIVERSAL_TAG_NAME = ['EOC', 'BOOLEAN', 'INTEGER', 'BIT_STRING', 'OCTET_STRING', 'NULL', 'OBJECT', 'OBJECT_DESCRIPTOR', 'EXTERNAL', 'REAL', 'ENUMERATED', 'EMBEDDED_PDV', 'UTF8STRING', 'RELATIVE_OID', nil, nil, 'SEQUENCE', 'SET', 'NUMERICSTRING', 'PRINTABLESTRING', 'T61STRING', 'VIDEOTEXSTRING', 'IA5STRING', 'UTCTIME', 'GENERALIZEDTIME', 'GRAPHICSTRING', 'ISO64STRING', 'GENERALSTRING', 'UNIVERSALSTRING', 'CHARACTER_STRING', 'BMPSTRING'].freeze
    UNIVERSAL_TAG_NAME.each_with_index { |name, number| const_set(name, number) if name }
    OID_LOOKUP = {}
    OID_NAMES.each { |oid, names| OID_LOOKUP[oid] = oid; names.each { |name| OID_LOOKUP[name] = oid } }

    def self.string(value)
      value = value.to_str if !value.is_a?(String) && value.respond_to?(:to_str)
      raise TypeError, 'no implicit conversion into String' unless value.is_a?(String)
      value.b
    end

    def self.base128(value)
      raise ASN1Error, 'negative tag or object identifier component' if value < 0
      bytes = [value & 127]
      while (value >>= 7) > 0
        bytes.unshift((value & 127) | 128)
      end
      bytes.pack('C*')
    end

    def self.tlv(tag, tag_class, constructed, payload, indefinite = false)
      tag = ::Kernel.Integer(tag)
      cls = TAG_CLASSES.index(tag_class)
      raise ASN1Error, 'invalid tag class or number' if cls.nil? || tag < 0 || tag > 2147483647
      raise ASN1Error, 'indefinite length for primitive value' if indefinite && !constructed
      head = [cls * 64 + (constructed ? 32 : 0) + [tag, 31].min].pack('C')
      head << base128(tag) if tag >= 31
      if indefinite
        return head + "\x80".b + payload + "\x00\x00".b
      end
      length = payload.bytesize
      if length < 128
        head << [length].pack('C')
      else
        octets = []
        while length > 0
          octets.unshift(length & 255)
          length >>= 8
        end
        head << ([128 + octets.length] + octets).pack('C*')
      end
      head + payload
    end

    class ASN1Data
      attr_accessor :value, :tag, :tag_class, :indefinite_length
      def initialize(value, tag, tag_class)
        @value, @tag, @tag_class = value, ::Kernel.Integer(tag), tag_class
        @indefinite_length = false
        raise ASN1Error, 'invalid tag class' unless TAG_CLASSES.include?(tag_class)
      end

      def to_der
        constructed = @value.is_a?(Array)
        payload = constructed ? ASN1.contents(@value, @indefinite_length) : ASN1.string(@value)
        ASN1.tlv(@tag, @tag_class, constructed, payload, @indefinite_length)
      end
    end

    module Tagged
      attr_accessor :tagging
      def initialize(value, tag = nil, tagging = nil, tag_class = nil)
        default = self.class.const_defined?(:TAG) ? self.class.const_get(:TAG) : nil
        tag = default if tag.nil?
        raise ASN1Error, 'must specify tag number' if tag.nil?
        raise ASN1Error, 'invalid tagging method' unless [nil, :IMPLICIT, :EXPLICIT].include?(tagging)
        tag_class ||= tagging ? :CONTEXT_SPECIFIC : :UNIVERSAL
        super(value, tag, tag_class)
        @tagging = tagging
      end

      def tagged_der(payload, constructed)
        if @tagging == :EXPLICIT
          default = self.class.const_defined?(:TAG) ? self.class.const_get(:TAG) : @tag
          inner = ASN1.tlv(default, :UNIVERSAL, constructed, payload, @indefinite_length)
          ASN1.tlv(@tag, @tag_class, true, inner, @indefinite_length)
        else
          ASN1.tlv(@tag, @tag_class, constructed, payload, @indefinite_length)
        end
      end
    end

    class Primitive < ASN1Data
      include Tagged
      undef_method :indefinite_length=
      def to_der
        tagged_der(ASN1.payload(self), false)
      end
    end

    class Constructive < ASN1Data
      include Tagged
      include Enumerable
      def to_der
        tagged_der(ASN1.contents(@value.to_a, @indefinite_length), true)
      end
      def each(&block)
        return enum_for(:each) unless block
        @value.each(&block)
        self
      end
    end

    class EndOfContent < ASN1Data
      def initialize
        super(''.b, 0, :UNIVERSAL)
      end
      def to_der
        "\x00\x00".b
      end
    end

    class BitString < Primitive
      TAG = 3
      attr_accessor :unused_bits
      def initialize(*args)
        super
        @unused_bits = 0
      end
    end

    def self.contents(values, indefinite)
      chunks = []
      values.each_with_index do |value, index|
        if indefinite && value.is_a?(EndOfContent)
          raise ASN1Error, 'illegal EOC octets in value' if index + 1 != values.length
          break
        end
        value = value.to_der if value.respond_to?(:to_der)
        chunks << string(value)
      end
      chunks.join.b
    end

    def self.integer_bytes(number)
      number = ::Kernel.Integer(number)
      width = 1
      width += 1 while number < -(1 << (8 * width - 1)) || number >= (1 << (8 * width - 1))
      number += 1 << (width * 8) if number < 0
      result = Array.new(width, 0)
      (width - 1).downto(0) { |i| result[i] = number & 255; number >>= 8 }
      result.pack('C*')
    end

    def self.payload(node)
      value = node.value
      case node
      when Boolean then value ? "\xff".b : "\x00".b
      when Integer, Enumerated then integer_bytes(value)
      when Null then ''.b
      when BitString
        bits = node.unused_bits
        raise ASN1Error, 'invalid unused bits' unless bits.is_a?(::Integer) && (0..7).include?(bits)
        data = string(value).dup
        data.setbyte(data.bytesize - 1, data.getbyte(data.bytesize - 1) & (255 << bits)) if bits > 0 && !data.empty?
        [bits].pack('C') + data
      when ObjectId
        numbers = node.oid.split('.').map { |s| ::Kernel.Integer(s, 10) }
        raise ASN1Error, 'invalid object identifier' unless numbers.length >= 2 && (0..2).include?(numbers[0]) && numbers[1] >= 0 && (numbers[0] == 2 || numbers[1] < 40)
        ([numbers[0] * 40 + numbers[1]] + numbers[2..]).map { |n| base128(n) }.join.b
      when UTCTime, GeneralizedTime
        time = value.is_a?(Time) ? value.getutc : Time.at(::Kernel.Integer(value)).utc
        range = node.is_a?(UTCTime) ? (1950..2049) : (0..9999)
        raise ASN1Error, 'time is out of range' unless range.include?(time.year)
        time.strftime(node.is_a?(UTCTime) ? '%y%m%d%H%M%SZ' : '%Y%m%d%H%M%SZ').b
      else string(value)
      end
    end

    class ObjectId < Primitive
      TAG = 6
      def oid
        text = ASN1.string(@value)
        result = OID_LOOKUP[text] || text
        raise ASN1Error, 'invalid object identifier' unless result.match?(/\A[0-9]+(?:\.[0-9]+)+\z/)
        result
      end
      def sn; OID_NAMES[oid]&.first; end
      def ln; OID_NAMES[oid]&.last; end
      alias short_name sn
      alias long_name ln
      def ==(other)
        other.is_a?(ObjectId) && oid == other.oid
      end
      def self.register(oid, short, long)
        oid, short, long = [oid, short, long].map { |v| ASN1.string(v) }
        raise ASN1Error, 'invalid or duplicate object identifier' if OID_NAMES.key?(oid) || OID_LOOKUP.key?(short) || OID_LOOKUP.key?(long)
        ObjectId.new(oid).to_der
        OID_NAMES[oid] = [short, long]
        [oid, short, long].each { |name| OID_LOOKUP[name] = oid }
        true
      end
    end

    def self.read_node(source, position, limit, depth, visitor)
      raise ASN1Error, 'ASN1 nesting is too deep' if depth > 512
      start = position
      raise ASN1Error, 'header too long' if position + 2 > limit
      first = source.getbyte(position)
      position += 1
      tag = first & 31
      if tag == 31
        tag = 0
        loop do
          raise ASN1Error, 'invalid high tag' if position >= limit
          octet = source.getbyte(position)
          position += 1
          tag = tag * 128 + (octet & 127)
          raise ASN1Error, 'tag number too large' if tag > 2147483647
          break if octet < 128
        end
      end
      raise ASN1Error, 'missing length' if position >= limit
      length = source.getbyte(position)
      position += 1
      indefinite = length == 128
      if length > 128
        count = length & 127
        raise ASN1Error, 'invalid length' if count > 8 || position + count > limit
        length = 0
        count.times { length = length * 256 + source.getbyte(position); position += 1 }
      end
      constructed = (first & 32) != 0
      tag_class = TAG_CLASSES[first >> 6]
      raise ASN1Error, 'indefinite primitive' if indefinite && !constructed
      finish = indefinite ? limit : position + length
      raise ASN1Error, 'too long' if finish > limit
      visitor.call([depth, start, position - start, indefinite ? 0 : length, constructed, tag_class, tag]) if visitor
      if constructed
        values = []
        loop do
          if indefinite
            # The pinned decoder accepts an empty indefinite envelope ending
            # immediately after its header; its encoder supplies the EOC.
            break if position == limit && values.empty?
            raise ASN1Error, 'missing end of content' if position + 2 > limit
            if source.getbyte(position) == 0 && source.getbyte(position + 1) == 0
              visitor.call([depth + 1, position, 2, 0, false, :UNIVERSAL, 0]) if visitor
              position += 2
              break
            end
          else
            break if position == finish
          end
          child, position = read_node(source, position, finish, depth + 1, visitor)
          values << child
        end
        klass = tag_class == :UNIVERSAL ? {16 => Sequence, 17 => Set}[tag] : nil
        node = klass ? klass.new(values) : (tag_class == :UNIVERSAL ? Constructive.new(values, tag) : ASN1Data.new(values, tag, tag_class))
        node.indefinite_length = indefinite
      else
        raw = source.byteslice(position, length)
        position = finish
        klass = tag_class == :UNIVERSAL ? CLASSES[tag] : nil
        case klass&.name
        when 'OpenSSL::ASN1::EndOfContent'
          raise ASN1Error, 'invalid end of content' unless length == 0
          node = EndOfContent.new
        when 'OpenSSL::ASN1::Boolean'
          raise ASN1Error, 'invalid boolean' unless length == 1
          node = Boolean.new(raw.getbyte(0) != 0)
        when 'OpenSSL::ASN1::Integer', 'OpenSSL::ASN1::Enumerated'
          raise ASN1Error, 'invalid integer' if length == 0
          if length > 1 && ((raw.getbyte(0) == 0 && raw.getbyte(1) < 128) || (raw.getbyte(0) == 255 && raw.getbyte(1) >= 128))
            raise ASN1Error, 'nonminimal integer encoding'
          end
          number = 0
          raw.each_byte { |b| number = number * 256 + b }
          number -= 1 << (length * 8) if raw.getbyte(0) >= 128
          node = klass.new(OpenSSL::BN.new(number))
        when 'OpenSSL::ASN1::Null'
          raise ASN1Error, 'invalid null' unless length == 0
          node = Null.new(nil)
        when 'OpenSSL::ASN1::BitString'
          raise ASN1Error, 'invalid bit string' if length == 0 || raw.getbyte(0) > 7
          node = BitString.new(raw.byteslice(1, length - 1))
          node.unused_bits = raw.getbyte(0)
        when 'OpenSSL::ASN1::ObjectId'
          components = []
          number = 0
          raw.each_byte do |b|
            number = number * 128 + (b & 127)
            if b < 128
              components << number
              number = 0
            end
          end
          raise ASN1Error, 'invalid object identifier' if components.empty? || raw.getbyte(length - 1) >= 128
          first_oid = components.shift
          components.unshift(first_oid < 80 ? first_oid % 40 : first_oid - 80)
          components.unshift(first_oid < 80 ? first_oid / 40 : 2)
          oid = components.join('.')
          node = ObjectId.new(OID_NAMES[oid]&.first || oid)
        when 'OpenSSL::ASN1::UTCTime', 'OpenSSL::ASN1::GeneralizedTime'
          digits = klass == UTCTime ? 12 : 14
          pattern = klass == UTCTime ? /\A[0-9]{12}Z\z/ : /\A[0-9]{14}(?:\.[0-9]+)?Z\z/
          raise ASN1Error, 'invalid time' unless raw.match?(pattern)
          width = klass == UTCTime ? 2 : 4
          year = raw[0, width].to_i
          year += year < 50 ? 2000 : 1900 if width == 2
          values = [year] + raw[width, 10].scan(/../).map(&:to_i)
          begin
            time = Time.utc(*values)
            raise ASN1Error, 'invalid time' unless [time.year, time.mon, time.day, time.hour, time.min, time.sec] == values
            node = klass.new(time)
          rescue ArgumentError
            raise ASN1Error, 'invalid time'
          end
        else
          node = klass && klass != Sequence && klass != Set ? klass.new(raw) : ASN1Data.new(raw, tag, tag_class)
        end
      end
      [node, position]
    end

    def self.input(value)
      value = value.to_der if value.respond_to?(:to_der)
      string(value)
    end

    def self.decode(value)
      source = input(value)
      node, position = read_node(source, 0, source.bytesize, 0, nil)
      raise ASN1Error, 'Type mismatch. Total bytes read does not match supplied data' unless position == source.bytesize
      node
    end

    def self.decode_all(value)
      source = input(value)
      nodes, position = [], 0
      while position < source.bytesize
        node, position = read_node(source, position, source.bytesize, 0, nil)
        nodes << node
      end
      nodes
    end

    def self.traverse(value, &block)
      raise LocalJumpError, 'no block given' unless block
      source = input(value)
      _, position = read_node(source, 0, source.bytesize, 0, block)
      raise ASN1Error, 'trailing data' unless position == source.bytesize
      nil
    end
  end
end

module OpenSSL
  module ASN1
    def self.EndOfContent(*args); EndOfContent.new(*args); end
    class Boolean < Primitive; TAG = 1; end
    def self.Boolean(*args); Boolean.new(*args); end
    class Integer < Primitive; TAG = 2; end
    def self.Integer(*args); Integer.new(*args); end
    def self.BitString(*args); BitString.new(*args); end
    class OctetString < Primitive; TAG = 4; end
    def self.OctetString(*args); OctetString.new(*args); end
    class Null < Primitive; TAG = 5; end
    def self.Null(*args); Null.new(*args); end
    def self.ObjectId(*args); ObjectId.new(*args); end
    class Enumerated < Primitive; TAG = 10; end
    def self.Enumerated(*args); Enumerated.new(*args); end
    class UTF8String < Primitive; TAG = 12; end
    def self.UTF8String(*args); UTF8String.new(*args); end
    class Sequence < Constructive; TAG = 16; end
    def self.Sequence(*args); Sequence.new(*args); end
    class Set < Constructive; TAG = 17; end
    def self.Set(*args); Set.new(*args); end
    class NumericString < Primitive; TAG = 18; end
    def self.NumericString(*args); NumericString.new(*args); end
    class PrintableString < Primitive; TAG = 19; end
    def self.PrintableString(*args); PrintableString.new(*args); end
    class T61String < Primitive; TAG = 20; end
    def self.T61String(*args); T61String.new(*args); end
    class VideotexString < Primitive; TAG = 21; end
    def self.VideotexString(*args); VideotexString.new(*args); end
    class IA5String < Primitive; TAG = 22; end
    def self.IA5String(*args); IA5String.new(*args); end
    class UTCTime < Primitive; TAG = 23; end
    def self.UTCTime(*args); UTCTime.new(*args); end
    class GeneralizedTime < Primitive; TAG = 24; end
    def self.GeneralizedTime(*args); GeneralizedTime.new(*args); end
    class GraphicString < Primitive; TAG = 25; end
    def self.GraphicString(*args); GraphicString.new(*args); end
    class ISO64String < Primitive; TAG = 26; end
    def self.ISO64String(*args); ISO64String.new(*args); end
    class GeneralString < Primitive; TAG = 27; end
    def self.GeneralString(*args); GeneralString.new(*args); end
    class UniversalString < Primitive; TAG = 28; end
    def self.UniversalString(*args); UniversalString.new(*args); end
    class BMPString < Primitive; TAG = 30; end
    def self.BMPString(*args); BMPString.new(*args); end
    CLASSES = {0 => EndOfContent, 1 => Boolean, 2 => Integer, 3 => BitString, 4 => OctetString, 5 => Null, 6 => ObjectId, 10 => Enumerated, 12 => UTF8String, 16 => Sequence, 17 => Set, 18 => NumericString, 19 => PrintableString, 20 => T61String, 21 => VideotexString, 22 => IA5String, 23 => UTCTime, 24 => GeneralizedTime, 25 => GraphicString, 26 => ISO64String, 27 => GeneralString, 28 => UniversalString, 30 => BMPString}.freeze
  end
end
