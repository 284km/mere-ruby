module PrivateHolder1104
  module Hidden
    X = 1
    module Inner
      X = 2
    end
  end
  private_constant :Hidden
  def self.lexical = [defined?(Hidden), defined?(Hidden::X), defined?(Hidden::Inner::X)]
end
PrivateAlias1104 = PrivateHolder1104
p defined?(PrivateHolder1104::Hidden)
p defined?(PrivateHolder1104::Hidden::X)
p defined?(PrivateHolder1104::Hidden::Inner::X)
p defined?(::PrivateHolder1104::Hidden::X)
p defined?(PrivateAlias1104::Hidden::X)
p PrivateHolder1104.lexical

module PrivateAncestor1104
  Secret = 3
  private_constant :Secret
end
class PrivateChild1104
  include PrivateAncestor1104
end
p defined?(PrivateChild1104::Secret)
p defined?(PrivateChild1104::Secret::X)

module PrivateHook1104
  Secret = 4
  private_constant :Secret
  def self.const_missing(name)
    $private_hook_1104 << name
    PrivateHolder1104
  end
end
$private_hook_1104 = []
p defined?(PrivateHook1104::Secret)
p $private_hook_1104
p defined?(PrivateHook1104::Secret::Hidden)
p $private_hook_1104

module PublicHolder1104
  module Inner
    X = nil
  end
end
p defined?(PublicHolder1104::Inner::X)
p defined?(::PublicHolder1104::Inner::X)
p defined?(PublicHolder1104::Inner::Missing)

# Object's top-level autoloads are keyed by the bare name. A scoped
# defined? query reports the pending constant without running its file.
require 'tmpdir'
Dir.mktmpdir do |dir|
  file = File.join(dir, 'pending.rb')
  File.write(file, "$autoload_1104_ran = true; module AutoloadPending1104; X = 1; end")
  Object.autoload(:AutoloadPending1104, file)
  p defined?(Object::AutoloadPending1104)
  p defined?(::AutoloadPending1104)
  p $autoload_1104_ran
  p defined?(Object::AutoloadPending1104::X)
  p $autoload_1104_ran
end
