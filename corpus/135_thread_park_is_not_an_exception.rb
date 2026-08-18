# A thread that is killed while sleeping runs its ensure blocks, and `$!` there
# is nil: the kill is not an exception the program raised. This interpreter
# parks a thread by raising an internal __ThreadPark, and that leaked into $!,
# so the ensure saw `#<__ThreadPark: sleep>` -- an implementation detail, in a
# variable a program reads.
doit = false
exc = :unset
t = Thread.new do
  begin
    doit = true
    sleep 10
  ensure
    exc = $!
  end
end
Thread.pass until doit
t.kill
t.join
p exc

# a thread that finishes normally is unaffected
t2 = Thread.new { :done }
p t2.value

# and outside a thread nothing changed
begin
  begin
    raise ArgumentError, "outer"
  ensure
    p $!.class
  end
rescue ArgumentError
  p :rescued
end

# `$!` holds the exception being handled, and once a rescue has HANDLED it the
# exception is no longer in flight: the ensure that follows sees nil. It stayed
# set here, so an ensure could not tell "we are unwinding" from "we recovered" --
# which is most of what an ensure asks $! for.
begin
  raise "x"
rescue => e
  p ["in rescue", $!.class]
ensure
  p ["after handled", $!.inspect]
end

begin
  begin
    raise ArgumentError, "y"
  ensure
    p ["while unwinding", $!.class]
  end
rescue ArgumentError
  p :rescued
end
p $!.inspect

# a bare `raise` inside a rescue still re-raises what is being handled
begin
  begin
    raise "inner"
  rescue
    raise
  end
rescue => e
  p ["re-raised", e.message]
end
