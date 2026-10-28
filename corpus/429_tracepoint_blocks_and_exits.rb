# TracePoint around blocks and around methods left by an exception or a
# break: :b_call / :b_return, the :return of a method a raise leaves, the
# ids a :raise reports, and an exception the hook itself raises.

def events(*kinds)
  ary = []
  tp = TracePoint.new(*kinds) do |t|
    next unless t.path == __FILE__
    rv = (t.event == :return || t.event == :b_return) ? t.return_value : :-
    ary << [t.event, t.method_id, rv]
  end
  tp.enable { yield }
  ary
end

def iter = yield
def raiser = raise("boom")
def rescuer
  raise
rescue
  return :rescued
end
def breaker
  iter { break :broke }
  :after
end
o = Class.new {
  def m = raise("x")
  alias alias_m m
}.new

p events(:b_call, :b_return) { 3.times { next } }
p events(:b_return) { [1, 2].map { |x| x * 2 } }
p events(:call, :return) { raiser rescue nil }
p events(:return) { rescuer }
p events(:return, :b_return) { breaker }
p events(:b_return) { lambda { return 1 }.call; lambda { raise }.call rescue nil }

ids = []
TracePoint.new(:raise, :call, :return) { |t| ids << [t.event, t.method_id, t.callee_id] if t.path == __FILE__ }.enable { o.alias_m rescue nil }
p ids

# the hook's own exception leaves through the event's place
seen = []
tp = TracePoint.new(:b_call, :b_return) { |t| seen << t.event; raise "from hook" if t.event == :b_call }
begin
  tp.enable { 1.times { :never } }
rescue => e
  p [e.message, seen]
end

# ...and String#getbyte takes one argument
p String.instance_method(:getbyte).parameters
