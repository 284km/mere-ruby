# An exception OBJECT reports its own message. There are two exception
# representations here: a class-and-message pair (what `raise "x"` makes) and a
# real object with ivars (what a class with its own #initialize makes). The
# object one reported `#<StandardError:0x..>` as its message, because a branch
# added to make `p obj` and `obj.inspect` agree -- for ORDINARY objects -- caught
# exceptions on the way past. The pair representation never goes through it,
# which is why `raise "x"; rescue => e; e.message` always looked fine.
e = StandardError.new("s")
p [e.to_s, e.inspect, e.message]
p StandardError.new.message          # no message: the class name
p RuntimeError.new("r").message

class Custom < StandardError
  def initialize(msg = "custom default")
    super
  end
end
class WithCode < StandardError
  attr_reader :code
  def initialize(code)
    @code = code
    super("code #{code}")
  end
end
p Custom.new.message
p Custom.new("given").message
p WithCode.new(7).message
p WithCode.new(7).code

# ... through the shapes that raise it
def in_a_method; raise Custom; end
begin
  in_a_method
rescue => ex
  p [ex.class, ex.message]
end
begin
  [1].each { raise WithCode.new(8) }
rescue => ex
  p [ex.class, ex.message, ex.code]
end
begin
  raise Custom, "reraised"
rescue => ex
  begin
    raise ex
  rescue => ex2
    p ex2.message
  end
end

# equal when the class and the message are equal, as in ruby
p [StandardError.new("a") == StandardError.new("a"), StandardError.new("a") == StandardError.new("b")]

# a user-defined #message still wins
class Own < StandardError
  def message; "mine"; end
end
p Own.new.message

# full_message: the frame it was raised on, the message, the class
err = StandardError.new("a")
err.set_backtrace(["x"])
p err.full_message

# respond_to? agrees with what is answered (`exception` and `cause` are not
# implemented, and it says so rather than promising them -- KNOWN_GAPS.md)
p [err.respond_to?(:message), err.respond_to?(:backtrace), err.respond_to?(:full_message)]
