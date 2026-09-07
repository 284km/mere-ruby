# Four things this program pins, each of which answered WRONGLY rather than
# raising, so nothing was there to notice them:
#
#   1. dispatch sites that never reached method_missing (and one that reached
#      it when Object already answers)
#   2. an exception raised while another was in flight, which lost its cause
#   3. ENV, which stored whatever it was handed and looked up nothing
#   4. `p exception`, which printed the ivar dump in place of the message

# ---- 1. every operator is a message ---------------------------------------
class Ghost
  # the arguments are reported by CLASS: an object's inspect carries an address,
  # and a corpus program is compared byte for byte
  def method_missing(name, *args) = "MM(#{name},#{args.map { |a| a.class.to_s }})"
  def respond_to_missing?(name, priv = false) = true
end

g = Ghost.new
p g + 1
p g * 2
p(-g)                 # -@ is a message too; it used to answer the receiver
p(+g)
p g[3]
p g.zork(9)
p g < 4

# ...but `<=>` is a real Object method, so method_missing must NOT run: two
# objects that are not == have no ordering, and that is nil, not a missing
# message.
p(g <=> 3)
p(g !~ 3)
o = Object.new
p(o <=> o)
p(o <=> Object.new)

# the coerce protocol re-SENDS the operator to the coerced left value, so
# whatever answers an ordinary call answers here -- including a method_missing.
class Coercer
  def coerce(other) = [Ghost.new, Ghost.new]
end
p 1 + Coercer.new
p 1.5 * Coercer.new
p Rational(3, 4) - Coercer.new

# a coerce that hands back real numbers still computes
class Doubler
  def coerce(other) = [other * 2, 10]
end
p 3 + Doubler.new
p 3 <=> Doubler.new

# Numeric#+@ / #-@ are Numeric's own, so a subclass inherits them: +n is n and
# -n is `0 - n`, which goes through the subclass's coerce.
class Weight < Numeric
  def initialize(v) = @v = v
  def coerce(other) = [other, @v]
  def to_s = "W(#{@v})"
  def inspect = to_s
end
w = Weight.new(100)
p (+w).equal?(w)
p(-w)
p w.respond_to?(:-@)
p Numeric.instance_method(:+@).name

# ---- 2. a raise inside a rescue records what it interrupted ---------------
def cause_chain
  begin
    raise ArgumentError, "inner"
  rescue
    raise "outer"
  end
rescue => e
  [e.class, e.message, e.cause.class, e.cause.message]
end
p cause_chain

# ...for every shape of raise, not just the ones that build an object
p(begin
    begin
      raise "a"
    rescue
      raise TypeError
    end
  rescue => e
    [e.class, e.cause.message]
  end)

# an explicit cause OVERRIDES the one in flight, and `cause: nil` suppresses it
p(begin
    begin
      raise "in flight"
    rescue
      raise "boom", cause: ArgumentError.new("chosen")
    end
  rescue => e
    e.cause.message
  end)
p(begin
    begin
      raise "in flight"
    rescue
      raise "boom", cause: nil
    end
  rescue => e
    e.cause.inspect
  end)
begin
  raise(cause: ArgumentError.new("x"))
rescue => e
  p [e.class, e.message]
end
begin
  raise "m", cause: Object.new
rescue => e
  p [e.class, e.message]
end

# nothing in flight is still nil -- the common case, and the one that made the
# loss invisible
p(begin; raise "alone"; rescue => e; e.cause.inspect; end)

# #detailed_message is the first line of a report; an EMPTY message names the
# exception instead, and an anonymous class has no name to add.
p RuntimeError.new("new error").detailed_message
p RuntimeError.new("").detailed_message
p StandardError.new("").detailed_message
p Class.new(RuntimeError).new("message").detailed_message
p RuntimeError.new("new error").detailed_message(foo: true)

e = RuntimeError.new("Some runtime error")
e.set_backtrace(["a.rb:1", "b.rb:2", "c.rb:3"])
print e.full_message(highlight: false, order: :top)
print e.full_message(highlight: false, order: :bottom)

# ...and #full_message reaches #detailed_message through the dispatcher, so an
# override decides -- which is the entire purpose of the method. The override
# takes ANONYMOUS keywords, which is how ruby's own docs write it.
ov = Exception.new("new error")
def ov.detailed_message(**) = "<prefix>#{message}<suffix>"
p ov.full_message(highlight: false).include?("<prefix>new error<suffix>")

# anonymous parameters bind like named ones
def anon_star(*) = :star
def anon_kw(**) = :kw
def anon_blk(&) = :blk
def anon_mix(x, **) = [x]
p anon_star(1, 2), anon_kw(a: 1), anon_kw, anon_blk { }, anon_mix(7, y: 8)
p method(:anon_kw).parameters, method(:anon_star).parameters

# SystemExit reads a STRING in the status position as the message
p [SystemExit.new("message").status, SystemExit.new("message").message]
p [SystemExit.new(3, "m").status, SystemExit.new(3, "m").message]
p [SystemExit.new(true).status, SystemExit.new(false).status]

# ---- 3. ENV takes strings, and asks for one --------------------------------
class Name
  def initialize(s) = @s = s
  def to_str = @s
end

ENV["MRB_195_A"] = "one"
p ENV[Name.new("MRB_195_A")]
p ENV.key?(Name.new("MRB_195_A"))
p ENV.fetch(Name.new("MRB_195_A"))
p ENV.values_at(Name.new("MRB_195_A"))
p ENV.assoc(Name.new("MRB_195_A"))

# a stored value is converted; the CALL answers the object it was given
val = Name.new("two")
# a String is answered as itself, identity and all; anything else is answered
# as the string it converted to
p ENV.send(:[]=, "MRB_195_B", val)
str = "three"
p ENV.send(:[]=, "MRB_195_D", str).equal?(str)
p ENV["MRB_195_B"]

# slice looks up by the converted string and answers under the key it was GIVEN
p ENV.slice("MRB_195_A")
p ENV.slice(Name.new("MRB_195_A")).values

# a search is only ASKED, never refused: no value equals 1, and that is not an
# error -- while a KEY that cannot become a String is
p ENV.value?(Name.new("one"))
p ENV.value?(1)
p ENV.rassoc(1)
[-> { ENV.values_at(1) }, -> { ENV["MRB_195_C"] = 1 }, -> { ENV[1] = "x" },
 -> { ENV.replace(1) }, -> { ENV.dup }, -> { ENV.clone },
 -> { ENV.clone(freeze: 1) }, -> { ENV.clone(foo: nil) }].each do |f|
  begin
    f.call
  rescue => err
    puts "#{err.class}: #{err.message}"
  end
end
ENV.delete("MRB_195_A")
ENV.delete("MRB_195_B")
ENV.delete("MRB_195_D")
p ENV.key?("MRB_195_A")

# ---- 4. printing an exception ---------------------------------------------
p RuntimeError.new("x")
p [RuntimeError.new("y"), "z"]
print [RuntimeError.new("w")], "\n"
class Tagged < StandardError
  def initialize(m)
    super
    @extra = 5
  end
end
p Tagged.new("m")
p(begin
    begin
      raise "FOO"
    rescue
      begin
        raise "BAR"
      rescue
        [$!, $!.cause]
      end
    end
  end)

# ---- reflection sees the names the dispatcher answers ---------------------
p Symbol.instance_method(:intern).name
p Symbol.instance_method(:slice).name
p String.instance_method(:size).arity
p String.instance_method(:sub).arity
p Integer.instance_method(:+).arity
S195 = Struct.new(:a, :b)
p S195.instance_method(:map).name
p S195.instance_method(:filter).name
p S195.new(1, 2).map { |x| x * 2 }
named = Struct.new(Name.new("Corpus195"), :x)
p named.name

# an anonymous class that answers #name is REPORTED by that name
k = Class.new { def self.name = "MyClass" }
begin
  k.foo
rescue NoMethodError => err
  p err.message
end
m = Module.new { def self.name = "MyModule" }
begin
  m.foo
rescue NoMethodError => err
  p err.message
end

# IO's non-blocking markers: an errno class WITH a marker module mixed in
p IO::EAGAINWaitReadable.superclass == Errno::EAGAIN
p IO::EAGAINWaitReadable.ancestors.include?(IO::WaitReadable)
p IO::EAGAINWaitWritable.ancestors.include?(IO::WaitWritable)
p IO::EAGAINWaitReadable.equal?(IO::EWOULDBLOCKWaitReadable) ==
  Errno::EAGAIN.equal?(Errno::EWOULDBLOCK)
