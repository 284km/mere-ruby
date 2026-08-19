# A handful of Kernel methods are answered before the method table is consulted,
# each guarded by "unless something defines this name" -- and the guard asked for
# a BARE name, which is where a top-level `def puts` lands. `module Kernel; def
# puts; end` registers "Kernel#puts", the guard did not see it, and the builtin
# still won, though ruby honours both. `puts` was worse than outranked: it is a
# STATEMENT in this parser, so a user-defined one was never consulted at all.
#
# (Aliasing one of these builtins and calling the alias bare is a separate gap,
# recorded in KNOWN_GAPS.md: an alias whose source has no entry in the table is
# noted as a builtin delegation, which the implicit-self path does not read.)
module Kernel
  def puts(*args)
    $lines = ($lines || 0) + [args.size, 1].max
    STDOUT.write(args.empty? ? "\n" : args.map { |a| "#{a}\n" }.join)
    nil
  end
  def warn(*args)
    STDOUT.write("warned: " + args.join(",") + "\n")
    nil
  end
  def format(*args)
    "formatted(#{args.length})"
  end
end
puts "one"
puts "two", "three"
puts
warn "careful"
p [$lines, format("%d", 5)]
class Speaker
  def talk; puts "from a class"; end
end
Speaker.new.talk
p $lines
