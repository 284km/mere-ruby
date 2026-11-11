base = Class.new do
  def value
    :old
  end
end
object = base.new
unbound = object.method(:value).unbind
p [unbound.owner == base, unbound.name, unbound.bind(object).call]
base.class_eval do
  def value
    :new
  end
end
GC.start
p [unbound.bind(object).call, object.method(:value).unbind.bind(object).call]
base.class_eval { remove_method :value }
GC.start
p unbound.bind(object).call
begin
  object.method(:value).unbind
rescue NameError
  p :missing
end

refined_target = Class.new { def value; :base; end }
refinement = Module.new do
  refine refined_target do
    def value
      :refined
    end
  end
end
caller_class = Class.new do
  using refinement
  define_method(:read) do |receiver|
    receiver.method(:value).unbind
  end
end
receiver = refined_target.new
saved = caller_class.new.read(receiver)
GC.start
p [saved.bind(receiver).call, saved.name]

custom = Class.new do
  def method(name)
    Struct.new(:token) do
      def unbind
        token
      end
    end.new(name)
  end
end.new
p custom.method(:custom).unbind

module UnbindOverride
  refine Method do
    def unbind
      :overridden
    end
  end
end
class UnbindCaller
  using UnbindOverride
  def self.read(receiver)
    receiver.method(:to_s).unbind
  end
end
p UnbindCaller.read(Object.new)
