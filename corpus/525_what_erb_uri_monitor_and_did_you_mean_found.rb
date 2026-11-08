# frozen_string_literal: true
# What test/erb, uri, monitor, did_you_mean and etc found.

def show(label)
  v = yield
  puts "#{label}: #{v.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}: #{e.message}"
end

# a frozen "" literal is not nil.to_s: nil interpolated into a string left
# every frozen "" US-ASCII (URI::Generic#to_s after IPAddr's message)
def empty_literal_enc; "".encoding; end
show("before") { empty_literal_enc }
s = "invalid address: #{@nothing}"
show("after nil interpolated") { empty_literal_enc }
show("true literal") { x = "t: #{true}"; "true".encoding }
show("nil.to_s") { [nil.to_s.encoding, nil.to_s.frozen?, nil.to_s.equal?(nil.to_s)] }
show("nil.inspect") { [nil.inspect.encoding, nil.inspect.frozen?] }
show("true.inspect") { [true.inspect.encoding, true.inspect.frozen?, true.inspect.equal?(true.to_s)] }

# Marshal does not ask the dumped object's own equal?
class AlwaysEqual
  def equal?(_other) = true
end
holder = Object.new
holder.instance_variable_set(:@a, "s")
holder.instance_variable_set(:@b, AlwaysEqual.new)
show("marshal") { Marshal.load(Marshal.dump(holder)).instance_variables }
show("marshal array") { Marshal.load(Marshal.dump([AlwaysEqual.new, "x", 1])).map(&:class) }

# `def CONST.m` in a class body, the constant holding an Array or a String
LIST = [1, 2]
WORD = +"w"
class Opener
  def LIST.second = self[1]
  def WORD.twice = self * 2
end
show("def LIST.m") { LIST.second }
show("def WORD.m") { WORD.twice }

# a module named through const_missing, included; defined? through an alias
module Outer
  module Real
    module Inner
      X = 1
    end
  end
  def self.const_missing(c) = c == :Alias ? Real : super
end
class Includer
  include Outer::Alias::Inner
end
show("include via const_missing") { Includer::X }
show("ancestor") { Includer.ancestors[1] }
Outer.const_set(:Pointer, Outer::Real::Inner)
show("defined? through const_set") { [defined?(Outer::Pointer), defined?(Outer::Pointer::X), defined?(Outer::Pointer::Y)] }

# a method named lambda on self is called, not Kernel#lambda
class Typo
  attr_accessor :lambda
  def initialize = @lambda = 4
  def half = (lambda / 2)
end
show("self.lambda") { Typo.new.half }

# private_methods carries Kernel's; Struct's NameError has a receiver
show("private raise") { Object.new.private_methods.include?(:raise) }
show("private user") { c = Class.new { def puts = nil }; c.new.private_methods.include?(:puts) }
show("struct member") do
  st = Struct.new(:does_exist).new
  begin
    st[:doesnt_exist]
  rescue NameError => e
    [e.message, e.name, e.receiver.equal?(st)]
  end
end

# a monitor belongs to a fiber; a timed wait that runs out is false
require "monitor"
m = Monitor.new
m.enter
show("try_enter other fiber") { Fiber.new { m.try_enter }.resume }
m.exit
show("timed wait") { m.synchronize { m.new_cond.wait(0.01) } }
class KwParent
  def initialize(x:) = @x = x
end
class KwChild < KwParent
  include MonitorMixin
  def initialize = super(x: 1)
end
show("monitor kwargs") { KwChild.new.instance_variable_get(:@x) }
