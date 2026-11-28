# A loop that makes a big String each turn is collected in the middle of the
# loop, not only at its end. The VM reaches fewer safepoints than the
# evaluator, and each asked for the pressure one time in 32: `while` on one
# line and a String made in a method met none that asked, and every String
# the loop made stayed until it ended (22 turns: 132 MB where the evaluator
# kept 24). A safepoint now asks as soon as 16 MB of String bytes are new.
c = GC.count
22.times { ("a".b * 6_000_000).bytesize }
p GC.count > c
c = GC.count
i = 0
while i < 22
  ("a".b * 6_000_000).bytesize
  i += 1
end
p GC.count > c
c = GC.count
22.times { s = "a" * 6_000_000; s.bytesize }
p GC.count > c
c = GC.count
def big = "b" * 6_000_000
22.times { big.size }
p GC.count > c
c = GC.count
i = 0; while i < 22; ("a".b * 6_000_000).bytesize; i += 1; end
p GC.count > c
