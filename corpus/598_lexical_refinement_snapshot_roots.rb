target = Class.new { def marker; :base; end }
first = Module.new do
  refine target do
    def marker; :first; end
  end
end
second = Module.new do
  refine target do
    def marker; :second; end
  end
end
first_scope = Module.new do
  using first
  def self.read(object); object.marker; end
end
second_scope = Module.new do
  using second
  def self.read(object); object.marker; end
end
readers = [first_scope.method(:read).to_proc, second_scope.method(:read).to_proc]
first_scope = second_scope = nil
value = target.new
target = first = second = nil
10.times { GC.start }
p [readers[0].call(value), readers[1].call(value), value.marker]
saved = readers.shift
readers = nil
10.times { GC.start }
p [saved.call(value), value.marker]
