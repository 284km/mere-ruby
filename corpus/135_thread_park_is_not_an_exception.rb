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
