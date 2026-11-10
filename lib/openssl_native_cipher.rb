if OpenSSL.__native_available
  module OpenSSL
    module Backend
      class CipherContext < NativeObject; end
    end
    class Cipher
      def initialize(name)
        raise RuntimeError, 'Cipher already initialized' if @native
        @native = Backend.call('cipher.new', OpenSSL.__str(name))
      end
      def initialize_copy(other); @native=Backend.call('object.copy', other.instance_variable_get(:@native)); end
      private :initialize_copy
      def __provider(operation, *args)
        raise RuntimeError, 'Cipher not initialized!' unless @native
        Backend.call('cipher.' + operation, @native, *args)
      end
      def self.ciphers; Backend.call('cipher.list').map(&:downcase).uniq.sort; end
      def name; __provider('info')[0]; end
      def key_len; __provider('info')[1]; end
      def iv_len; __provider('info')[2]; end
      def block_size; __provider('info')[3]; end
      def authenticated?; __provider('info')[4]; end
      def encrypt; __provider('encrypt'); self; end
      def decrypt; __provider('decrypt'); self; end
      def reset; __provider('reset'); self; end
      def key_len=(value); __provider('set_key_length', Integer(value)); value; end
      def iv_len=(value); __provider('set_iv_length', Integer(value)); value; end
      def key=(value); __provider('set_key', OpenSSL.__str(value)); value; end
      def iv=(value); __provider('set_iv', OpenSSL.__str(value)); value; end
      def padding=(value); __provider('set_padding', Integer(value)!=0); value; end
      def update(value, buffer = nil)
        raise FrozenError, "can't modify frozen String" if buffer && buffer.frozen?
        result=__provider('update', OpenSSL.__str(value))
        if buffer
          encoding = buffer.encoding
          buffer.replace(result).force_encoding(encoding)
        else
          result
        end
      end
      def final; __provider('final'); end
      def random_key; self.key=Random.random_bytes(key_len); end
      def random_iv; self.iv=Random.random_bytes(iv_len); end
      def pkcs5_keyivgen(password, salt = nil, iterations = 2048, digest = 'MD5')
        __provider('pkcs5_keyivgen', OpenSSL.__str(password), salt.nil? ? nil : OpenSSL.__str(salt), iterations.nil? ? 2048 : Integer(iterations), digest.nil? ? 'MD5' : digest.is_a?(Digest) ? digest.name : OpenSSL.__str(digest))
        nil
      end
      def auth_data=(value); __provider('auth_data', OpenSSL.__str(value)); value; end
      def auth_tag=(value); __provider('set_auth_tag', OpenSSL.__str(value)); value; end
      def auth_tag(length = nil); __provider('auth_tag', length.nil? ? nil : Integer(length)); end
      def auth_tag_len=(value); __provider('auth_tag_length', Integer(value)); value; end
      def ccm_data_len=(value); __provider('ccm_data_length', Integer(value)); value; end
    end
  end
end
