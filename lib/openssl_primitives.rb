if OpenSSL.__native_available
  module OpenSSL
    module Backend
      class DigestContext < NativeObject; end
      class HMACContext < NativeObject; end
    end
    class HMACError < OpenSSLError; end
    class Digest
      def initialize(name, data = nil)
        name = name.name if name.is_a?(Digest)
        @native = Backend.call('digest.new', OpenSSL.__str(name))
        @name, @digest_length, @block_length = Backend.call('digest.info', @native)
        update(data) unless data.nil?
      end
      def initialize_copy(other)
        @native = Backend.call('object.copy', other.instance_variable_get(:@native))
      end
      private :initialize_copy
      def name; @name.dup; end
      def digest_length; @digest_length; end
      alias size digest_length
      alias length digest_length
      def block_length; @block_length; end
      def update(data); Backend.call('digest.update', @native, OpenSSL.__str(data)); self; end
      alias << update
      def reset; Backend.call('digest.reset', @native); self; end
      def digest(*args)
        raise ArgumentError, 'wrong number of arguments' if args.size>1
        unless args.empty?
          reset
          update(args[0])
        end
        result = Backend.call('digest.final', @native)
        reset unless args.empty?
        result
      end
      def digest!; result=digest; reset; result; end
      def hexdigest(*args); digest(*args).unpack1('H*'); end
      def hexdigest!; digest!.unpack1('H*'); end
      def base64digest(*args); [digest(*args)].pack('m0'); end
      def base64digest!; [digest!].pack('m0'); end
      alias to_s hexdigest
      def ==(other); other.is_a?(Digest) && digest==other.digest; end
      def self.digest(name, data = nil)
        __algo ? new(name).digest : new(name, OpenSSL.__str(data)).digest
      end
      def self.hexdigest(name, data = nil); digest(name, data).unpack1('H*'); end
      def self.base64digest(name, data = nil); [digest(name, data)].pack('m0'); end
      def self.digests; Backend.call('digest.list').uniq.sort; end
      class SHA224 < Digest
        def self.__algo; 'SHA224'; end
        def initialize(data = nil); super('SHA224', data); end
      end
    end
    def self.Digest(name); Digest.const_get(OpenSSL.__str(name)); end

    class HMAC
      def initialize(key, digest)
        digest = digest.name if digest.is_a?(Digest)
        @native = Backend.call('hmac.new', OpenSSL.__str(key), OpenSSL.__str(digest))
      end
      def initialize_copy(other); @native=Backend.call('object.copy', other.instance_variable_get(:@native)); end
      private :initialize_copy
      def update(value); Backend.call('hmac.update', @native, OpenSSL.__str(value)); self; end
      alias << update
      def reset; Backend.call('hmac.reset', @native); self; end
      def digest; Backend.call('hmac.final', @native); end
      def hexdigest; digest.unpack1('H*'); end
      def base64digest; [digest].pack('m0'); end
      alias to_s hexdigest
      def ==(other); other.is_a?(HMAC) && OpenSSL.fixed_length_secure_compare(digest, other.digest); end
      def self.digest(digest, key, data); new(key,digest).update(data).digest; end
      def self.hexdigest(digest,key,data); self.digest(digest,key,data).unpack1('H*'); end
      def self.base64digest(digest,key,data); [self.digest(digest,key,data)].pack('m0'); end
    end
    module KDF
      class KDFError < OpenSSLError; end
      def self.hash_name(hash); hash.is_a?(Digest) ? hash.name : OpenSSL.__str(hash); end
      # NUM2INT's conversion: an Integer, or what answers #to_int, else
      # "no implicit conversion" (Kernel#Integer's message is "can't convert")
      def self.__int(v)
        return v if v.is_a?(Integer)
        return v.to_int if !v.nil? && v.respond_to?(:to_int)
        raise TypeError, v.nil? ? "no implicit conversion from nil to integer" : "no implicit conversion of #{v.class} into Integer"
      end
      # the digest by name, as ossl_evp_md_fetch refuses an unknown one
      def self.__digest_name(hash)
        return hash.name if hash.is_a?(Digest)
        name = OpenSSL.__str(hash)
        begin
          Digest.new(name)
        rescue Digest::DigestError => e
          raise Digest::DigestError, "unsupported digest algorithm: #{name}: #{e.message.sub(/\A.*?error:[0-9A-F]+:[^:]*::/, '')}"
        end
        name
      end
      def self.pbkdf2_hmac(password, salt:, iterations:, length:, hash:)
        pw = OpenSSL.__str(password)
        sl = OpenSSL.__str(salt)
        iter = __int(iterations)
        len = __int(length)
        md = __digest_name(hash)
        raise KDFError, "PKCS5_PBKDF2_HMAC: invalid iteration count" if iter <= 0
        Backend.call('kdf.pbkdf2', pw, sl, len, iter, md)
      end
      # (N cannot be a keyword PARAMETER -- a constant is no formal argument --
      #  so the keywords are read the way ossl_kdf_scrypt's rb_get_kwargs reads
      #  them: all five required, named in ruby's order when missing)
      def self.scrypt(password, **kw)
        names = %i[salt N r p length]
        missing = names.reject { |k| kw.key?(k) }
        unless missing.empty?
          raise ArgumentError, "missing keyword#{missing.size > 1 ? 's' : ''}: #{missing.map(&:inspect).join(', ')}"
        end
        extra = kw.keys - names
        raise ArgumentError, "unknown keyword#{extra.size > 1 ? 's' : ''}: #{extra.map(&:inspect).join(', ')}" unless extra.empty?
        cost = __int(kw[:N]); r = __int(kw[:r]); p = __int(kw[:p]); len = __int(kw[:length])
        raise ArgumentError, "negative string size (or size too big)" if len < 0
        if cost < 2 || (cost & (cost - 1)) != 0 || r <= 0 || p <= 0
          raise KDFError, "EVP_PBE_scrypt: invalid parameter"
        end
        Backend.call('kdf.scrypt', OpenSSL.__str(password), OpenSSL.__str(kw[:salt]), len, cost, r, p)
      end
      def self.hkdf(key, salt:, info:, length:, hash:)
        Backend.call('kdf.hkdf', OpenSSL.__str(key), OpenSSL.__str(salt), __int(length), OpenSSL.__str(info), hash_name(hash))
      end
    end
    module PKCS5
      def self.pbkdf2_hmac(password,salt,iterations,length,hash)
        KDF.pbkdf2_hmac(password,salt: salt,iterations: iterations,length: length,hash: hash)
      end
      def self.pbkdf2_hmac_sha1(password,salt,iterations,length)
        pbkdf2_hmac(password,salt,iterations,length,'SHA1')
      end
    end
    class Provider < NativeObject
      class ProviderError < OpenSSLError; end
      private_class_method :new
      def self.load(name); Backend.call('provider.load', OpenSSL.__str(name)); end
      def self.provider_names; Backend.call('provider.list'); end
      def name; Backend.call('provider.name', self); rescue TypeError; raise ProviderError, 'provider was unloaded'; end
      def unload
        name
        __close_native
      end
      def inspect; "#<#{self.class} name=#{name}>"; end
    end
    def self.fips_mode=(enabled)
      Backend.call('set_fips_mode', !!enabled)
      enabled
    end
  end
end
