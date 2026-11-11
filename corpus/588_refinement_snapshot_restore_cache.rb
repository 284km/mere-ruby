module CachedRefinements
  refine String do
    def cached_label
      :first
    end
  end
end
class CachedCaller
  using CachedRefinements
  def self.label(value)
    value.cached_label
  end
end
30.times do |i|
  raise 'snapshot changed' unless CachedCaller.label('x') == :first
  GC.start if i % 5 == 0
end
module CachedRefinements
  refine String do
    def cached_label
      :second
    end
  end
end
30.times do |i|
  raise 'live refinement stale' unless CachedCaller.label('x') == :second
  GC.start if i % 5 == 0
end

saved = []
270.times do |i|
  target = Class.new { def value; :plain; end }
  refinement = Module.new do
    refine target do
      def value
        :refined
      end
    end
  end
  caller_class = Class.new do
    using refinement
    define_method(:read) { target.new.value }
  end
  saved << caller_class.new if i % 90 == 0
  raise 'restored scope changed' unless caller_class.new.read == :refined
end
GC.start
p saved.map(&:read)
p CachedCaller.label('x')
p 'refinement snapshot restore preserves live entries and retained callers'
