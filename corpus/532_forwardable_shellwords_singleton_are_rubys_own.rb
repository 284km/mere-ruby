# What the top-level test files found: Forwardable, Shellwords and Singleton
# are ruby's own files; a builtin's Method put back with
# define_singleton_method is the builtin again; singleton.rb's undef of
# extend_object; a Hash literal with keys of their own #hash; a class's alias
# of a builtin ahead of an included module's method.
require "forwardable"
require "shellwords"
require "singleton"
require "securerandom"
require "rbconfig"

def show(label)
  v = yield
  puts "#{label}: #{v.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}: #{e.message}"
end

class Queue2
  extend Forwardable
  def_delegators :@items, :size, :first
  def_delegator :@items, :push, :enq
  def_delegator :@items, :fetch, :at_kw
  def initialize = @items = []
end
q = Queue2.new
q.enq(1); q.enq(2)
show("forwardable") { [q.size, q.first, Queue2.instance_method(:enq).owner == Queue2] }
o = Object.new
o.instance_variable_set(:@list, [3, 4, 5])
o.extend SingleForwardable
o.def_delegator :@list, :last
show("single forwardable") { o.last }

show("shellsplit") { Shellwords.shellsplit(%q{a "b c" d\ e}) }
show("unmatched") { Shellwords.shellsplit(%q{a "b}) }
show("escape") { "it's here".shellescape }

class Config2
  include Singleton
  attr_accessor :v
end
Config2.instance.v = 3
show("instance") { [Config2.instance.equal?(Config2.instance), Config2.instance.v] }
show("new") { Config2.new }
show("extend") { Object.new.extend(Singleton) }
show("include in a module") { begin; Module.new { include Singleton }; rescue TypeError => e; e.message.sub(/0x\h+/, "X"); end }

show("gen_random") { SecureRandom.gen_random(8).bytesize }

original = Fiber.method(:current_scheduler)
mock = Object.new
Fiber.define_singleton_method(:current_scheduler) { mock }
show("mocked") { Fiber.current_scheduler.equal?(mock) }
Fiber.define_singleton_method(:current_scheduler, original)
show("put back") { [Fiber.current_scheduler, Thread.new { Fiber.current_scheduler }.value] }

Addr = Struct.new(:a) do
  def hash = a.hash
  def eql?(o) = o.is_a?(Addr) && o.a == a
end
show("literal keys") { {Addr.new(1) => :x, Addr.new(1) => :y, Addr.new(2) => :z}.size }

module Walk
  def walk_each = raise(NotImplementedError)
end
class Array
  include Walk
  alias walk_each each
end
show("alias ahead of the module") { r = []; [1, 2].walk_each { |x| r << x }; r }

show("makefile dirs") { RbConfig.expand(RbConfig::MAKEFILE_CONFIG["rubyarchdir"].dup) == RbConfig::CONFIG["rubyarchdir"] }
