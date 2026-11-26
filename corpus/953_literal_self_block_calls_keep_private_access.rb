class Forwarder953
  private def target(*args, **keywords, &block)
    [args, keywords, block ? block.call(:result) : :none]
  end

  def forwarded(...) = self.target(:forwarded, ...)
  def explicit(*args, **keywords, &block)
    self.target(:explicit, *args, **keywords, &block)
  end
  def absent = self.target(:absent, &nil)
  def literal
    self.target(:literal) { :literal_block }
  end
  def symbol = self.target(:symbol, &:to_s)
  def bare(...) = target(:bare, ...)
  def other(receiver, ...) = receiver.target(...)
  def same(...)
    receiver = self
    receiver.target(...)
  end
  class_eval("def generated(...) = self.target(:generated, ...)")
end

class << Forwarder953
  private def target(&block) = block ? block.call : :none
  def forwarded(...) = self.target(...)
end
p [:class, Forwarder953.forwarded { :class_block }]

module RefineForwarder953
  refine Forwarder953 do
    def target(*args, **keywords, &block)
      [:refined, args, keywords, block ? block.call : :none]
    end
  end
end
using RefineForwarder953
class Forwarder953
  def refined
    self.target(:argument, key: 3) { :refined_block }
  end
end
p [:refinement, Forwarder953.new.refined]

forwarder = Forwarder953.new
[:forwarded, :explicit, :bare, :generated].each do |method|
  p [method, forwarder.public_send(method, 1, key: 2)]
  p [method, forwarder.public_send(method, 1, key: 2) { :block }]
end
p forwarder.absent
p forwarder.literal
p forwarder.symbol
[:other, :same].each do |method|
  begin
    method == :other ? forwarder.other(forwarder, 1) : forwarder.same(1)
  rescue NoMethodError => error
    p [method, error.class, error.name]
  end
end
