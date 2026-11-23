# A dropped Fiber that stopped inside an op-assign is given back. Each turn
# makes an Enumerator, runs it to a yield and drops it; the yield is in the
# op-assign's value (`o.y += y.yield(1)`), in its reader, its writer, its
# `[]` or its `[]=`. A scope alive where the fiber stopped must not root the
# stopped block (fb_reclaim, lv_fbscope): unittest/fiber_scope_reclaim_check.py.
class O
  def initialize = (@y = 0)
  def y = (($mode == "getter") ? $yy.yield(1) : 0) || 0
  def y=(v)
    ($mode == "setter") ? $yy.yield(1) : (@y = v)
  end
  def [](k) = (($mode == "aref") ? $yy.yield(1) : 0) || 0
  def []=(k, v)
    ($mode == "aset") ? $yy.yield(1) : v
  end
end
n = Integer(ARGV[0]); $mode = ARGV[1]
n.times do
  e = Enumerator.new do |y|
    $yy = y
    o = O.new
    case $mode
    when "value" then o.y += y.yield(1)
    when "getter", "setter" then o.y += 1
    else o[:a] += 1
    end
  end
  e.next
end
puts "fiber scope reclaim: #{$mode} done"
