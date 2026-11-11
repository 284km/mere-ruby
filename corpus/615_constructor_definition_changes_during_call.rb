# The initializer being executed remains alive when it replaces its own
# definition and collection occurs before the original call returns.
klass = Class.new do
  attr_reader :events
  def initialize
    @events = [:before]
    self.class.class_eval do
      def initialize
        @events = [:replacement]
      end
    end
    GC.start
    @events << :after
  end
end
first = klass.new
second = klass.new
p [first.events, second.events]

# Inherited and prepended initializers retain their real defining owner.
parent = Class.new do
  attr_reader :events
  def initialize
    @events = [:parent]
  end
end
child = Class.new(parent) do
  def initialize
    super
    @events << :child
  end
end
wrapper = Module.new do
  def initialize
    super
    @events << :wrapper
  end
end
child.prepend(wrapper)
p child.new.events

plain = Class.new do
  attr_reader :values
  def initialize(**keywords)
    @values = keywords
  end
end
p plain.new.values
