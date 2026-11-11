plain = Class.new
plain.freeze
p plain.new.class.equal?(plain)
initialized = Class.new do
  def initialize
    @marker = :initialized
  end
  attr_reader :marker
end
p initialized.new.marker
begin
  Class.new { def initialize(required); end }.new
rescue ArgumentError => error
  p error.class
end

mixin = Module.new { def initialize; @marker = :included; end }
included = Class.new { include mixin; attr_reader :marker }
p included.new.marker
custom = Class.new { def self.new; :custom; end }
p custom.new
hidden = Class.new
hidden.private_class_method(:new)
begin
  hidden.new
rescue NoMethodError => error
  p [error.class, error.name]
end
p hidden.send(:new).class.equal?(hidden)

refined = Class.new
refinery = Module.new do
  refine refined.singleton_class do
    def new; :refined_constructor; end
  end
end
scope = Module.new
# An ordinary method definition carries the lexical refinement snapshot.
scope.module_eval do
  using refinery
  def self.construct_from(object); object.new; end
end
p scope.construct_from(refined)
p refined.new.class.equal?(refined)

callbacks = []
traced = Class.new do
  define_method(:initialize) { callbacks << :initialize }
end
events = []
trace = TracePoint.new(:c_call, :c_return) do |event|
  events << event.event if event.method_id == :new && event.self.equal?(traced)
end
trace.enable { traced.new }
p [callbacks, events]
8.times { GC.start }
p [initialized.new.marker, included.new.marker, custom.new]
