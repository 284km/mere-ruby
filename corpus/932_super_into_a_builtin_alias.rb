# `super` that finds no Ruby method above reaches an alias of a builtin
# farther up the chain. actionpack's AbstractController::Base has
# `alias send_action send`, and ActionController::BasicImplicitRender's
# #send_action calls super into it: every controller action went through that.

module Abstract
  class Base
    def process_action(name, *args, &blk) = send_action(name, *args, &blk)
    def hi(x) = "hi #{x}"
    def each_twice = [yield(1), yield(2)]
    alias send_action send
    alias inspect_saved inspect
    alias frozen_saved frozen?
  end
end

module Implicit
  def send_action(m, *args, &blk)
    ret = super
    "implicit(#{ret.inspect})"
  end

  def frozen_saved = [:implicit, super]
end

class Metal < Abstract::Base; end
class Ctl < Metal
  include Implicit
  def inspect_saved = "ctl:" + super.sub(/0x\h+/, "0x")
end

c = Ctl.new
p c.process_action(:hi, 1)
p c.process_action(:each_twice) { |x| x * 10 }
p c.inspect_saved
p c.frozen_saved

# an undef farther up still stops it
class Plain
  alias saved_dup dup
end
class Child < Plain
  def saved_dup = [:child, super.class]
end
p Child.new.saved_dup

class Grandchild < Child
  def missing_one = super
end
begin
  Grandchild.new.missing_one
rescue NoMethodError => e
  puts e.message
end
