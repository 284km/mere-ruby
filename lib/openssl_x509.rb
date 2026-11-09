module OpenSSL
  module X509
    class NameError < OpenSSLError; end
    class ExtensionError < OpenSSLError; end
    class AttributeError < OpenSSLError; end
    class CertificateError < OpenSSLError; end
    class RequestError < OpenSSLError; end
    class CRLError < OpenSSLError; end
    class RevokedError < OpenSSLError; end
    class StoreError < OpenSSLError; end

    def self.string(value); ::OpenSSL::PKey.string(value); end
    def self.data(value); ::OpenSSL::PKey.data(value); end
    def self.mutable(object)
      raise FrozenError, "can't modify frozen #{object.class}" if object.frozen?
    end

    class Name < NativeObject
      include Comparable
      DEFAULT_OBJECT_TYPE = ASN1::UTF8STRING
      OBJECT_TYPE_TEMPLATE = Hash.new(DEFAULT_OBJECT_TYPE).merge(
        'C'=>ASN1::PRINTABLESTRING, 'countryName'=>ASN1::PRINTABLESTRING,
        'serialNumber'=>ASN1::PRINTABLESTRING, 'dnQualifier'=>ASN1::PRINTABLESTRING,
        'DC'=>ASN1::IA5STRING, 'domainComponent'=>ASN1::IA5STRING, 'emailAddress'=>ASN1::IA5STRING
      ).freeze
      COMPAT = 0
      RFC2253 = 17892119
      ONELINE = 8520479
      MULTILINE = 44302342
      def initialize(value = nil, template = OBJECT_TYPE_TEMPLATE)
        entries = value.is_a?(Array) ? value : (value.to_ary if value.respond_to?(:to_ary))
        __take(Backend.call('xname.new', entries || value.nil? ? nil : X509.data(value)))
        entries&.each do |entry|
          oid, text, type = entry
          add_entry(oid, text, type || template[oid] || DEFAULT_OBJECT_TYPE)
        end
      end
      def add_entry(oid, value, type = nil, loc: -1, set: 0)
        X509.mutable(self)
        Backend.call('xname.add', self, X509.string(oid), X509.string(value), type || OBJECT_TYPE_TEMPLATE[oid], Integer(loc), Integer(set))
        self
      end
      def to_der; Backend.call('xname.to_der', self); end
      def to_s(format = nil); Backend.call('xname.to_s', self, format.nil? ? nil : Integer(format)); end
      def to_utf8; Backend.call('xname.to_s', self, RFC2253 & ~4).force_encoding('UTF-8'); end
      def inspect; "#<#{self.class} #{to_utf8}>"; end
      def to_a
        Backend.call('xname.to_a', self).map { |oid, value, type| [oid, type == ASN1::UTF8STRING ? value.force_encoding('UTF-8') : value, type] }
      end
      def <=>(other); other.is_a?(Name) ? Backend.call('xname.cmp', self, other) : nil; end
      alias cmp <=>
      def ==(other); other.is_a?(Name) && (self <=> other) == 0; end
      alias eql? ==
      def hash; Backend.call('xname.hash', self); end
      def hash_old; Backend.call('xname.hash_old', self); end
    end

    class Extension < NativeObject
      def initialize(oid, value = nil, critical = false)
        object = if value.nil?
          Backend.call('xext.new', X509.data(oid))
        else
          Backend.call('xext.create', X509.string(oid), X509.data(value), true, !!critical)
        end
        __take(object)
      end
      def to_der; Backend.call('xext.to_der', self); end
      def oid; Backend.call('xext.oid', self); end
      def value; Backend.call('xext.value', self); end
      def value_der; Backend.call('xext.value_der', self); end
      def critical?; Backend.call('xext.critical', self); end
      def oid=(value); X509.mutable(self); Backend.call('xext.set_oid', self, X509.string(value)); value; end
      def value=(value); X509.mutable(self); Backend.call('xext.set_value', self, X509.data(value)); value; end
      def critical=(value); X509.mutable(self); Backend.call('xext.set_critical', self, !!value); value; end
    end
    class ExtensionFactory
      attr_accessor :issuer_certificate, :subject_certificate, :subject_request, :crl, :config
      def initialize(issuer = nil, subject = nil, request = nil, crl = nil)
        @issuer_certificate, @subject_certificate, @subject_request, @crl = issuer, subject, request, crl
      end
      def create_ext(oid, value, critical = false)
        text = X509.string(value)
        text = 'critical,' + text if critical
        Backend.call('xext.create', X509.string(oid), text, false, @issuer_certificate, @subject_certificate, @subject_request, @crl, @config&.to_s)
      end
    end

    class Attribute
      def initialize(oid, value = nil)
        if value.nil?
          source = ASN1.decode(X509.data(oid))
          raise AttributeError, 'invalid attribute' unless source.is_a?(ASN1::Sequence) && source.value.size == 2
          oid, value = source.value[0].oid, source.value[1]
        end
        self.oid = oid
        self.value = value
      end
      def oid; object = ASN1::ObjectId.new(@oid); object.sn || object.oid; end
      def oid=(value)
        X509.mutable(self)
        oid = ASN1::ObjectId.new(X509.string(value)).oid
        @oid = oid
        value
      rescue ASN1::ASN1Error
        raise AttributeError, 'invalid attribute OID'
      end
      def value; ASN1.decode(@value); end
      def value=(value)
        X509.mutable(self)
        raise TypeError, 'attribute value must be ASN1Data' unless value.is_a?(ASN1::ASN1Data)
        raise AttributeError, 'attribute value must be a universal SET' unless value.is_a?(ASN1::Set) && value.tag_class == :UNIVERSAL && value.tag == 17 && !value.tagging
        bytes = value.to_der
        ASN1.decode(bytes)
        @value = bytes
        value
      end
      def to_der; ASN1::Sequence.new([ASN1::ObjectId.new(@oid), ASN1.decode(@value)]).to_der; end
    end

    # Common field operations use checked native methods rather than keeping a
    # second, potentially stale Ruby copy of the mutable certificate state.
    module Fields
      def __get(field); Backend.call(self.class::NATIVE_PREFIX + '.' + field, self); end
      def __set(field, value)
        X509.mutable(self)
        Backend.call(self.class::NATIVE_PREFIX + '.set_' + field, self, value)
      end
      def to_der; __get('to_der'); end
      def to_pem; __get('to_pem'); end
      alias to_s to_pem
      def to_text; __get('to_text'); end
      def sign(key, digest)
        X509.mutable(self)
        Backend.call(self.class::NATIVE_PREFIX + '.sign', self, key, ::OpenSSL::PKey.digest_name(digest))
        self
      end
      def verify(key); Backend.call(self.class::NATIVE_PREFIX + '.verify', self, key); end
      def signature_algorithm; __get('signature_algorithm'); end
    end
    module Extensions
      def extensions; __get('extensions'); end
      def extensions=(values)
        X509.mutable(self)
        entries = values.to_ary
        entries.each { |entry| raise TypeError, 'expected X509::Extension' unless entry.is_a?(Extension) }
        __get('clear_extensions')
        entries.each { |entry| add_extension(entry) }
        values
      end
      def add_extension(value)
        X509.mutable(self)
        Backend.call(self.class::NATIVE_PREFIX + '.add_extension', self, value)
        value
      end
    end
    class Certificate < NativeObject
      NATIVE_PREFIX = 'xcert'
      include Fields
      include Extensions
      def initialize(value = nil); __take(Backend.call('xcert.new', value.nil? ? nil : X509.data(value))); end
      def version; __get('version'); end
      def version=(value); __set('version', Integer(value)); value; end
      def serial; BN.new(__get('serial')); end
      def serial=(value); __set('serial', BN.number(value).to_s); value; end
      def subject; __get('subject'); end
      def subject=(value); __set('subject', value); value; end
      def issuer; __get('issuer'); end
      def issuer=(value); __set('issuer', value); value; end
      def public_key; __get('public_key'); end
      def public_key=(value); __set('public_key', value); value; end
      def not_before; Time.at(__get('not_before')).utc; end
      def not_before=(value); __set('not_before', value.to_i); value; end
      def not_after; Time.at(__get('not_after')).utc; end
      def not_after=(value); __set('not_after', value.to_i); value; end
      def check_private_key(key); Backend.call('xcert.check_private_key', self, key); end
      def ==(other); other.is_a?(Certificate) && Backend.call('xcert.equal', self, other); end
      def tbs_precert_bytes; __get('tbs_precert_bytes'); end
      def tbs_bytes; __get('tbs_bytes'); end
      def self.load(value)
        source = X509.data(value)
        if source.include?('-----BEGIN CERTIFICATE-----')
          source.scan(/-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m).map { |pem| new(pem) }
        elsif source.empty? || !source.start_with?("\x30".b)
          raise CertificateError, 'Could not detect format of certificate data!'
        else
          [new(source)]
        end
      end
    end
    class Request < NativeObject
      NATIVE_PREFIX = 'xreq'
      include Fields
      def initialize(value = nil); __take(Backend.call('xreq.new', value.nil? ? nil : X509.data(value))); end
      def version; __get('version'); end
      def version=(value); __set('version', Integer(value)); value; end
      def subject; __get('subject'); end
      def subject=(value); __set('subject', value); value; end
      def public_key; __get('public_key'); end
      def public_key=(value); __set('public_key', value); value; end
      def attributes; __get('attributes').map { |der| Attribute.new(der) }; end
      def attributes=(values)
        X509.mutable(self)
        entries = values.to_ary
        entries.each { |entry| raise TypeError, 'expected X509::Attribute' unless entry.is_a?(Attribute) }
        __get('clear_attributes')
        entries.each { |entry| add_attribute(entry) }
        values
      end
      def add_attribute(value)
        X509.mutable(self)
        raise TypeError, 'expected X509::Attribute' unless value.is_a?(Attribute)
        Backend.call('xreq.add_attribute', self, value.to_der)
        value
      end
    end
    class CRL < NativeObject
      NATIVE_PREFIX = 'xcrl'
      include Fields
      include Extensions
      def initialize(value = nil); __take(Backend.call('xcrl.new', value.nil? ? nil : X509.data(value))); end
      def version; __get('version'); end
      def version=(value); __set('version', Integer(value)); value; end
      def issuer; __get('issuer'); end
      def issuer=(value); __set('issuer', value); value; end
      def last_update; Time.at(__get('last_update')).utc; end
      def last_update=(value); __set('last_update', value.to_i); value; end
      def next_update; Time.at(__get('next_update')).utc; end
      def next_update=(value); __set('next_update', value.to_i); value; end
      def revoked; __get('revoked'); end
      def revoked=(values)
        X509.mutable(self)
        entries = values.to_ary
        entries.each { |entry| raise TypeError, 'expected X509::Revoked' unless entry.is_a?(Revoked) }
        __get('clear_revoked')
        entries.each { |entry| add_revoked(entry) }
        values
      end
      def add_revoked(value); X509.mutable(self); Backend.call('xcrl.add_revoked', self, value); value; end
    end
    class Revoked < NativeObject
      NATIVE_PREFIX = 'xrev'
      include Fields
      include Extensions
      def initialize(value = nil); __take(Backend.call('xrev.new', value.nil? ? nil : X509.data(value))); end
      def serial; BN.new(__get('serial')); end
      def serial=(value); __set('serial', BN.number(value).to_s); value; end
      def time; Time.at(__get('time')).utc; end
      def time=(value); __set('time', value.to_i); value; end
    end
    class StoreContext < NativeObject; end
  end
end
module OpenSSL
  module X509
    Backend.call('x509.constants').each { |name, value| const_set(name, value) } if OpenSSL.__native_available
    class Store < NativeObject
      attr_accessor :verify_callback
      attr_reader :error, :error_string, :chain
      def initialize(*args)
        warn 'OpenSSL::X509::Store.new does not take any arguments' unless args.empty?
        __take(Backend.call('xstore.new'))
      end
      undef_method :initialize_copy
      def flags=(value); Backend.call('xstore.set_flags', self, Integer(value)); value; end
      def purpose=(value); Backend.call('xstore.set_purpose', self, Integer(value)); value; end
      def trust=(value); Backend.call('xstore.set_trust', self, Integer(value)); value; end
      def time=(value); Backend.call('xstore.set_time', self, value.to_i); value; end
      def add_file(value); Backend.call('xstore.add_file', self, X509.string(value)); self; end
      def add_path(value); Backend.call('xstore.add_path', self, X509.string(value)); self; end
      def set_default_paths; Backend.call('xstore.default_paths', self); nil; end
      def add_cert(value); Backend.call('xstore.add_cert', self, value); self; end
      def add_crl(value); Backend.call('xstore.add_crl', self, value); self; end
      def verify(certificate, chain = nil, &block)
        context = StoreContext.new(self, certificate, chain)
        context.verify_callback = block || @verify_callback
        result = context.verify
        @error, @error_string, @chain = context.error, context.error_string, context.chain
        result
      ensure
        context&.__close_native
      end
    end
    class StoreContext
      attr_accessor :verify_callback
      undef_method :initialize_copy
      def initialize(store, certificate = nil, chain = nil)
        __take(Backend.call('xctx.new', store, certificate, chain))
        @verify_callback = store.verify_callback
      end
      def verify
        begin
          Backend.call('xctx.start', self, !@verify_callback.nil?)
          loop do
            step = Backend.call('xctx.poll', self)
            case step[0]
            when 'done' then return step[1]
            when 'pending' then sleep(0.001)
            when 'callback'
              begin
                accepted = @verify_callback.call(step[1], self) == true
              rescue Exception
                warn 'exception in verify_callback is ignored'
                accepted = false
              end
              Backend.call('xctx.respond', self, accepted)
            else raise StoreError, 'invalid verification state'
            end
          end
        ensure
          Backend.call('xctx.stop', self)
        end
      end
      def error; Backend.call('xctx.error', self); end
      def error=(value); Backend.call('xctx.set_error', self, Integer(value)); value; end
      def error_string; Backend.call('xctx.error_string', self); end
      def error_depth; Backend.call('xctx.error_depth', self); end
      def chain; Backend.call('xctx.chain', self); end
      def current_cert; Backend.call('xctx.current_cert', self); end
      def current_crl; Backend.call('xctx.current_crl', self); end
      def flags=(value); Backend.call('xctx.set_flags', self, Integer(value)); value; end
      def purpose=(value); Backend.call('xctx.set_purpose', self, Integer(value)); value; end
      def trust=(value); Backend.call('xctx.set_trust', self, Integer(value)); value; end
      def time=(value); Backend.call('xctx.set_time', self, value.to_i); value; end
    end
  end
end
