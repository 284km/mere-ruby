# TracePoint and set_trace_func report the events ruby's do (note 435):
# a builtin call is a :c_call / :c_return, a method's :call and :return name
# the lines it was defined and ended on, a class body is :class, an
# attribute is a C method, and set_trace_func is a TracePoint over every
# event, its first one being its own c-return.

def foo
  1 + 1
end
def bar = 2

class Pt
  attr_accessor :x
  alias y x
  def m(a, b = 1)
    a
  end
end

ev = []
tp = TracePoint.new(:line, :call, :return, :c_call, :c_return, :class, :end) do |t|
  ev << [t.event, t.lineno, t.method_id, t.defined_class]
end
tp.enable
foo
bar
class Qq; end
pt = Pt.new
pt.x = 3
pt.y
pt.m(1)
tp.disable
# (the hooks a class body calls -- const_added, inherited -- are not reported,
#  nor is the allocation inside new)
skip = [:disable, :new, :initialize, :const_added, :inherited, :method_added]
ev.each { |e| p e unless skip.include?(e[2]) }

# callee_id is the name it was called by
ids = []
TracePoint.new(:c_call, :call) { |t| ids << [t.method_id, t.callee_id] }.enable { pt.y; pt.x }
p ids

# the parameters of the method being called
ps = []
TracePoint.new(:call) { |t| ps << t.parameters }.enable { pt.m(2) }
p ps

# attributes read outside the handler raise
kept = nil
t2 = TracePoint.new(:c_call) { |t| kept = t }
t2.enable { 1 + 2 }
[:event, :lineno, :path, :method_id, :defined_class, :return_value].each do |a|
  begin
    kept.public_send(a)
    p [a, :no_error]
  rescue RuntimeError => e
    p [a, e.message]
  end
end

# set_trace_func, filtered to this file's events
events = []
name = "settrace"
eval <<-EOS, nil, name
set_trace_func(Proc.new { |event, file, lineno, mid, binding, klass|
  events << [event, lineno, mid, klass] if file == name
})
x = 1 + 1
set_trace_func(nil)
EOS
events.each { |e| p e }
