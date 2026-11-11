klass = Class.new do
  def marker; :original; end
end
object = klass.new
saved = object.method(:marker)
p [saved.receiver.equal?(object), saved.owner.equal?(klass), saved.name, saved.call]
klass.class_eval { def marker; :replacement; end }
p [saved.call, object.method(:marker).call]
klass.send(:remove_method, :marker)
8.times { GC.start }
p saved.call
begin
  object.method(:marker)
rescue NameError => error
  p error.class
end

custom = Class.new do
  def method(name); [:override, name]; end
end.new
p custom.method(:marker)
missing = Class.new do
  def respond_to_missing?(name, include_private)
    $native_method_missing_probes << [name, include_private]
    name == :marker
  end
  def method_missing(name, *arguments); [:missing, name, arguments]; end
end.new
$native_method_missing_probes = []
p missing.method(:marker).call(7)
p $native_method_missing_probes

target = Class.new { def marker; :base; end }
refinery = Module.new do
  refine target do
    def marker; :refined; end
  end
end
scope = Module.new do
  using refinery
  def self.read(object); object.method(:marker); end
end
refined_method = scope.read(target.new)
scope = refinery = nil
8.times { GC.start }
p [refined_method.call, refined_method.unbind.bind(refined_method.receiver).call]
p object.method(:object_id).call == object.object_id

# String coercion and builtin reflection retain their full protocols.
coercible = Object.new
def coercible.to_str; 'object_id'; end
p object.method(coercible).call == object.object_id
$native_method_missing_probes = nil
