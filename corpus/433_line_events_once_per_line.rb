# What a TracePoint sees: one :line per line (a nested if/while/begin body on
# its statement's line is no new one; a block's, a def's and a class's body
# start afresh), the line of a class's `end`, a builtin reached through an
# alias (method_id the builtin's, callee_id the alias), a builtin that raises
# still returning, and set_trace_func's view of a singleton method and of
# method_added.

def lines
  ev = []
  tp = TracePoint.new(:line) { |t| ev << t.lineno - __LINE__ }
  tp.enable do
    a = 1; b = 2
    i = 0
    while i < 2
      i += 1; d = 4
    end
    i = 0; while i < 2; i += 1; end
    pr = proc { e = 5; f = 6 }
    pr.call; pr.call
    if a == 1 then g = 7; h = 8 end
    if a == 2
    else k = 9
    end
    begin; l = 1; end
    q = (r = 1; s = 2)
    u = [1].map { |v| v + 1 }
  end
  ev
end
p lines

class Klass
  def m
  end
end
ev = []
TracePoint.new(:class, :end) { |t| ev << [t.event, t.lineno - __LINE__] }.enable do
  class Klass
    X = 1
  end
end
p ev

class AliasedCMethod < Hash
  alias original_size size
  def size; original_size; end
end
ev = []
o = AliasedCMethod.new
TracePoint.new(:call, :return, :c_call, :c_return) { |tp| ev << [tp.event, tp.method_id, tp.callee_id] }.enable { o.size }
p ev

ev = []
o = Class.new { alias alias_raise raise; def m; alias_raise; end }.new
TracePoint.new(:c_return) { |tp| ev << [tp.event, tp.method_id, tp.callee_id] }.enable { o.m rescue nil }
p ev[0]

# set_trace_func names a singleton method's class by its object, and
# method_added made from Module's own Method is a builtin's
class Base
  def self.hi = 1
end
class Kid < Base
  class << self
    define_method(:method_added, Module.method(:method_added))
  end
end
ev = []
set_trace_func(proc { |e, f, l, id, b, k| ev << [e, id, k] if [:hi, :method_added].include?(id) })
Base.hi
class Kid
  def kid_m; end
end
set_trace_func(nil)
ev.each { |e| p e }

# an alias of a String builtin in a subclass, with and without a block
s = Class.new(String) { include Enumerable; alias each each_char }.new("foo")
p s.each.to_a
p s.find { |c| c == "o" }
p s.map(&:upcase)

# a raise is Kernel#raise and what it asks (exception, initialize, backtrace),
# then the :raise; a rescue asks Module#=== on its own line
ev = []
TracePoint.new(:c_call, :c_return, :raise, :rescue) { |tp| ev << [tp.event, tp.lineno - __LINE__, tp.method_id, tp.defined_class] }.enable do
  begin
    raise TypeError, "error"
  rescue TypeError
  end
  begin
    raise "plain"
  rescue
  end
end
ev.each { |e| p e }
