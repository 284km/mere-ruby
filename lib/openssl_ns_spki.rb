module OpenSSL
  module Netscape
    class SPKIError < OpenSSLError; end
    class SPKI < NativeObject
      def initialize(*args)
        raise ArgumentError, 'wrong number of arguments' if args.size>1
        __take(Backend.call('spki.new',args.empty? ? nil : PKey.string(args[0])))
      end
      def to_der; Backend.call('spki.to_der',self); end
      def to_pem; Backend.call('spki.to_pem',self); end
      def to_text; Backend.call('spki.to_text',self); end
      def public_key; Backend.call('spki.public_key',self); end
      def public_key=(value); X509.mutable(self); Backend.call('spki.set_public_key',self,value); value; end
      def challenge; Backend.call('spki.challenge',self); end
      def challenge=(value); X509.mutable(self); Backend.call('spki.set_challenge',self,PKey.string(value)); value; end
      def sign(key,digest)
        X509.mutable(self)
        name=digest.is_a?(Digest) ? digest.name : Backend.c_string(digest)
        Backend.call('spki.sign',self,key,name)
        self
      end
      def verify(key); Backend.call('spki.verify',self,key); end
    end
  end
end
