module OpenSSL
  module Backend
    def self.int32(value)
      original = value
      value = value.to_int if !value.is_a?(Integer) && value.respond_to?(:to_int)
      raise TypeError, "no implicit conversion of #{original.class} into Integer" unless value.is_a?(Integer)
      raise RangeError, 'integer out of range for int' unless (-2147483648..2147483647).include?(value)
      value
    end
    def self.c_string(value)
      text = PKey.string(value)
      raise ArgumentError, 'string contains null byte' if text.include?("\0")
      text
    end
  end
  class PKCS12 < NativeObject
    class PKCS12Error < OpenSSLError; end
    KEY_SIG = 128
    KEY_EX = 16
    attr_reader :key, :certificate, :ca_certs
    def self.create(password, name, key, cert, ca = nil, key_pbe = nil, cert_pbe = nil,
                    key_iter = nil, mac_iter = nil, keytype = nil)
      password = Backend.c_string(password) unless password.nil?
      name = Backend.c_string(name) unless name.nil?
      key_pbe = Backend.c_string(key_pbe) unless key_pbe.nil?
      cert_pbe = Backend.c_string(cert_pbe) unless cert_pbe.nil?
      key_iter, mac_iter, keytype = [key_iter, mac_iter, keytype].map { |v| v.nil? ? 0 : Backend.int32(v) }
      value = Backend.call('pkcs12.create', password, name, key, cert, ca, key_pbe, cert_pbe, key_iter, mac_iter, keytype)
      value.instance_variable_set(:@key, key)
      value.instance_variable_set(:@certificate, cert)
      value.instance_variable_set(:@ca_certs, ca)
      value
    end
    def initialize(*args)
      raise ArgumentError, 'wrong number of arguments' if args.length > 2
      data = args.empty? ? nil : PKey.data(args[0])
      password = args[1].nil? ? nil : Backend.c_string(args[1])
      native, key, cert, ca = Backend.call('pkcs12.new', data, password)
      __close_native
      __take(native)
      @key, @certificate, @ca_certs = key, cert, ca
    end
    def to_der; Backend.call('pkcs12.to_der', self); end
    def set_mac(password, salt = nil, iterations = nil, digest = nil)
      X509.mutable(self)
      Backend.call('pkcs12.set_mac', self, PKey.string(password), salt.nil? ? nil : PKey.string(salt),
                   iterations.nil? ? 0 : Backend.int32(iterations), PKey.digest_name(digest))
      nil
    end
  end
end
