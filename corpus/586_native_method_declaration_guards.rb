# Native declaration scopes retain method visibility, lexical scope and
# redefinition observers. A class_eval body still returns its final symbol.
module DeclarationHome
  VALUE = :lexical
  def self.build
    Class.new do
      def value
        VALUE
      end
    end
  end
end
p DeclarationHome.build.new.value

owner = Class.new
p owner.class_eval { def item; :old; end }
warnings = []
Warning.singleton_class.send(:define_method, :warn) do |message, **options|
  warnings << message if message.include?('method redefined')
end
$VERBOSE = true
p owner.class_eval { def item; :new; end }
$VERBOSE = false
p [owner.new.item, warnings.size]

p owner.class_eval { def initialize(value = :default); @value = value; end }
p owner.private_instance_methods(false).include?(:initialize)
owner.class_eval { attr_reader :value }
p [owner.new.value, owner.new(:explicit).value]

hooked = Class.new
events = []
hooked.define_singleton_method(:method_added) { |name| events << name }
p hooked.class_eval { def observed; :called; end }
p [hooked.new.observed, events]
