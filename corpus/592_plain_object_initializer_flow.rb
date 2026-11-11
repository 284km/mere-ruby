klass = Class.new do
  attr_reader :info
  def initialize
    @info = [__method__, __callee__, block_given?]
    super()
    :ignored_return
  end
end
p klass.new.info
p klass.new.class == klass

included = Module.new do
  def initialize
    @value = :included
  end
end
with_include = Class.new do
  include included
  attr_reader :value
end
p with_include.new.value
included.module_eval do
  def initialize
    @value = :redefined
  end
end
p with_include.new.value

required = Class.new { def initialize(value); end }
begin
  required.new
rescue ArgumentError
  p :arity_preserved
end

raising = Class.new do
  def initialize
    begin
      raise ArgumentError, "initializer"
    ensure
      $initializer_ensure = :ran
    end
  end
end
begin
  raising.new
rescue ArgumentError => error
  p [error.message, $initializer_ensure]
end

nested = Class.new do
  def initialize
    @inner = Class.new { def initialize; @ok = true; end; attr_reader :ok }.new
  end
  def ok
    @inner.ok
  end
end
p nested.new.ok

custom = Class.new do
  def initialize
    @value = :ordinary
  end
  attr_reader :value
end
custom.define_singleton_method(:new) { :custom }
p custom.new
