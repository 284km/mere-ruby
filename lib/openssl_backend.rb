module OpenSSL
  module Backend
    def self.pack(value)
      case value
      when nil then 'n'
      when true then 't'
      when false then 'f'
      when Integer
        text = value.to_s
        'i' + [text.bytesize].pack('N') + text
      when String then 's' + [value.bytesize].pack('N') + value.b
      when Array then 'a' + [value.length].pack('N') + value.map { |v| pack(v) }.join
      when Hash then 'm' + [value.length].pack('N') + value.map { |k, v| pack(k) + pack(v) }.join
      else raise TypeError, 'unsupported provider argument'
      end.b
    end

    def self.item(source, position)
      kind = source.getbyte(position)
      position += 1
      case kind
      when 110 then return [nil, position]
      when 116 then return [true, position]
      when 102 then return [false, position]
      when 101
        name, position = item(source, position)
        message, position = item(source, position)
        raise Object.const_get(name), message
      end
      raise OpenSSLError, 'invalid provider response' unless position + 4 <= source.bytesize
      size = source.byteslice(position, 4).unpack1('N')
      position += 4
      case kind
      when 105, 115
        raise OpenSSLError, 'invalid provider string' unless position + size <= source.bytesize
        text = source.byteslice(position, size)
        [kind == 105 ? text.to_i : text, position + size]
      when 97, 109
        values = []
        (kind == 109 ? size * 2 : size).times do
          value, position = item(source, position)
          values << value
        end
        [kind == 109 ? values.each_slice(2).to_h : values, position]
      else raise OpenSSLError, 'invalid provider response type'
      end
    end

    def self.call(operation, *args)
      raise NotImplementedError, 'native OpenSSL provider is unavailable on this target' unless OpenSSL.__native_available
      source = OpenSSL.__native_call(operation, pack(args))
      value, position = item(source, 0)
      raise OpenSSLError, 'trailing provider response' unless position == source.bytesize
      value
    end
  end

  def self.errors
    __native_available ? Backend.call('errors') : []
  end

  if __native_available
    OPENSSL_VERSION = Backend.call('version')
    OPENSSL_LIBRARY_VERSION = OPENSSL_VERSION
    OPENSSL_VERSION_NUMBER = Backend.call('version_number')
  end
end
