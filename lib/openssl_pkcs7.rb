module OpenSSL
  class PKCS7 < NativeObject
    class PKCS7Error < OpenSSLError; end
    {TEXT:1, NOCERTS:2, NOSIGS:4, NOCHAIN:8, NOINTERN:16, NOVERIFY:32,
     DETACHED:64, BINARY:128, NOATTR:256, NOSMIMECAP:512}.each { |name,value| const_set(name,value) }
    attr_reader :data
    attr_accessor :error_string
    def initialize(*args)
      raise ArgumentError, 'wrong number of arguments' if args.size>1
      native=Backend.call('pkcs7.new', args.empty? ? nil : PKey.data(args[0]))
      __close_native
      __take(native)
      @data=@error_string=nil
    end
    def self.sign(cert,key,data,certs=nil,flags=0)
      data=PKey.data(data)
      value=Backend.call('pkcs7.sign',cert,key,data,certs,flags.nil? ? 0 : Backend.int32(flags))
      value.instance_variable_set(:@data,data)
      value.instance_variable_set(:@error_string,nil)
      value
    end
    def self.encrypt(certs,data,cipher=nil,flags=0)
      raise ArgumentError, 'cipher must be specified; the former default was RC2-40-CBC' if cipher.nil?
      cipher=cipher.name if cipher.is_a?(Cipher)
      data=PKey.data(data)
      value=Backend.call('pkcs7.encrypt',certs,data,Backend.c_string(cipher),flags.nil? ? 0 : Backend.int32(flags))
      value.instance_variable_set(:@data,data)
      value.instance_variable_set(:@error_string,nil)
      value
    end
    def self.read_smime(data)
      value,body=Backend.call('pkcs7.read_smime',PKey.data(data))
      value.instance_variable_set(:@data,body)
      value.instance_variable_set(:@error_string,nil)
      value
    end
    def self.write_smime(value,data=nil,flags=0)
      data=value.data if data.nil?
      Backend.call('pkcs7.write_smime',value,data.nil? ? nil : PKey.data(data),flags.nil? ? 0 : Backend.int32(flags))
    end
    def type; Backend.call('pkcs7.type',self)&.to_sym; end
    def type=(value)
      X509.mutable(self)
      Backend.call('pkcs7.set_type',self,value.is_a?(Symbol) ? value.to_s : Backend.c_string(value))
      value
    end
    def detached; Backend.call('pkcs7.detached',self); end
    def detached?; Backend.call('pkcs7.detached_p',self); end
    def detached=(value)
      X509.mutable(self)
      raise PKCS7Error, 'must specify a boolean' unless value==true || value==false
      Backend.call('pkcs7.set_detached',self,value)
      value
    end
    def cipher=(value)
      X509.mutable(self)
      Backend.call('pkcs7.set_cipher',self,Backend.c_string(value.is_a?(Cipher) ? value.name : value))
      value
    end
    [:signer,:recipient,:certificate,:crl].each do |part|
      define_method('add_'+part.to_s) do |value|
        X509.mutable(self)
        Backend.call('pkcs7.add_'+part.to_s,self,value)
        self
      end
    end
    [:signers,:recipients,:certificates,:crls].each do |part|
      define_method(part) { Backend.call('pkcs7.'+part.to_s,self) }
    end
    def certificates=(values)
      X509.mutable(self)
      Backend.call('pkcs7.clear_certificates',self)
      values.each { |value| add_certificate(value) }
      values
    end
    def crls=(values)
      X509.mutable(self)
      Backend.call('pkcs7.clear_crls',self)
      values.each { |value| add_crl(value) }
      values
    end
    def add_data(value)
      X509.mutable(self)
      data=PKey.data(value)
      Backend.call('pkcs7.add_data',self,data)
      @data=nil
      data
    end
    alias data= add_data
    def verify(certs,store,data=nil,flags=0)
      X509.mutable(self)
      data=@data if data.nil?
      ok,@data,@error_string=Backend.call('pkcs7.verify',self,certs,store,data.nil? ? nil : PKey.data(data),flags.nil? ? 0 : Backend.int32(flags))
      ok
    end
    def decrypt(key,cert=nil,flags=0); Backend.call('pkcs7.decrypt',self,key,cert,flags.nil? ? 0 : Backend.int32(flags)); end
    def to_der; Backend.call('pkcs7.to_der',self); end
    def to_pem; Backend.call('pkcs7.to_pem',self); end
    alias to_s to_pem
    def to_text; Backend.call('pkcs7.to_text',self); end
    class SignerInfo < NativeObject
      def initialize(cert,key,digest); __take(Backend.call('p7si.new',cert,key,PKey.digest_name(digest))); end
      def issuer; Backend.call('p7si.issuer',self); end
      def serial; Backend.call('p7si.serial',self).to_i; end
      def signed_time; value=Backend.call('p7si.signed_time',self); value.nil? ? nil : Time.at(value).utc; end
    end
    Signer=SignerInfo
    class RecipientInfo < NativeObject
      def initialize(cert); __take(Backend.call('p7ri.new',cert)); end
      def issuer; Backend.call('p7ri.issuer',self); end
      def serial; Backend.call('p7ri.serial',self).to_i; end
      def enc_key; Backend.call('p7ri.enc_key',self); end
    end
  end
end
