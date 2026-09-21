# Three containers can point at themselves, and the printer knew about two.
# An object holding itself recursed until the stack died -- a SIGSEGV, not an
# exception, so nothing could rescue it and the whole file went with it.
#
# Marshal has the same shape of problem and ruby's answer is the OBJECT TABLE:
# every non-immediate, non-Symbol value gets an index the first time it is
# written, and a later mention is "@" plus that index. That is what makes a
# cycle terminate, and it is also why `[s, s]` writes the string ONCE.
# Symbols are not in it (they have their own table); Floats are.

a = []; a << a
p a
h = {}; h[:x] = h
p h

class Selfref
  def initialize = @me = self
end
s = Selfref.new.inspect
p s.start_with?("#<Selfref:0x")
p s.include?("@me=#<Selfref:0x")
p s.end_with?(" ...>>")

str = "ab"
p Marshal.dump([str, str])
p Marshal.dump([str, "ab"])
p Marshal.dump(a)
p Marshal.dump(h)
p Marshal.dump([1, 1])
p Marshal.dump([:a, :a])
p Marshal.dump([1.5, 1.5])
p Marshal.dump([nil, nil])
ar = [1]
p Marshal.dump([ar, ar])
p Marshal.dump([[str], [str]])
p Marshal.load(Marshal.dump([str, str])).then { |x| [x, x[0].equal?(x[1])] }

# ...and a thread that kills itself has no value, which is what left one
# holding ITSELF and turned `p t.value` into the same overflow.
t = Thread.new { Thread.current.exit }
p t.value
p Thread.new { 3 }.value

# ...and COMPARING two cycles is a third walk that needed the same guard. A
# pair already on the comparison stack is taken as equal, which is what makes
# the walk terminate -- and [1,[...]] == [2,[...]] is still false, because the
# 1 and the 2 differ before the cycle closes.
b = [1]; b << b
c = [2]; c << c
p [a == a, a.equal?(a)]
# ...their hashes MAY collide (the contract only binds equal values), so
# only the equal pair below asserts on #hash.
p [b == c, b.eql?(c)]
d = [1]; d << d
p [b == d, b.eql?(d), b.hash == d.hash]
i = {}; i[:x] = i
p h == i
p Marshal.load(Marshal.dump(b)) == b
