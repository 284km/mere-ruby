module OpenSSL
  module OCSP
    class OCSPError < OpenSSLError; end
    Backend.call('ocsp.constants').each { |name,value| const_set(name,value) } if OpenSSL.__native_available
    def self.der(value); PKey.string(value.respond_to?(:to_der) ? value.to_der : value); end
    def self.absolute_time(value)
      return Time.now.to_i+Backend.int32(value) if value.is_a?(Integer)
      raise TypeError, 'expected a Time' unless value.is_a?(Time)
      value.to_i
    end
    class CertificateId < NativeObject
      def initialize(*args)
        raise ArgumentError, 'wrong number of arguments' unless (1..3).include?(args.size)
        value=if args.size==1
          Backend.call('ocsp.cid.new',OCSP.der(args[0]))
        else
          Backend.call('ocsp.cid.new',nil,args[0],args[1],PKey.digest_name(args[2]))
        end
        __replace_native(value)
      end
      def cmp(other); Backend.call('ocsp.cid.cmp',self,other); end
      def cmp_issuer(other); Backend.call('ocsp.cid.cmp_issuer',self,other); end
      def serial; BN.new(Backend.call('ocsp.cid.serial',self)); end
      def issuer_name_hash; Backend.call('ocsp.cid.issuer_name_hash',self).unpack1('H*'); end
      def issuer_key_hash; Backend.call('ocsp.cid.issuer_key_hash',self).unpack1('H*'); end
      def hash_algorithm; Backend.call('ocsp.cid.hash_algorithm',self); end
      def to_der; Backend.call('ocsp.cid.to_der',self); end
    end
    class Request < NativeObject
      def initialize(data=nil); return self if data.nil? && __native_initialized?; __replace_native(Backend.call('ocsp.req.new',data.nil? ? nil : OCSP.der(data))); end
      def add_nonce(value=nil)
        X509.mutable(self)
        Backend.call('ocsp.req.add_nonce',self,value.nil? ? nil : PKey.string(value)); self
      end
      def check_nonce(response); Backend.call('ocsp.req.check_nonce',self,response); end
      def add_certid(id); X509.mutable(self); Backend.call('ocsp.req.add_certid',self,id); self; end
      def certid; Backend.call('ocsp.req.certid',self); end
      def signed?; Backend.call('ocsp.req.signed',self); end
      def sign(cert,key,certs=nil,flags=0,digest=nil)
        X509.mutable(self)
        Backend.call('ocsp.req.sign',self,cert,key,certs,flags.nil? ? 0 : Backend.int32(flags),PKey.digest_name(digest)); self
      end
      def verify(certs,store,flags=0); Backend.call('ocsp.req.verify',self,certs,store,flags.nil? ? 0 : Backend.int32(flags)); end
      def to_der; Backend.call('ocsp.req.to_der',self); end
    end
    class Response < NativeObject
      def initialize(data=nil); return self if data.nil? && __native_initialized?; __replace_native(Backend.call('ocsp.res.new',data.nil? ? nil : OCSP.der(data))); end
      def self.create(status,basic); Backend.call('ocsp.res.create',Backend.int32(status),basic); end
      def status; Backend.call('ocsp.res.status',self); end
      def status_string; Backend.call('ocsp.res.status_string',self); end
      def basic; Backend.call('ocsp.res.basic',self); end
      def to_der; Backend.call('ocsp.res.to_der',self); end
    end
    class BasicResponse < NativeObject
      def initialize(data=nil); return self if data.nil? && __native_initialized?; __replace_native(Backend.call('ocsp.bres.new',data.nil? ? nil : OCSP.der(data))); end
      def copy_nonce(request); X509.mutable(self); Backend.call('ocsp.bres.copy_nonce',self,request); end
      def add_nonce(value=nil)
        X509.mutable(self)
        Backend.call('ocsp.bres.add_nonce',self,value.nil? ? nil : PKey.string(value)); self
      end
      def add_status(id,status,reason,revtime,thisupd,nextupd,extensions)
        X509.mutable(self)
        status=Backend.int32(status)
        reason,revtime=status==V_CERTSTATUS_REVOKED ? [Backend.int32(reason),OCSP.absolute_time(revtime)] : [0,nil]
        Backend.call('ocsp.bres.add_status',self,id,status,reason,revtime,OCSP.absolute_time(thisupd),
                     nextupd.nil? ? nil : OCSP.absolute_time(nextupd),extensions)
        self
      end
      def responses; Backend.call('ocsp.bres.responses',self); end
      def find_response(id); Backend.call('ocsp.bres.find_response',self,id); end
      def status
        responses.map do |response|
          state=response.cert_status
          revoked=state==V_CERTSTATUS_REVOKED
          [response.certid,state,revoked ? response.revocation_reason : -1,
           revoked ? response.revocation_time : nil,response.this_update,response.next_update,response.extensions]
        end
      end
      def sign(cert,key,certs=nil,flags=0,digest=nil)
        X509.mutable(self)
        Backend.call('ocsp.bres.sign',self,cert,key,certs,flags.nil? ? 0 : Backend.int32(flags),PKey.digest_name(digest)); self
      end
      def verify(certs,store,flags=0); Backend.call('ocsp.bres.verify',self,certs,store,flags.nil? ? 0 : Backend.int32(flags)); end
      def to_der; Backend.call('ocsp.bres.to_der',self); end
    end
    class SingleResponse < NativeObject
      def initialize(data); __replace_native(Backend.call('ocsp.single.new',OCSP.der(data))); end
      def check_validity(seconds=0,max_seconds=-1)
        Backend.call('ocsp.single.check_validity',self,seconds.nil? ? 0 : Backend.int32(seconds),max_seconds.nil? ? -1 : Backend.int32(max_seconds))
      end
      def certid; Backend.call('ocsp.single.certid',self); end
      def cert_status; Backend.call('ocsp.single.cert_status',self); end
      def revocation_reason; Backend.call('ocsp.single.revocation_reason',self); end
      [:this_update,:next_update,:revocation_time].each do |field|
        define_method(field) do
          value=Backend.call('ocsp.single.'+field.to_s,self)
          value.nil? ? nil : Time.at(value).utc
        end
      end
      def extensions; Backend.call('ocsp.single.extensions',self); end
      def to_der; Backend.call('ocsp.single.to_der',self); end
    end
  end
end
