first = Class.new { def marker; :first_base; end }
second = Class.new { def marker; :second_base; end }
$native_snapshot_second = second
outer = Module.new do
  refine first do
    def helper; :outer_helper; end
  end
end
refinery = Module.new do
  using outer
  refine first do
    def marker; [helper, $native_snapshot_second.new.marker]; end
  end
  refine second do
    def marker; :later_refinement; end
  end
end
scope = Module.new do
  using outer
  using refinery
  def self.read(first, second); [first.marker, second.marker]; end
end
reader = scope.method(:read).to_proc
first_object, second_object = first.new, second.new
scope = refinery = outer = first = second = nil
8.times { GC.start }
p reader.call(first_object, second_object)
p [first_object.marker, second_object.marker]
8.times { GC.start }
p reader.call(first_object, second_object)
$native_snapshot_second = nil
