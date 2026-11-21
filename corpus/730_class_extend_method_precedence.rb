module ExtendDispatchScope
  class MimeType
    class << self
      def extend(type, extensions: [], &block)
        [type, extensions, block ? block.call(:ruby) : :no_block]
      end
    end
  end
end
p [:explicit, ExtendDispatchScope::MimeType.extend('text/plain', extensions: ['txt'])]
p [:block, ExtendDispatchScope::MimeType.extend('text/html', extensions: ['html']) { |kind| kind }]
class ExtendDispatchChild < ExtendDispatchScope::MimeType
end
p [:inherited, ExtendDispatchChild.extend('text/plain')]
module ExtendDispatchModule
  def self.extend(argument)
    [:module_override, argument]
  end
end
p ExtendDispatchModule.extend(:value)

module ExtendDispatchFeature
  def feature; :installed; end
end
class NativeExtendDelegation
  class << self
    alias saved_extend extend
    def extend(*modules)
      [:delegated, defined?(super), super(*modules).equal?(self)]
    end
  end
end
p NativeExtendDelegation.extend(ExtendDispatchFeature)
p [:super_feature, NativeExtendDelegation.feature]
p [:saved, NativeExtendDelegation.saved_extend(ExtendDispatchFeature).equal?(NativeExtendDelegation)]

class PrivateExtendOverride
  class << self
    def extend(value); [:private_override, value]; end
    private :extend
  end
end
begin
  PrivateExtendOverride.extend(:value)
rescue NoMethodError => error
  p [:private, error.name]
end
p PrivateExtendOverride.send(:extend, :value)

class UndefinedExtendOverride
  class << self
    undef_method :extend
  end
end
begin
  UndefinedExtendOverride.extend(ExtendDispatchFeature)
rescue NoMethodError => error
  p [:undefined, error.name]
end

begin
  Class.new.extend('not a module')
rescue TypeError
  puts 'native-type-checked'
end

class UndefinedExtendParent
  class << self
    undef_method :extend
  end
end
class UndefinedExtendChild < UndefinedExtendParent
  def self.extend(*modules)
    [defined?(super), super(*modules)]
  rescue NoMethodError => error
    [defined?(super), error.name]
  end
end
p [:super_undef, UndefinedExtendChild.extend(ExtendDispatchFeature)]
class ZeroExtendOverride
  def self.extend; :zero_arguments; end
end
p [:zero_arguments, ZeroExtendOverride.extend]
