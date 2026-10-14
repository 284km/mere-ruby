# sprintf and Float as CRuby's test_sprintf and test_float ask them (note
# 340): %d / %x write a huge Float as the integer it is, %f rounds a Float
# the way ruby's dtoa does (the shortest digits, half to even, when the
# precision cuts inside them; the exact binary value past them) and writes an
# Integer or a Rational from its exact value, a named reference after a
# numbered one is refused by name, #round / #floor / #ceil take precisions
# past 14 digits through the exact value, and a Float step ends on its end.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{n}: #{r}"
end
t(1) { [sprintf("%d", (2**64).to_f), sprintf("%d", -(2**63).to_f), sprintf("%d", -(2**63)), sprintf("%d", 1e20), sprintf("%x", 2.0**70), sprintf("%x", -(2**63))] }
t(2) { [5.005, 5.015, 5.025, 0.35, 0.45, 2.675, 0.125, 0.0005, 0.5, 1.5].map { |x| sprintf("%.2f|%.1f|%.0f|%.3f", x, x, x, x) } }
t(3) { [sprintf("%.17f", 0.35), sprintf("%.20f", 0.1), sprintf("%.3f", 1e22), sprintf("%.12f", 123.456)] }
t(4) { [sprintf("%.60f", 1/3r), sprintf("%.5f", -2/3r), sprintf("%f", 100**20), sprintf("%.2f", -(10**25)), sprintf("%.600f", 600**~60).size] }
t(5) { [(sprintf("%1$<k>s", k: 1) rescue $!.message), (sprintf("%s%s%<k>s", "a", "b", k: 1) rescue $!.message), (sprintf("%1${k}s", k: 1) rescue $!.message)] }
t(6) { [(sprintf("%.**d", 5, 10, 1) rescue $!.message), (sprintf("%*999999999999999999999999$d", 1) rescue $!.message)] }
t(7) { s = sprintf("%c".encode(Encoding::US_ASCII), 0x80); [s.encoding, s.valid_encoding?] }
t(8) { [1.1e-300, -1.1e-300, 1.5e-300, Float::MIN, 2.675, 1e300].map { |x| [x.round(300), x.floor(300), x.ceil(300), x.truncate(16), x.round(16), x.ceil(20)] } }
t(9) { [(Float::NAN.div(2) rescue $!.class), (11.5.div(Float::NAN) rescue $!.class)] }
t(10) { [(1.0..12.7).step(1.3).to_a.last, 1.0.step(2.0, 0.1).to_a, (0.0...1.0).step(0.1).to_a.size, 0.0.step(1.0, Float::INFINITY).to_a, (1.0.step(2.0, "0.5") {} rescue $!.message)] }
t(11) { o = Object.new; def o.to_f = raise("x"); [Float(o, exception: false), (1.0.round(half: "up".dup.force_encoding("utf-16be")) rescue $!.class)] }
