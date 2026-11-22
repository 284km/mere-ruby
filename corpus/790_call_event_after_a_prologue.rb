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
