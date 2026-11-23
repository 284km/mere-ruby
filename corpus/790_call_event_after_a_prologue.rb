# A method's :call fires where ruby fires it: after the prologue that
# destructures a `(a, b)` parameter. A TracePoint enabled while that prologue
# runs -- by the #to_ary it calls -- sees the call, once, with the method's
# own id, callee and line; one enabled before the call sees one :call, not
# two; and a loop that comes back to the first instruction after the
# prologue does not fire it again.

$events = []
$tp = TracePoint.new(:call, :return) do |tp|
  if tp.method_id.to_s.start_with?("pro_")
    $events << [tp.event, tp.method_id, tp.callee_id, tp.lineno]
  end
end

class Arming
  def to_ary
    $tp.enable
    [1, 2]
  end
end

def pro_pair((a, b))
  a + b
end
p [:armed_in_prologue, pro_pair(Arming.new)]
$tp.disable
p $events

$events.clear
$tp.enable
p [:armed_before, pro_pair([3, 4])]
$tp.disable
p $events

def pro_loop((a, b), n)
  i = 0
  while i < n
    i += 1
  end
  [a, b, i]
end
alias pro_loop_alias pro_loop
$events.clear
p [:loop, pro_loop_alias(Arming.new, 3)]
$tp.disable
p $events

# a method with no prologue is called the ordinary way
def pro_plain(x) = x * 2
$events.clear
$tp.enable
p [:plain, pro_plain(5)]
$tp.disable
p $events

# An alias's events name the method it was defined as, and the lines it was
# written on -- in a class, and at the top level, where __method__ and
# original_name do too.
class ProAliasHost
  def pro_inner(a)
    a
  end
  alias pro_outer pro_inner
end
$events.clear
$tp.enable
ProAliasHost.new.pro_outer(1)
$tp.disable
p $events

def pro_top = [__method__, __callee__]
alias pro_top_alias pro_top
p [pro_top_alias, method(:pro_top_alias).original_name]

# With the TracePoint on from the start, the call still comes after the
# prologue: after a default's own call, after the #to_ary that destructures.
$late = []
late_tp = TracePoint.new(:call, :return) { |t| $late << [t.event, t.method_id] if %i[pro_m1 pro_m2 pro_dflt to_ary].include?(t.method_id) }
def pro_dflt = 1
def pro_m1(a, b = pro_dflt, *r, k: pro_dflt, **kw) = a
class ProPair; def to_ary = [1, 2]; end
def pro_m2((a, b), c) = a
late_tp.enable
pro_m1(0)
pro_m2(ProPair.new, 3)
late_tp.disable
p $late

# A block's :b_call comes after its parameters are bound, too: after a
# default's own call (a lambda's, a keyword's), after the #to_ary of a
# destructured `|(a, b)|`, on the line of the block's `{` / `do`. A
# define_method body is a block: its method's :call and its :b_call come
# after the default -- at the top level as in a class.
$bev = []
btp = TracePoint.new(:call, :return, :b_call, :b_return) do |t|
  if t.method_id.to_s.start_with?("bd_") || (t.method_id.nil? && %i[b_call b_return].include?(t.event))
    $bev << [t.event, t.method_id, t.lineno]
  end
end
def bd_dflt = 1
define_method(:bd_top) { |a, b = bd_dflt| a + b }
class BdHost
  define_method(:bd_in) { |a, b = 2| a + b }
end
class BdPair; def to_ary = [1, 2]; end
# (the body ends on the `end` line: the evaluator's :b_return is on the
#  last line it ran, not on the `end` -- loop/2026-11-23-stage10-r50.md (96))
lam = lambda do |x,
                 y = bd_dflt|
  x + y; end
kw = proc { |k: bd_dflt| k }
btp.enable
bd_top(1)
BdHost.new.bd_in(1)
lam.(1)
kw.call
[BdPair.new].each { |(a, b)| a }
btp.disable
$bev.each { |e| p e }

# ...once a call, on both executions: a `for` loop's body (which writes its
# variable first), a block that writes a local outside it, a lambda with a
# default doing the same. A binding that raises -- a missing keyword --
# fires neither :b_call nor :b_return.
$once = []
once_tp = TracePoint.new(:b_call, :b_return) { |t| $once << [t.event, t.lineno] }
n = 0
once_tp.enable
for i in [1, 2] do i end
[1].each { |x, y = bd_dflt| n += 1 }
lambda { |a = bd_dflt| n += a }.call
begin; lambda { |a, k:| }.call(1); rescue ArgumentError; end
once_tp.disable
p $once, n

# ...but a default that raises has its frame pushed: its :b_return comes,
# with no :b_call -- a positional default, a lambda's, a keyword's
def bd_boom = raise("boom")
$raised = []
raised_tp = TracePoint.new(:b_call, :b_return) { |t| $raised << [t.event, t.lineno] }
raised_tp.enable
begin; proc { |a = bd_boom| }.call; rescue; end
begin; lambda { |a = bd_boom| }.call; rescue; end
begin; proc { |k: bd_boom| }.call; rescue; end
begin; lambda { |a| }.call; rescue ArgumentError; end
begin; [1].each { |a, b = bd_boom| }; rescue; end
raised_tp.disable
p $raised
