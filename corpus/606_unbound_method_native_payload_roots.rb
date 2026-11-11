base = Class.new do
  private
  def answer; :base; end
end
child = Class.new(base) { public :answer }
unbound = child.instance_method(:answer)
copies = [unbound, unbound.dup, unbound.clone]
object = child.new
base = child = unbound = nil
8.times { GC.start }
p copies.map { |item| [item.bind(object).call, item.owner.equal?(object.class), item.name, item.parameters] }
p copies.map(&:hash).uniq.length

parent = Class.new { def answer; :parent; end }
child = Class.new(parent) { def answer; :child; end }
above = child.instance_method(:answer).super_method
copies = [above, above.dup, above.clone]
object = child.new
parent = child = above = nil
8.times { GC.start }
p copies.map { |item| [item.bind_call(object), item.super_method.nil?] }

target = Class.new { def answer; :base; end }
refinery = Module.new do
  refine target do
    def answer; :refined; end
  end
end
scope = Module.new do
  using refinery
  def self.read(object); object.method(:answer).unbind; end
end
object = target.new
held = scope.read(object)
copies = [held, held.dup, held.clone]
held = target = refinery = scope = nil
8.times { GC.start }
p copies.map { |item| [item.bind_call(object), item.owner.class] }
