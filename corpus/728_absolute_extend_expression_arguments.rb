module RootExtendFactory
  module Feature
    def feature; :root_feature; end
  end
  module Extra
    def extra; :extra_feature; end
  end
  def self.with(value)
    raise 'factory argument lost' unless value == :routes
    Feature
  end
  def self.itself; self; end
end

module ExtendLexicalScope
  RootExtendFactory = Module.new
  class Controller
    extend ::RootExtendFactory.with(:routes), ::RootExtendFactory::Extra
  end
  class Bare
    extend ::RootExtendFactory::Feature
  end
  class Rootless < BasicObject
    extend ::RootExtendFactory.with(:routes)
  end
  class Chained
    extend ::RootExtendFactory.itself.with(:routes)
  end
end
p [:rooted, ExtendLexicalScope::Controller.feature, ExtendLexicalScope::Controller.extra]
p [:bare, ExtendLexicalScope::Bare.feature]
p [:basic_object, ExtendLexicalScope::Rootless.feature]
p [:chain, ExtendLexicalScope::Chained.feature]

object = Object.new
object.instance_eval do
  extend ::RootExtendFactory.with(:routes) if true
  extend ::RootExtendFactory::Extra unless false
end
p [:modifiers, object.feature, object.extra]

skipped = Object.new
skipped.instance_eval do
  extend ::RootExtendFactory.with(:never) if false
end
p [:skipped, skipped.respond_to?(:feature)]

class OverrideExtend
  def self.extend(*modules)
    [:override, modules.map(&:name)]
  end
  RESULT = extend ::RootExtendFactory.with(:routes), ::RootExtendFactory::Extra
end
p [:override, OverrideExtend::RESULT]

begin
  Object.new.instance_eval { extend ::Object.new }
rescue TypeError
  puts 'non-module-rejected'
end

plain = Object.new
p [:parentheses, plain.extend(::RootExtendFactory::Feature).equal?(plain), plain.feature]
extend = Object.new
def extend.get; :local_receiver; end
p [:local_receiver, extend.get]
