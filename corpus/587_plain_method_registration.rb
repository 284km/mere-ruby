module RegistrationScope
  TOKEN = :lexical
  C = Class.new do
    def read(value = TOKEN)
      value
    end
    def initialize(value = 7)
      @value = value
    end
    def value
      @value
    end
  end
end
c = RegistrationScope::C.new
p [c.read, c.read(:argument), c.value]
p [RegistrationScope::C.private_method_defined?(:initialize), RegistrationScope::C.public_method_defined?(:read)]
p RegistrationScope::C.instance_method(:read).parameters
p RegistrationScope::C.instance_method(:read).source_location.last > 0

base = Class.new do
  private
  def hidden
    :base
  end
end
child = Class.new(base) do
  private :hidden
  public
  def hidden
    :child
  end
end
p [child.new.hidden, child.public_method_defined?(:hidden)]
klass = Class.new do
  def repeat
    :first
  end
  def repeat
    :second
  end
  def self.singleton_value
    :singleton
  end
end
p [klass.new.repeat, klass.singleton_value]
klass.freeze
begin
  klass.class_eval do
    def refused
      :bad
    end
  end
rescue FrozenError
  p :frozen
end

warnings = []
Warning.singleton_class.send(:define_method, :warn) { |message, **_kw| warnings << message }
Class.new do
  def __send__(*args)
    :custom
  end
end
p warnings.any? { |message| message.include?("redefining '__send__'") }

seen = []
hooked = Class.new do
  define_singleton_method(:method_added) { |name| seen << name }
  def hooked_value
    :hooked
  end
end
p [seen, hooked.new.hooked_value]
