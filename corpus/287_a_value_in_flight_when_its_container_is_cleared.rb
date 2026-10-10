# A value read out of a hash or an array is still in flight -- an argument
# not yet passed -- when the container is cleared and refilled. The index a
# big hash keeps went back to a pool at the clear, wound back, and the next
# hash's values were written over the bytes the argument pointed at: foo got
# `true` for :val3 (note 303). Dropped indexes and queues wait for a
# collection now, which runs off the stack.
def foo(a, b, c) = p([a, b, c])

h = {}
20.times { |i| h["k#{i}".to_sym] = "val#{i}".to_sym }
foo(h[:k3], (h.clear; 30.times { |i| h["z#{i}".to_sym] = ("w" * 40 + i.to_s).to_sym }; 1), h[:z1])

g = {}
20.times { |i| g[i] = 12345678901234567890123 + i }
foo(g[3], (g.clear; 30.times { |i| g[i + 100] = 98765432109876543210987 * i }; 2), g[101])

s = {}
10.times { |i| s["k#{i}".to_sym] = "small#{i}".to_sym }
foo(s[:k3], (s.clear; 30.times { |i| s["z#{i}".to_sym] = ("x" * 40 + i.to_s).to_sym }; 3), s[:z1])

a = []
10.times { |i| a << "elt#{i}".to_sym }
foo(a[3], (a.clear; 30.times { |i| a << ("y" * 40 + i.to_s).to_sym }; 4), a[1])

# and through a collection in the middle: the queues dropped before it are
# pooled by it, and the values taken out before it are still the same
b = []
5.times { |i| b << 1000000000000000000000 * (i + 1) }
foo(b[2], (b.clear; GC.start; 2000.times { |i| x = []; x << i << i }; 5), b.size)
hh = {}
25.times { |i| hh[i] = "v#{i}" * 3 }
foo(hh[7], (hh.clear; GC.start; 2000.times { |i| y = {}; y[i] = i.to_s * 9 }; 6), hh.size)
