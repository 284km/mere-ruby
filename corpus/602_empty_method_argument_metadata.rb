parent = Class.new do
  def call(*arguments, **keywords, &block)
    [arguments, keywords, block && block.call]
  end
end
child = Class.new(parent) do
  def call
    super
  end
end
object = child.new
p object.call
p object.call(**{}) { :block }
p [object.method(:call).arity, object.method(:call).parameters]
begin
  object.call(:unexpected)
rescue ArgumentError => error
  p error.class
end

# The explicit-block super expression has a separate evaluator entry.
explicit_block = Class.new(parent) do
  def call
    super { :explicit }
  end
end
p explicit_block.new.call(**{})

# Nonempty parameter metadata still forwards the current values, including
# defaults and replaced positional/keyword parameters.
changed = Class.new(parent) do
  def call(value = :default, **keywords)
    value = :changed
    keywords[:added] = true
    super
  end
end
p changed.new.call(original: true) { :forwarded }

retained = []
12.times do
  retained << Class.new(parent) do
    def call
      super
    end
  end.new.method(:call)
end
8.times { GC.start }
p retained.map { |method| [method.call(**{}), method.parameters] }.uniq
