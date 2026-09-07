# ---- 1. a signal that does not exist is refused ---------------------------
# `signal_num_of` answers 0 for a name nothing claims and `signal_name_of` ""
# for an unknown number, and both were handed back as an ANSWER -- so this
# built a SignalException whose signo was 0 and whose message was "SIGNOPE".
p [SignalException.new("INT").message, SignalException.new(:INT).signm,
   SignalException.new(:INT).signo, SignalException.new(2).message,
   SignalException.new(2, "name").message]
[-> { SignalException.new("NOPE") }, -> { SignalException.new(1000) },
 -> { SignalException.new(:NOPE) }].each do |f|
  begin
    f.call
  rescue => e
    puts "#{e.class}: #{e.message}"
  end
end

# Interrupt is SIGINT with a message of its own. Inheriting SignalException's
# initialize made the first argument a SIGNAL, so `Interrupt.new("message")`
# reported "SIGmessage" -- a signal name built out of the caller's text.
p [Interrupt.new.signo, Interrupt.new.signm, Interrupt.new.message]
p [Interrupt.new("message").message, Interrupt.new("message").signo]
p Interrupt.ancestors.include?(SignalException)

# ---- 2. a single Integer is an ERRNO, not a message -----------------------
p [SystemCallError.new(2).errno, SystemCallError.new(2).class]
p [SystemCallError.new(0).errno, SystemCallError.new(-1).errno]
p [SystemCallError.new("msg", 2).errno, SystemCallError.new("msg", 2).class]
p Errno::ENOENT.new.errno
c = Class.new(Errno::ENOENT)
p [c.new.message, c.new("custom").message]

# ---- 3. Struct ------------------------------------------------------------
# `keyword_init:` is TRUTHY, not `== true`. Matching only a boolean made this
# a POSITIONAL struct, so `k.new(m: 1).m` was the hash itself.
k = Struct.new(:m, keyword_init: 42)
p [k.keyword_init?, k.new(m: 1).m]
p [Struct.new(:m, keyword_init: true).keyword_init?,
   Struct.new(:m, keyword_init: nil).keyword_init?,
   Struct.new(:m, keyword_init: false).keyword_init?,
   Struct.new(:m).keyword_init?]

# ...and the NAME has to be a constant's: this accepted "lower" and registered
# `Struct::lower`, which no program can then refer to.
p Struct.new("Named199", :a).name
p Struct::Named199.new(1).a
begin
  Struct.new("lower", :a)
rescue => e
  puts "#{e.class}: #{e.message}"
end

# ---- 4. one skipped NAME took the row from every class that shares it -----
# `select` was skipped when the argument-bounds table was generated, because
# Kernel#select and IO.select block on a file descriptor. That removed
# Array#select and Enumerable#select as well, so this answered instead of
# refusing -- while its own alias Array#filter had a row all along.
[-> { [1, 2].select(1) { |x| true } },
 -> { ({ a: 1 }).select(1) { |x| true } },
 -> { Struct.new(:a).new(1).select(1) { |x| true } },
 -> { [1, 2].filter(1) { |x| true } }].each do |f|
  begin
    f.call
  rescue => e
    puts "#{e.class}: #{e.message}"
  end
end
p [[1, 2, 3].select { |x| x > 1 }, ({ a: 1, b: 2 }).select { |_, v| v > 1 },
   Struct.new(:a, :b).new(1, 2).select { |x| x > 1 }]
p [Array.instance_method(:select).arity, Array.instance_method(:filter).arity]
