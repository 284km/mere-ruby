# Kernel#loop runs its block from a frame of its own, as ruby's backtrace
# shows: `in 'Kernel#loop'`, at the line of the call, between the block and
# the method around it. Each way out of the loop is unchanged.
def labels1063
  loop do
    return caller_locations(0, 3).map { |l| [l.label, l.lineno] }
  end
end
p labels1063

def raised1063
  loop { raise ArgumentError, "x" }
rescue ArgumentError => e
  e.backtrace_locations.first(3).map(&:label)
end
p raised1063

def nested1063
  loop do
    [1].each do
      loop { return caller(0, 5).map { |s| s[/'(.*)'/, 1] } }
    end
  end
end
p nested1063

# break, next, StopIteration (and its result), return, throw
p(loop { break 5 })
i = 0
p(loop { i += 1; next if i < 3; break i })
e = [1, 2].each
p(loop { e.next })
def ret1063 = loop { return :ret }
p ret1063
p(catch(:t) { loop { throw :t, :thrown } })
# an error from a method the block calls still names the loop in between
def deep1063 = raise("deep")
begin
  loop { deep1063 }
rescue => err
  p err.backtrace_locations.first(3).map(&:label)
end
# a loop with no block is an Enumerator, and has no frame of its own
p loop.class
# the frame is gone once the loop is: the caller sees its own frame again
def after1063
  loop { break }
  caller_locations(0, 1).first.label
end
p after1063
