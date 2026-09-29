# sprintf's %a (hex float, rounded half-to-even into the exponent), a name
# written after the flags, Hash#default for a missing name, and a chained
# assignment whose first target is a global (it used to bind a local).
p ["%a" % 1.0, "%a" % -0.0, "%a" % 5e-324, "%.0a" % 1.5, "%.2a" % 1.999999, "%#.0a" % 16.25]
p ["%020a" % 196, "%-12A|" % 3.0, "% a" % 196]
p [format("%+15<x>.5f", x: 10.952), format("%-8.3{s}|", s: "abcdef"), format("%{k}", Hash.new(7))]
p [format("%#.0e", 100), format("%#.0f", 123.4), format("%#.0o", 0), format("%#o", -87)]
begin
  format("%<nope>s", { other: 1 })
rescue KeyError => e
  p [e.message, e.key, e.receiver]
end
p [Signal.signame(6), Signal.signame(20)]
$chained = local = 5
p [$chained, local]
