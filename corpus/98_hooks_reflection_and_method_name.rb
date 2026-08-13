# `method_added` fires when a method is defined, `Regexp.last_match` reads the
# last match, `__method__` names the running method, and a real `binding`
# method is not shadowed by Kernel's.

# with no match yet, there is nothing to report
p Regexp.last_match

class Registry
  class << self
    attr_reader :registry
    def method_added(method)
      @registry ||= {}
      @registry[Regexp.last_match(1).to_sym] = method if method =~ /^visit_(.*)/
      super
    end
  end
  def visit_send; :send; end
  def visit_other_type; :other; end
  def plain; :plain; end
  define_method(:visit_dyn) { :dyn }
end
p Registry.registry
p Registry.new.visit_dyn

module Mod
  def self.method_added(m); (@seen ||= []) << m; end
  def self.seen; @seen; end
  def one; end
  def two; end
end
p Mod.seen

# a class with no hook still defines methods normally
class NoHook
  def a; 1; end
end
p NoHook.new.a

# Regexp.last_match, with and without an index
"hello world" =~ /(\w+)\s(\w+)/
p Regexp.last_match(1)
p Regexp.last_match(2)
p Regexp.last_match[0]
p(:visit_send =~ /^visit_(.*)/)
p Regexp.last_match(1)

# __method__
def top_level_name; __method__; end
p top_level_name
class Named
  def inst; __method__; end
  def self.klass; __method__; end
  def with_block; [1].map { __method__ }; end
end
p Named.new.inst
p Named.klass
p Named.new.with_block
p __method__

# a `binding` method of one's own wins over Kernel#binding
class Holder
  attr_reader :binding
  def initialize; @binding = { bound: :yes }; end
  def read; binding[:bound]; end
end
p Holder.new.read
x = 42
b = binding
p b.local_variable_get(:x)
