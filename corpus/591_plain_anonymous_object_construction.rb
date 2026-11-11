plain = Class.new { def value; :plain; end }
first = plain.new
second = plain.new
p [first.class == plain, second.class == plain, first.equal?(second), first.value]
plain.freeze
p plain.new.class == plain
begin
  plain.new(:argument)
rescue ArgumentError
  p :arity_preserved
end

initialized = Class.new do
  def initialize
    @value = :initialized
  end
  attr_reader :value
end
p initialized.new.value
mixin = Module.new { def initialize; @value = :included; end }
included = Class.new { include mixin; attr_reader :value }
p included.new.value
custom = Class.new
custom.define_singleton_method(:new) { :factory }
p custom.new

copy = Time.dup
value = copy.new
p [value.class == copy, value.is_a?(Time)]

seen = []
trace = TracePoint.new(:c_call) do |event|
  seen << event.method_id if [:new, :initialize].include?(event.method_id)
end
trace.enable { plain.new }
p [seen.include?(:new), seen.include?(:initialize)]

private_factory = Class.new
private_factory.private_class_method(:new)
begin
  private_factory.new
rescue NoMethodError
  p :private_refused
end
p private_factory.send(:new).class == private_factory

module NewRefinement
  refine Class do
    def new
      :refined_factory
    end
  end
end
class RefinedNewCaller
  using NewRefinement
  def self.make(klass)
    klass.new
  end
end
p RefinedNewCaller.make(Class.new)
