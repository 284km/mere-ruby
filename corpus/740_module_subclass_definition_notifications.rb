class ObservableMethodFactory < Module
  attr_reader :added
  def method_added(name)
    (@added ||= []) << [name, instance_method(name).name == name, private_method_defined?(name)]
  end
end
class InheritedMethodFactory < ObservableMethodFactory; end
factory = InheritedMethodFactory.new
factory.define_method(:first) { :first }
factory.define_method(:second, proc { :second })
factory.define_method(:initialize) { }
factory.define_method(:identity, Kernel.instance_method(:itself))
source = Module.new { def original; :copied; end }
factory.define_method(:copied, source.instance_method(:original))
p factory.added
klass = Class.new { include factory }
p [klass.new.first, klass.new.second, klass.new.copied, klass.new.identity.class == klass]
factory.freeze
begin
  factory.define_method(:refused) { :never }
rescue => error
  p [error.class, factory.added.size]
end
singleton = Module.new
class << singleton
  attr_reader :added
  def method_added(name); (@added ||= []) << name; end
end
singleton.define_method(:plain) { :plain }
p singleton.added
custom = ObservableMethodFactory.new
class << custom
  def method_added(name); (@singleton_added ||= []) << name; end
  attr_reader :singleton_added
end
custom.define_method(:selected) { :selected }
p [custom.singleton_added, custom.added]
class RaisingMethodFactory < Module
  attr_reader :calls
  def method_added(name)
    @calls = (@calls || 0) + 1
    raise 'notification failed'
  end
end
raising = RaisingMethodFactory.new
begin
  raising.define_method(:retained) { :retained }
rescue => error
  p [error.class, error.message, raising.calls]
end
p Class.new { include raising }.new.retained

# A global Module callback also receives the original object exactly once.
events = []
observer_class = Class.new(Module)
observed = observer_class.new
Module.class_eval do
  alias_method :__review_original_added, :method_added
  define_method(:method_added) do |name|
    events << [equal?(observed), self.class.equal?(observer_class), name] if name == :seen
  end
end
observed.define_method(:seen) { :seen }
p events
Module.class_eval do
  alias_method :method_added, :__review_original_added
  remove_method :__review_original_added
end
fresh=Class.new(Module).new
trace_events=[]
trace=TracePoint.new(:c_call,:c_return) do |event|
  trace_events << [event.event,event.defined_class == Module,event.self.equal?(fresh)] if event.method_id == :method_added && event.self.equal?(fresh)
end
trace.enable { fresh.define_method(:ordinary) { :ordinary } }
p [:native,trace_events]
class NativeAliasObserverFactory < Module
  define_method(:method_added,Module.instance_method(:method_added))
end
aliased=NativeAliasObserverFactory.new
trace_events=[]
trace=TracePoint.new(:c_call,:c_return) do |event|
  trace_events << [event.event,event.defined_class == NativeAliasObserverFactory,event.self.equal?(aliased)] if event.method_id == :method_added && event.self.equal?(aliased)
end
trace.enable { aliased.define_method(:observed) { :observed } }
p [:alias_native,trace_events]
undefined=Class.new(Module).new
undefined.singleton_class.class_eval { undef_method :method_added }
missing_events=[]
undefined.define_singleton_method(:method_missing) { |name,*args| missing_events << [name,args] }
undefined.define_method(:retained) { :retained }
p [:undefined,missing_events,Class.new { include undefined }.new.retained]
object_events=[]
Object.class_eval do
  define_method(:method_added) { |name| object_events << name if name == :behind_module }
end
fresh.define_method(:behind_module) { :kept }
p [:native_before_object,object_events]
Object.class_eval { remove_method :method_added }
