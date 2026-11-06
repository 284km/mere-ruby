# Class/module receivers ask the same public-method surface they can call.
p [defined?(Process.kill), defined?(Process.pid), defined?(Math.sqrt),
   defined?(Time.utc), defined?(File.read), defined?(String.new)]
p [defined?(Process.not_a_method), defined?(Math.not_a_method),
   defined?(Process.kill(undefined_argument))]
p [defined?(Object.print), defined?(Object.sleep), defined?(Kernel.print)]
calls = []
p defined?(Process.kill(calls << :argument, Process.pid))
p calls
class DefinedClassSurface
  def instance_only; end
  def self.public_method; end
  class << self
    protected
    def protected_method; end
    private
    def private_method; end
  end
end
p [defined?(DefinedClassSurface.instance_only),
   defined?(DefinedClassSurface.public_method),
   defined?(DefinedClassSurface.protected_method),
   defined?(DefinedClassSurface.private_method)]
class DefinedChildSurface < DefinedClassSurface
  class << self
    alias renamed public_method
    undef_method :public_method
  end
end
p [defined?(DefinedChildSurface.public_method), defined?(DefinedChildSurface.renamed)]
class DefinedNoNew
  class << self
    undef_method :new
  end
end
p defined?(DefinedNoNew.new)
module DefinedDynamicSurface
  def self.respond_to_missing?(name, private_ok = false)
    name == :dynamic || super
  end
  def self.method_missing(name, *)
    return :dynamic if name == :dynamic
    super
  end
end
p [defined?(DefinedDynamicSurface.dynamic), defined?(DefinedDynamicSurface.absent)]
module DefinedOverrideSurface
  def self.respond_to?(*)
    raise 'defined? must not ask the override'
  end
end
p defined?(DefinedOverrideSurface.absent)
# The queried builtin is available, and querying it sends no signal.
p Process.kill(0, Process.pid) if defined?(Process.kill)
