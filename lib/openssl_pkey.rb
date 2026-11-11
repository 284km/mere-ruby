module OpenSSL
  module PKey
    class PKeyError < OpenSSLError; end
    class PasswordRequired < PKeyError; end

    def self.string(value)
      text = OpenSSL.__str(value)
      raise TypeError, 'no implicit conversion into String' unless text.is_a?(String)
      text
    end
    def self.data(value)
      value = value.read if value.is_a?(IO)
      value = value.to_der if value.respond_to?(:to_der)
      string(value)
    end
    def self.options(value)
      raise TypeError, "wrong argument type #{value.class} (expected Hash)" unless value.is_a?(Hash)
      result = {}
      value.each { |k, v| result[string(k)] = v.to_s }
      result
    end
    def self.digest_name(value)
      return nil if value.nil?
      value.is_a?(OpenSSL::Digest) ? value.name : string(value)
    end
    def self.read(value, password = nil, &block)
      read_kind(nil, value, password, &block)
    end
    def self.read_kind(kind, value, password = nil, &block)
      bytes = data(value)
      password = string(password) unless password.nil?
      begin
        Backend.call('pkey.read', bytes, password, kind)
      rescue PasswordRequired => error
        raise PKeyError, error.message unless block && password.nil?
        password = block.call(false)
        raise PKeyError, 'password callback did not return a String' if password.nil?
        begin
          Backend.call('pkey.read', bytes, string(password), kind)
        rescue PasswordRequired => failure
          raise PKeyError, failure.message
        end
      end
    end
    def self.generate_key(algorithm, options = {}, &block)
      Backend.generate(algorithm, self.options(options), false, &block)
    end
    def self.generate_parameters(algorithm, options = {}, &block)
      Backend.generate(algorithm, self.options(options), true, &block)
    end
    def self.new_raw_private_key(algorithm, data)
      Backend.call('pkey.new_raw_private_key', string(algorithm), string(data))
    end
    def self.new_raw_public_key(algorithm, data)
      Backend.call('pkey.new_raw_public_key', string(algorithm), string(data))
    end

    class PKey < NativeObject
      def initialize
        raise TypeError, 'PKey is an abstract class'
      end
      def oid; Backend.call('pkey.oid', self); end
      def inspect
        "#<#{self.class}:#{object_id} oid=#{oid} type_name=#{Backend.call('pkey.type_name', self)}>"
      end
      def private?; Backend.call('pkey.private', self); end
      def public?; Backend.call('pkey.public', self); end
      def to_text; Backend.call('pkey.to_text', self); end
      def export_format(format, cipher = nil, password = nil, &block)
        cipher = cipher.is_a?(OpenSSL::Cipher) ? cipher.name : ::OpenSSL::PKey.string(cipher) unless cipher.nil?
        password = block.call(true) if cipher && password.nil? && block
        password = ::OpenSSL::PKey.string(password) unless password.nil?
        raise PKeyError, 'password required' if cipher && password.nil?
        Backend.call('pkey.export', self, format, cipher, password)
      end
      private :export_format
      def private_to_der(*args, &block); export_format('private_der', *args, &block); end
      def private_to_pem(*args, &block); export_format('private_pem', *args, &block); end
      def public_to_der; export_format('public_der'); end
      def public_to_pem; export_format('public_pem'); end
      def raw_private_key; Backend.call('pkey.raw_private_key', self); end
      def raw_public_key; Backend.call('pkey.raw_public_key', self); end
      def compare?(other); Backend.call('pkey.compare', self, other); end
      def sign(digest, data, options = {})
        Backend.call('pkey.sign', self, ::OpenSSL::PKey.digest_name(digest), ::OpenSSL::PKey.string(data), ::OpenSSL::PKey.options(options))
      end
      def verify(digest, signature, data, options = {})
        Backend.call('pkey.verify', self, ::OpenSSL::PKey.digest_name(digest), ::OpenSSL::PKey.string(signature), ::OpenSSL::PKey.string(data), ::OpenSSL::PKey.options(options))
      end
      def sign_raw(digest, data, options = {})
        Backend.call('pkey.sign_raw', self, ::OpenSSL::PKey.digest_name(digest), ::OpenSSL::PKey.string(data), ::OpenSSL::PKey.options(options))
      end
      def verify_raw(digest, signature, data, options = {})
        Backend.call('pkey.verify_raw', self, ::OpenSSL::PKey.digest_name(digest), ::OpenSSL::PKey.string(signature), ::OpenSSL::PKey.string(data), ::OpenSSL::PKey.options(options))
      end
      def verify_recover(digest, signature, options = {})
        Backend.call('pkey.verify_recover', self, ::OpenSSL::PKey.digest_name(digest), ::OpenSSL::PKey.string(signature), ::OpenSSL::PKey.options(options))
      end
      def encrypt(data, options = {})
        Backend.call('pkey.encrypt', self, ::OpenSSL::PKey.string(data), ::OpenSSL::PKey.options(options))
      end
      def decrypt(data, options = {})
        Backend.call('pkey.decrypt', self, ::OpenSSL::PKey.string(data), ::OpenSSL::PKey.options(options))
      end
      def derive(other, options = {})
        raise TypeError, 'expected an OpenSSL::PKey' unless other.is_a?(PKey)
        Backend.call('pkey.derive', self, other, ::OpenSSL::PKey.options(options))
      end
    end

    class RSA < PKey
      PKCS1_PSS_PADDING = 6
      def initialize(value, password = nil, &block)
        key = value.is_a?(RSA) ? Backend.call('object.copy', value) : OpenSSL::PKey.read_kind('RSA', value, password, &block)
        raise PKeyError, 'incorrect pkey type' unless key.is_a?(RSA)
        __take(key)
      end
      def to_der; export_format('traditional_der'); end
      def export(*args, &block); export_format('traditional_pem', *args, &block); end
      alias to_pem export
      alias to_s export  # (ossl_pkey_*.c: to_s is export, as to_pem is)
      def sign_pss(digest, data, salt_length:, mgf1_hash:)
        salt = {digest: -1, max: -2}.fetch(salt_length, salt_length)
        sign(digest, data, {'rsa_padding_mode'=>'pss','rsa_pss_saltlen'=>salt,'rsa_mgf1_md'=>::OpenSSL::PKey.digest_name(mgf1_hash)})
      end
      def verify_pss(digest, signature, data, salt_length:, mgf1_hash:)
        salt = {digest: -1, auto: -2}.fetch(salt_length, salt_length)
        verify(digest, signature, data, {'rsa_padding_mode'=>'pss','rsa_pss_saltlen'=>salt,'rsa_mgf1_md'=>::OpenSSL::PKey.digest_name(mgf1_hash)})
      end
    end
    class DSA < PKey
      def initialize(value, password = nil, &block)
        key = value.is_a?(DSA) ? Backend.call('object.copy', value) : OpenSSL::PKey.read_kind('DSA', value, password, &block)
        raise PKeyError, 'incorrect pkey type' unless key.is_a?(DSA)
        __take(key)
      end
      def to_der; export_format('traditional_der'); end
      def export(*args, &block); export_format('traditional_pem', *args, &block); end
      alias to_pem export
      alias to_s export  # (ossl_pkey_*.c: to_s is export, as to_pem is)
    end
    class DH < PKey
      def initialize(value, password = nil, &block)
        key = value.is_a?(DH) ? Backend.call('object.copy', value) : OpenSSL::PKey.read_kind('DH', value, password, &block)
        raise PKeyError, 'incorrect pkey type' unless key.is_a?(DH)
        __take(key)
      end
      def to_der; export_format('traditional_der'); end
      def export; export_format('traditional_pem'); end
      alias to_pem export
      alias to_s export  # (ossl_pkey_*.c: to_s is export, as to_pem is)
      def params_ok?; Backend.call('pkey.params_ok', self); end
    end
    class EC < PKey
      NAMED_CURVE = 1
      EXPLICIT_CURVE = 0
      class Group < NativeObject; end
      class Point < NativeObject; end
      def initialize(value, password = nil, &block)
        key = value.is_a?(EC) ? Backend.call('object.copy', value) : OpenSSL::PKey.read(value, password, &block)
        raise PKeyError, 'incorrect pkey type' unless key.is_a?(EC)
        __take(key)
      end
      def to_der; export_format('traditional_der'); end
      def export(*args, &block); export_format('traditional_pem', *args, &block); end
      alias to_pem export
      def check_key; Backend.call('pkey.check', self); end
      def private_key; text = Backend.call('pkey.get_bn', self, 'priv'); text.nil? ? nil : BN.new(text); end
    end
  end
end

module OpenSSL
  module PKey
    class RSA
      def n; text = Backend.call('pkey.get_bn', self, 'n'); text.nil? ? nil : BN.new(text); end
      def e; text = Backend.call('pkey.get_bn', self, 'e'); text.nil? ? nil : BN.new(text); end
      def d; text = Backend.call('pkey.get_bn', self, 'd'); text.nil? ? nil : BN.new(text); end
      def p; text = Backend.call('pkey.get_bn', self, 'rsa-factor1'); text.nil? ? nil : BN.new(text); end
      def q; text = Backend.call('pkey.get_bn', self, 'rsa-factor2'); text.nil? ? nil : BN.new(text); end
      def dmp1; text = Backend.call('pkey.get_bn', self, 'rsa-exponent1'); text.nil? ? nil : BN.new(text); end
      def dmq1; text = Backend.call('pkey.get_bn', self, 'rsa-exponent2'); text.nil? ? nil : BN.new(text); end
      def iqmp; text = Backend.call('pkey.get_bn', self, 'rsa-coefficient1'); text.nil? ? nil : BN.new(text); end
    end
    class DSA
      def p; text = Backend.call('pkey.get_bn', self, 'p'); text.nil? ? nil : BN.new(text); end
      def q; text = Backend.call('pkey.get_bn', self, 'q'); text.nil? ? nil : BN.new(text); end
      def g; text = Backend.call('pkey.get_bn', self, 'g'); text.nil? ? nil : BN.new(text); end
      def pub_key; text = Backend.call('pkey.get_bn', self, 'pub'); text.nil? ? nil : BN.new(text); end
      def priv_key; text = Backend.call('pkey.get_bn', self, 'priv'); text.nil? ? nil : BN.new(text); end
    end
    class DH
      def p; text = Backend.call('pkey.get_bn', self, 'p'); text.nil? ? nil : BN.new(text); end
      def q; text = Backend.call('pkey.get_bn', self, 'q'); text.nil? ? nil : BN.new(text); end
      def g; text = Backend.call('pkey.get_bn', self, 'g'); text.nil? ? nil : BN.new(text); end
      def pub_key; text = Backend.call('pkey.get_bn', self, 'pub'); text.nil? ? nil : BN.new(text); end
      def priv_key; text = Backend.call('pkey.get_bn', self, 'priv'); text.nil? ? nil : BN.new(text); end
    end
  end
end
