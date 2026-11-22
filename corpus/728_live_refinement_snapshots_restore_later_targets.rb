# Live refinement scopes must see targets added later without changing the
# fixed scope captured by an earlier using declaration.
$snapshot_base = Class.new do
  def value; :base; end
end
$snapshot_other = Class.new do
  def value; :other_base; end
end

refinery = Module.new do
  refine $snapshot_base do
    def probe(other)
      [value, other.value, Module.used_refinements.map do |r|
        r.target.equal?($snapshot_base) ? :base : :other
      end]
    end
  end
end

client = Class.new do
  using refinery
  def probe(base, other); base.probe(other); end
  def direct(other); other.value; end
end.new

p client.probe($snapshot_base.new, $snapshot_other.new)
refinery.module_eval do
  refine $snapshot_other do
    def value; :other_refined; end
  end
end
GC.start
p client.probe($snapshot_base.new, $snapshot_other.new)
p client.direct($snapshot_other.new)

refinery.module_eval do
  refine $snapshot_base do
    def value; :base_refined; end
  end
end
GC.start
p client.probe($snapshot_base.new, $snapshot_other.new)
p refinery.refinements.map { |r| r.target.equal?($snapshot_base) ? :base : :other }
refinery = nil
3.times { GC.start }
p client.probe($snapshot_base.new, $snapshot_other.new)
