a = Array.new(2000) { |i| (i * 7919) % 2003 }; f = a.map { _1 * 0.5 }
s = 0; 200.times { s += a.max + a.min + f.max; s += a.sort[3]; s += [a[1], a[2], a[3]].max }; p s
