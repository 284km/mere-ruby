module OpenSSL
  class NativeObject
    def __native_id
      OpenSSL.__native_handle(self)
    end
    def __adopt(id)
      OpenSSL.__native_bind(self, id)
      self
    end
    def __take(other)
      OpenSSL.__native_move(other, self)
      self
    end
    def __close_native
      OpenSSL.__native_release(self)
    end
    def initialize_copy(other)
      __take(Backend.call('object.copy', other))
    end
  end

  module Backend
    class KeygenJob < NativeObject; end
    def self.generate(algorithm, options, parameters, &block)
      job = call('keygen.start', algorithm, options, parameters)
      begin
        loop do
          step = call('keygen.poll', job)
          case step[0]
          when 'done' then return step[1]
          when 'progress'
            block.call(*step[1]) if block
            call('keygen.respond', job)
          when 'pending' then sleep(0.001)
          else raise OpenSSLError, 'invalid generation job state'
          end
        end
      ensure
        job.__close_native
      end
    end
    def self.wrap(name, handle)
      begin
        Object.const_get(name).allocate.__adopt(handle)
      rescue Exception
        call('object.release', handle)
        raise
      end
    end
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
      when NativeObject then pack(value.__native_id)
      else raise TypeError, 'unsupported provider argument'
      end.b
    end

    def self.item(source, position, owners = [])
      kind = source.getbyte(position)
      position += 1
      case kind
      when 110 then return [nil, position]
      when 116 then return [true, position]
      when 102 then return [false, position]
      when 101
        name, position = item(source, position, owners)
        message, position = item(source, position, owners)
        raise Object.const_get(name), message
      end
      raise OpenSSLError, 'invalid provider response' unless position + 4 <= source.bytesize
      size = source.byteslice(position, 4).unpack1('N')
      position += 4
      case kind
      when 104
        name, position = item(source, position, owners)
        value = wrap(name, size)
        owners << value
        [value, position]
      when 105, 115
        raise OpenSSLError, 'invalid provider string' unless position + size <= source.bytesize
        text = source.byteslice(position, size)
        [kind == 105 ? text.to_i : text, position + size]
      when 97, 109
        values = []
        (kind == 109 ? size * 2 : size).times do
          value, position = item(source, position, owners)
          values << value
        end
        [kind == 109 ? values.each_slice(2).to_h : values, position]
      else raise OpenSSLError, 'invalid provider response type'
      end
    end

    def self.call(operation, *args)
      raise NotImplementedError, 'native OpenSSL provider is unavailable on this target' unless OpenSSL.__native_available
      # Do not deliver an asynchronous exception between native allocation and
      # installing its Ruby owner. Native jobs yield outside this small region.
      owners = []
      delivered = false
      result = Thread.handle_interrupt(Object => :never) do
        source = OpenSSL.__native_call(operation, pack(args))
        value, position = item(source, 0, owners)
        raise OpenSSLError, 'trailing provider response' unless position == source.bytesize
        value
      end
      delivered = true
      result
    ensure
      # A deferred interrupt may be raised as the mask ends. Such a response
      # never reached its caller, so dispose all of its native objects now,
      # including handles already decoded from an incomplete response.
      if owners && !delivered
        Thread.handle_interrupt(Object => :never) do
          owners.each { |owner| owner.__close_native }
        end
      end
    end
  end

  def self.errors
    __native_available ? Backend.call('errors') : []
  end
  def self.fips_mode
    __native_available && Backend.call('fips_mode')
  end

  if __native_available
    OPENSSL_VERSION = Backend.call('version')
    OPENSSL_LIBRARY_VERSION = OPENSSL_VERSION
    OPENSSL_VERSION_NUMBER = Backend.call('version_number')
  end
end
