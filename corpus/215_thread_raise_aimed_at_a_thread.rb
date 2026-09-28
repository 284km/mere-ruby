# `t.raise` on a Thread was answered by Kernel#raise, which raised
# "undefined method 'raise' for main" in the CALLER. Raising into a dead
# thread is a no-op answering nil; raising into the current thread raises
# there, and with no argument it is RuntimeError "" even inside a rescue.
t = Thread.new { :dead }
t.join
p t.raise("Kill the thread")
p t.send(:raise, ArgumentError, "x")
p Thread.public_instance_methods.include?(:raise)
begin
  Thread.current.raise ArgumentError, "boom"
rescue => e
  p [e.class, e.message]
end
begin
  begin; 1 / 0; rescue ZeroDivisionError; Thread.current.raise; end
rescue => e
  p [e.class, e.message]
end
