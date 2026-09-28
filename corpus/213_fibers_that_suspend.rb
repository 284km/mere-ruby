# A Fiber used to run its whole body on the first #resume -- there was nothing
# to suspend -- and Fiber.yield did not exist. Each fiber's body now runs on a
# thread of its own, handed control strictly (see m_fiber.mere), so everything
# below is about what a SUSPENDED stack must keep and what it must not leak.

# values in and out of a suspension
f = Fiber.new { |x| y = Fiber.yield(x + 1); z = Fiber.yield(y * 2); "#{z}!" }
p f.resume(1), f.resume(10), f.resume(:done), f.alive?

# a generator that never ends, stepped
fib = Fiber.new { a, b = 0, 1; loop { Fiber.yield a; a, b = b, a + b } }
p 12.times.map { fib.resume }

# nested fibers: an inner resume returns to the outer, not to the root
outer = Fiber.new do
  inner = Fiber.new { Fiber.yield :inner1; :inner_done }
  a = inner.resume
  Fiber.yield [:outer, a]
  [inner.resume, inner.alive?]
end
p outer.resume, outer.resume

# an exception inside a fiber comes out of #resume, and the fiber is dead
bad = Fiber.new { Fiber.yield 1; raise KeyError, "inside" }
p bad.resume
begin
  bad.resume
rescue KeyError => e
  p [e.class, e.message, bad.alive?]
end

# ...and one rescued inside does not leak out
ok = Fiber.new do
  begin
    raise "handled"
  rescue => e
    Fiber.yield e.message
  end
  :after
end
p ok.resume, ok.resume

# kill runs ensure and no rescue; a parent killed from its child stops at once
k = Fiber.new do
  begin
    loop { Fiber.yield :tick }
  rescue Exception
    puts "rescue must not run"
  ensure
    puts "ensure ran"
  end
end
k.resume
p k.kill.alive?
parent = Fiber.new do
  Fiber.new { parent.kill; puts "child must not continue" }.resume
  puts "parent must not continue"
end
# (what that #resume returns is not printed: ruby 4.0.6 answers the class
# RuntimeError there, which is its kill machinery showing, not a value)
parent.resume
p parent.alive?

# break / return out of a fiber's block, and throw with no catch in THIS fiber
[-> { Fiber.new { break }.resume }, -> { Fiber.new { return }.resume }].each do |l|
  begin
    l.call
  rescue LocalJumpError => e
    p [e.class, e.message]
  end
end
catch(:outside) do
  begin
    Fiber.new { throw :outside }.resume
  rescue UncaughtThrowError => e
    p [e.class, e.tag]
  end
end

# a recursion inside a fiber (the fiber's stack is its own thread's). ruby's
# fibers get a smaller VM stack than its main thread -- 5000 levels is a
# SystemStackError there -- so this stays well inside what both can do.
def depth(n) = n.zero? ? 0 : 1 + depth(n - 1)
p Fiber.new { depth(800) }.resume
p caller.size == Fiber.new { caller.size }.resume

# $~ and $! belong to the stack that set them
"abc" =~ /b/
g = Fiber.new { "xyz" =~ /z/; Fiber.yield $~[0]; $~[0] }
p g.resume, $~[0], g.resume

# transfer, and where a transferred fiber returns
states = []
f1 = Fiber.new { states << :f1; Fiber.current }
f2 = Fiber.new { states << :f2; f1.transfer; states << :unreached }
f3 = Fiber.new { states << :f3; f2.transfer; states << :f3_back }
f3.resume
p states

# storage: inherited as a copy, never written back
Fiber[:who] = :root
child = Fiber.new do
  Fiber[:who] = :child
  [Fiber[:who], Fiber.new { Fiber[:who] }.resume]
end
p child.resume, Fiber[:who]

# Thread#[] is fiber-local; thread variables are not
Thread.current[:fl] = :root
Thread.current.thread_variable_set(:tv, :shared)
p Fiber.new { [Thread.current[:fl], Thread.current.thread_variable_get(:tv)] }.resume

# a thousand suspended fibers at once, then each resumed to the end
fs = (1..1000).map { |i| Fiber.new { Fiber.yield i; i * 2 } }
p fs.sum(&:resume), fs.sum(&:resume), fs.count(&:alive?)

# the status words
p [Fiber.new {}.inspect[/\((\w+)\)/, 1], Fiber.current.inspect[/\((\w+)\)/, 1]]
