# The rest of Range, and the two things found on the way.
#
# A block given to a method leaks into the calls made inside the proc it is
# stored in: `def w(&b); b.call; end; w { (0...2**64).min(2) }` answered []
# where the same expression at the top level answered [0, 1], because inside
# the proc body every plain call received the frame's block and a builtin that
# asks "was a block given?" saw one that was never passed. Every ruby/spec
# example runs in exactly that shape. A call with no block literal and no `&`
# passes NO block, whatever the frame holds.
#
# `def t.succ` gives an object a SINGLETON class, and a class is then known by
# two names: the bookkeeping one and the one it stands for. Every comparison
# against the literal "Time" -- the operator table, the arithmetic arm, the
# equality list -- stopped matching, so `t + 1` was "Integer can't be coerced
# into Object" and `t == Time.utc(1970)` was false.

def t(label)
  puts "%-46s %s" % [label, (yield).inspect]
rescue Exception => e
  puts "%-46s <%s: %s>" % [label, e.class, e.message]
end

# --- a block does not leak into the calls inside a proc ---
def w(&b); b.call; end
def y; yield; end
def foo; block_given?; end
t('min(2) at the top level')          { (0...2**64).min(2) }
t('min(2) inside &b.call')            { w { (0...2**64).min(2) } }
t('min(2) inside yield')              { y { (0...2**64).min(2) } }
t('endless min(2) inside &b.call')    { w { (1..).min(2) } }
t('max(2) with a comparator, inside') { w { (1..10).max(2) { |a, b| b <=> a } } }
t('block_given? inside &b.call')      { w { foo } }
t('sort inside &b.call')              { w { [3, 1, 2].sort } }
t('first(2) inside &b.call')          { w { [1, 2, 3].first(2) } }

# --- reverse_each walks from the END, and answers the range ---
t('reverse_each returns self')        { (1..3).reverse_each { |x| x }.class }
t('reverse_each values')              { a = []; (1..3).reverse_each { |x| a << x }; a }
t('exclusive reverse_each')           { a = []; (1...3).reverse_each { |x| a << x }; a }
t('String reverse_each')              { a = []; ('a'..'c').reverse_each { |x| a << x }; a }
t('beginless reverse_each.take(3)')   { (..5).reverse_each.take(3) }
t('exclusive beginless take(3)')      { (...5).reverse_each.take(3) }
t('endless reverse_each')             { (1..).reverse_each.take(3) }
t('endless String reverse_each')      { ('a'..).reverse_each.take(3) }
t('reverse_each.size Integer')        { (1..5).reverse_each.size }
t('reverse_each.size String')         { ('a'..'z').reverse_each.size }
t('reverse_each.size beginless')      { (..5).reverse_each.size }
t('reverse_each.size Float begin')    { (1.1..3).reverse_each.size }
t('reverse_each break')               { (1..3).reverse_each { |x| break x if x == 2 } }

# --- what an Enumerator over a range knows without walking ---
t('each.size Integer')                { (1..3).each.size }
t('each.size String')                 { ('a'..'c').each.size }
t('each.size endless')                { (1..).each.size }
t('each.size beginless')              { (..3).each.size }

# --- an endless String range walks until the block breaks ---
t('endless String each')              { a = []; ('A'..).each { |x| break if x > 'D'; a << x }; a }
t('endless String step(2)')           { a = []; ('a'..).step(2) { |x| break if x > 'e'; a << x }; a }
t('endless String step.take')         { ('a'..).step(2).take(3) }

# --- step: Floats, Strings, zero, beginless, and a stray object ---
t('Float range step to_a')            { (1.0..2.0).step(0.5).to_a }
t('Float range step class')           { (1.0..2.0).step(0.5).class }
t('Float range step size')            { (1.0..2.0).step(0.5).size }
t('exclusive Float step')             { (1.0...2.0).step(0.5).to_a }
t('Integer begin, Float end')         { (1..2.0).step(0.5).to_a }
t('Float step on Integers')           { (-2..2).step(1.5).to_a }
t('Float step with a block')          { a = []; (1.0..2.0).step(0.5) { |x| a << x }; a }
t('near the upper limit (16612)')     { (1.0...55.6).step(18.2).to_a }
t('near the upper limit: size')       { (1.0...55.6).step(18.2).size }
t('step(0)')                          { (1..5).step(0) }
t('step(0) with a block')             { (1..5).step(0) { } }
t('step(0.0)')                        { (1.0..2.0).step(0.0) }
t('String step')                      { a = []; ('A'..'E').step { |x| a << x }; a }
t('String step(2)')                   { a = []; ('A'..'G').step(2) { |x| a << x }; a }
t('exclusive String step(2)')         { a = []; ('A'...'G').step(2) { |x| a << x }; a }
t('String step Float')                { ('A'..'G').step(2.0) { } }
t('String step class')                { ('A'..'E').step.class }
t('String step(2).to_a')              { ('A'..'E').step(2).to_a }
t('beginless numeric step class')     { (..10).step.class }
t('beginless numeric step size')      { (..10).step.size }
t('beginless step with a block')      { (..10).step(2) { } }
t('beginless String step')            { (..'z').step(2) }
t('beginless String step, no arg')    { (..'z').step }
t('stray object step class')          { (1..2).step(Object.new).class }
t('stray object step walked')         { (1..2).step(Object.new).to_a }

# --- bsearch reaches the infinities and the boundaries ---
inf = Float::INFINITY
t('bsearch to -Infinity')             { (-inf..0.0).bsearch { |x| true } }
t('bsearch to Infinity')              { (0..inf).bsearch { |x| x == inf } }
t('bsearch excluded Infinity')        { (0...inf).bsearch { |x| x == inf } }
t('bsearch over everything')          { (-inf..inf).bsearch { |x| x >= 3 } }
t('bsearch find-any at the end')      { (1.0..3.0).bsearch { |x| 3.0 - x } }
t('bsearch find-any at the begin')    { (1.0..3.0).bsearch { |x| 1.0 - x } }
t('bsearch find-any exclusive')       { (1.0...3.0).bsearch { |x| 3.0.prev_float - x } }
t('bsearch smallest positive')        { (0.0..1.0).bsearch { |x| x >= Float::MIN } }
t('bsearch 0.0 answer')               { (0.0..4.0).bsearch { |x| x < 2 ? 1.0 : x > 2 ? -1.0 : 0.0 } }

# --- Range#initialize by name ---
t('allocate + initialize')            { Range.allocate.send(:initialize, 0, 1) }
t('initialize arity 0')               { Range.allocate.send(:initialize) }
t('initialize arity 4')               { Range.allocate.send(:initialize, 1, 3, 5, 7) }
t('initialize a built range')         { (0..1).send(:initialize, 1, 3) }
t('initialize incomparable')          { Range.allocate.send(:initialize, Object.new, Object.new) }

# --- an exclusive infinite end has no maximum to name ---
t('(0...inf).max')                    { (0...inf).max }
t('(0...inf).minmax')                 { (0...inf).minmax }
t('(0..inf).max')                     { (0..inf).max }

# --- a Time keeps being a Time behind a singleton class ---
t0 = Time.utc(1970)
def t0.succ; self + 1 end
t1 = t0.succ
def t1.succ; self + 1 end
t('singleton Time + 1 is a Time')     { (t0 + 1).class }
t('singleton Time == a fresh Time')   { t0 == Time.utc(1970) }
t('singleton Time <=>')               { t0 <=> t1 }
t('Times in an Array compare')        { [t0, t1] == [Time.utc(1970), Time.utc(1970, nil, nil, nil, nil, 1)] }
t('Array#include? a Time')            { [Time.utc(1970)].include?(Time.utc(1970)) }
t('range of Times with #succ walks')  { (t0..t1).to_a.size }
t('...and stops AT the end')          { (t0..t1).to_a.last.equal?(t1) }
