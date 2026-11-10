module OpenSSL
  module Timestamp
    class TimestampError < OpenSSLError; end
    class Request < NativeObject
      def initialize(*args)
        raise ArgumentError, 'wrong number of arguments' if args.size>1
        return self if args.empty? && __native_initialized?
        __replace_native(Backend.call('ts.req.new',args.empty? ? nil : PKey.data(args[0])))
      end
      def version; Backend.call('ts.req.version',self); end
      def version=(value); X509.mutable(self); Backend.call('ts.req.set_version',self,Backend.int64(value)); value; end
      def algorithm; Backend.call('ts.req.algorithm',self); end
      def algorithm=(value); X509.mutable(self); Backend.call('ts.req.set_algorithm',self,Backend.c_string(value)); value; end
      def message_imprint; Backend.call('ts.req.message_imprint',self); end
      def message_imprint=(value); X509.mutable(self); Backend.call('ts.req.set_message_imprint',self,PKey.string(value)); value; end
      def policy_id; Backend.call('ts.req.policy_id',self); end
      def policy_id=(value); X509.mutable(self); Backend.call('ts.req.set_policy_id',self,Backend.c_string(value)); value; end
      def nonce; value=Backend.call('ts.req.nonce',self); value.nil? ? nil : BN.new(value); end
      def nonce=(value); X509.mutable(self); Backend.call('ts.req.set_nonce',self,BN.number(value).to_s); value; end
      def cert_requested?; Backend.call('ts.req.cert_requested',self); end
      def cert_requested=(value); X509.mutable(self); Backend.call('ts.req.set_cert_requested',self,!!value); value; end
      def to_der; Backend.call('ts.req.to_der',self); end
      def to_text; Backend.call('ts.req.to_text',self); end
    end
    class TokenInfo < NativeObject
      def initialize(data); __replace_native(Backend.call('ts.info.new',PKey.data(data))); end
      [:version,:policy_id,:algorithm,:message_imprint,:ordering].each do |field|
        define_method(field) { Backend.call('ts.info.'+field.to_s,self) }
      end
      [:nonce,:serial_number].each do |field|
        define_method(field) { value=Backend.call('ts.info.'+field.to_s,self); value.nil? ? nil : BN.new(value) }
      end
      def gen_time; Time.at(Backend.call('ts.info.gen_time',self)).utc; end
      def to_der; Backend.call('ts.info.to_der',self); end
      def to_text; Backend.call('ts.info.to_text',self); end
    end
    class Response < NativeObject
      GRANTED=0
      GRANTED_WITH_MODS=1
      REJECTION=2
      WAITING=3
      REVOCATION_WARNING=4
      REVOCATION_NOTIFICATION=5
      def initialize(data); __replace_native(Backend.call('ts.res.new',PKey.data(data))); end
      def status; Backend.call('ts.res.status',self); end
      def status_text; Backend.call('ts.res.status_text',self).map { |v| v.force_encoding('UTF-8') }; end
      def failure_info; Backend.call('ts.res.failure_info',self)&.to_sym; end
      def token; Backend.call('ts.res.token',self); end
      def token_info; Backend.call('ts.res.token_info',self); end
      def tsa_certificate; Backend.call('ts.res.tsa_certificate',self); end
      def verify(request,store,intermediates=nil); Backend.call('ts.res.verify',self,request,store,intermediates); self; end
      def to_der; Backend.call('ts.res.to_der',self); end
      def to_text; Backend.call('ts.res.to_text',self); end
    end
    class Factory
      attr_accessor :allowed_digests,:default_policy_id,:serial_number,:gen_time,:additional_certs
      def create_timestamp(key,cert,request)
        raise TypeError, 'expected a PKey' unless key.is_a?(PKey::PKey)
        raise TypeError, 'expected a Certificate' unless cert.is_a?(X509::Certificate)
        raise TypeError, 'expected a Timestamp::Request' unless request.is_a?(Request)
        raise TimestampError, '@gen_time must be a Time.' unless @gen_time.instance_of?(Time)
        raise TimestampError, '@serial_number must be set.' if @serial_number.nil?
        policy=request.policy_id.nil? ? @default_policy_id : nil
        raise TimestampError, 'No policy id in the request and no default policy set' if request.policy_id.nil? && policy.nil?
        policy=Backend.c_string(policy) unless policy.nil?
        digests=@allowed_digests.is_a?(Array) ? @allowed_digests.map { |md| md.is_a?(Digest) ? md.name : Backend.c_string(md) } : []
        certs=@additional_certs.is_a?(Array) ? @additional_certs : nil
        Backend.call('ts.create',key,cert,request,BN.number(@serial_number).to_s,
                     Backend.int64(@gen_time.to_i),policy,digests,certs)
      end
    end
  end
end
