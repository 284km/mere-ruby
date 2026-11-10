module OpenSSL
  module PKey
    class EC
      FORMS = {compressed: 2, uncompressed: 4, hybrid: 6}.freeze
      def self.form_number(value)
        FORMS.fetch(value) { raise ArgumentError, 'invalid point conversion form' }
      end
      def self.builtin_curves
        Backend.call('ec_group.curves')
      end
      def self.generate(group)
        parameters = group.is_a?(Group) ? EC.new(group) : OpenSSL::PKey.generate_parameters('EC', {'ec_paramgen_curve'=>OpenSSL::PKey.string(group)})
        OpenSSL::PKey.generate_key(parameters)
      end
      def initialize(value, password = nil, &block)
        if value.is_a?(EC)
          key = Backend.call('object.copy', value)
        elsif value.is_a?(Group)
          key = OpenSSL::PKey.read_kind('EC', value.to_der)
        else
          begin
            key = OpenSSL::PKey.read_kind('EC', value, password, &block)
          rescue PKeyError
            # EC.new also accepts the name of a curve and creates parameters.
            raise unless value.is_a?(String) && value.match?(/\A[A-Za-z0-9_-]+\z/)
            key = OpenSSL::PKey.generate_parameters('EC', {'ec_paramgen_curve'=>value})
          end
        end
        raise PKeyError, 'incorrect pkey type' unless key.is_a?(EC)
        __take(key)
      end
      def group; Backend.call('pkey.ec_group', self); end
      def public_key; Backend.call('pkey.ec_point', self); end
      def generate_key!
        raise PKeyError, 'pkeys are immutable on OpenSSL 3.0'
      end
      alias generate_key generate_key!

      class Group
        class Error < PKeyError; end
        def initialize(*args)
          if args.length == 1
            source = args[0]
            object = source.is_a?(Group) ? Backend.call('object.copy', source) : Backend.call('ec_group.new', OpenSSL::PKey.data(source))
          elsif args.length == 4
            object = Backend.call('ec_group.new', args[0].to_s, *args[1..].map { |n| BN.number(n).to_s })
          else
            raise ArgumentError, "wrong number of arguments (given #{args.length}, expected 1 or 4)"
          end
          __take(object)
        end
        def ==(other); other.is_a?(Group) && Backend.call('ec_group.equal', self, other); end
        alias eql? ==
        def curve_name; Backend.call('ec_group.curve_name', self); end
        def degree; Backend.call('ec_group.degree', self); end
        def generator; Backend.call('ec_group.generator', self); end
        def order; BN.new(Backend.call('ec_group.order', self)); end
        def cofactor; BN.new(Backend.call('ec_group.cofactor', self)); end
        def asn1_flag; Backend.call('ec_group.asn1_flag', self); end
        def asn1_flag=(flag); Backend.call('ec_group.set_asn1_flag', self, Integer(flag)); flag; end
        def point_conversion_form; FORMS.key(Backend.call('ec_group.form', self)); end
        def point_conversion_form=(form); Backend.call('ec_group.set_form', self, EC.form_number(form)); form; end
        def seed; Backend.call('ec_group.seed', self); end
        def seed=(value); Backend.call('ec_group.set_seed', self, OpenSSL::PKey.string(value)); value; end
        def set_generator(point, order, cofactor)
          raise TypeError, 'expected an EC point' unless point.is_a?(Point)
          Backend.call('ec_group.set_generator', self, point, BN.number(order).to_s, BN.number(cofactor).to_s)
          self
        end
        def to_der; Backend.call('ec_group.to_der', self); end
        def to_pem; Backend.call('ec_group.to_pem', self); end
        def to_text; Backend.call('ec_group.to_text', self); end
      end

      class Point
        class Error < PKeyError; end
        def initialize(group, source = nil)
          if group.is_a?(Point) && source.nil?
            @group = group.group
            __take(Backend.call('object.copy', group))
          else
            raise TypeError, 'expected an EC group' unless group.is_a?(Group)
            @group = group
            source = source.to_s(2) if source.is_a?(BN)
            source = OpenSSL::PKey.string(source) unless source.nil?
            __take(Backend.call('ec_point.new', group, source))
          end
        end
        def group; @group ||= Backend.call('ec_point.group', self); end
        def ==(other); other.is_a?(Point) && Backend.call('ec_point.equal', self, other); end
        alias eql? ==
        def infinity?; Backend.call('ec_point.infinity', self); end
        def on_curve?; Backend.call('ec_point.on_curve', self); end
        def invert!; Backend.call('ec_point.invert', self); self; end
        def set_to_infinity!; Backend.call('ec_point.infinity_set', self); self; end
        def make_affine!; self; end
        def to_octet_string(form)
          Backend.call('ec_point.octets', self, EC.form_number(form))
        end
        def add(other)
          raise TypeError, 'expected an EC point' unless other.is_a?(Point)
          Backend.call('ec_point.add', self, other)
        end
        def mul(scalar, generator = nil)
          raise NotImplementedError, 'mul with arrays was removed' if scalar.is_a?(Array) || generator.is_a?(Array)
          Backend.call('ec_point.mul', self, BN.number(scalar).to_s, generator.nil? ? nil : BN.number(generator).to_s)
        end
      end
    end
  end
end
