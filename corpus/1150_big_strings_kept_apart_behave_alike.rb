# Strings of 256 KB and more are kept apart from the others; what a program
# does with them is the same
K = 300_000
def sum(s) = [s.bytesize, s[0, 3], s[-3, 3], s.count("z"), s.encoding.to_s]
a = "a" * K
p sum(a)
a << "zz"; p sum(a)
a[1, 2] = "XYZ"; p sum(a)
a.replace("short"); p sum(a)
a << ("b" * K); p sum(a)
a.slice!(0, K); p sum(a)
b = a.dup; b << "!"; p [sum(a), sum(b)]
c = "c" * K; c.freeze; p [sum(c), c.frozen?]
d = ("é" * (K / 2)); p sum(d); d.force_encoding("BINARY"); p sum(d)
e = "e" * K; e.sub!("e", "E"); e.gsub!("ee", "f"); p sum(e)
kept = (1..5).map { |i| (i.to_s * K) }
50.times { "x" * K; ("y" * K).upcase }
GC.start
p kept.map { |s| sum(s) }
f = +""; 40.times { |i| f << (i.to_s * 10_000) }; GC.start; p sum(f)
g = "g" * K; h = g; g << "!"; p [sum(h), h.equal?(g)]
i9 = "i" * K; j9 = i9 + "j" * K; GC.start; p [sum(i9), sum(j9)]
k9 = "k" * K; k9.clear; p sum(k9); k9 << "k" * K; GC.start; p sum(k9)
l9 = ["l" * K, "m" * K].join("-"); p sum(l9)
p ObjectSpace.each_object(String).count { |s| s.bytesize >= K } >= 7
