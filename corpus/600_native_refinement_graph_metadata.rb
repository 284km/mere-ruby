target = Class.new { def marker; :base; end }
refinery = Module.new
first = refinery.module_eval do
  refine target do
    def marker; :refined; end
  end
end
second = refinery.module_eval do
  refine target do
    def other_marker; :reopened; end
  end
end
p [first.equal?(second), refinery.refinements == [first], first.target.equal?(target)]
scope = Module.new do
  using refinery
  def self.read(object); [object.marker, object.other_marker]; end
end
object = target.new
reader = scope.method(:read)
target = refinery = second = scope = nil
8.times { GC.start }
p [first.target.equal?(object.class), first.instance_methods(false).sort]
p reader.call(object)
reader = object = nil
8.times { GC.start }
p [first.target.new.marker, first.instance_methods(false).sort]
