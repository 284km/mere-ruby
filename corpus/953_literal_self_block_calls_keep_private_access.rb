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
Forwarder953.class_eval(<<~'RUBY')
  def refined
    self.target(:argument, key: 3) { :refined_block }
  end
RUBY
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

class CatchForwarder953
  def call(&block)
    self.capture(&block)
  end

  def nonlocal_return
    catch(:done, &proc { return :returned })
    :unreached
  end

  private

  def capture(&block)
    catch(:done, &block)
  end
end

catcher = CatchForwarder953.new
p [:catch_value, catcher.call { :executed } == :executed]
p [:catch_throw, catcher.call { |tag| throw tag, :caught } == :caught]
p [:catch_return, catcher.nonlocal_return]
p [:catch_implicit_tag, catch(&proc { |tag| tag.is_a?(Object) })]
p [:catch_explicit_receiver, Kernel.catch(:done, &proc { |tag| tag })]

class CatchConvertible953
  attr_reader :calls
  def initialize
    @calls = 0
  end
  def to_proc
    @calls += 1
    proc { :converted }
  end
end
converted = CatchConvertible953.new
p [:catch_conversion, catch(:done, &converted) == :converted, converted.calls]
[proc { catch(:done, &nil) }, proc { catch(:done, &lambda { :strict }) }].each do |invocation|
  begin
    invocation.call
  rescue LocalJumpError, ArgumentError => error
    p [:catch_error, error.class.name]
  end
end
