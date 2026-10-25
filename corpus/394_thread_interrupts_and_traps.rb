# Thread.handle_interrupt holding back Thread#raise and SIGINT, a trap that
# joins the thread that sent the signal, an orphan break across threads, and the threads killed when the program ends

q = Thread::Queue.new
r = nil
th = Thread.new do
  begin
    Thread.handle_interrupt(Object => :on_blocking) do
      Thread.current.raise RuntimeError, "later"
      r = :not_yet
      sleep
    end
  rescue RuntimeError => e
    q << [r, e.message]
  end
end
p q.pop
th.join

Thread.handle_interrupt(RuntimeError => :never) do
  done = false
  t = Thread.new do
    Thread.pass until done
    p [:pending, Thread.pending_interrupt?]
    begin
      Thread.handle_interrupt(Object => :immediate) {}
    rescue RuntimeError
      p :delivered
    end
  end
  Thread.pass until t.stop? || t.status == "run"
  t.raise
  done = true
  t.join
end

waiting = Thread::Queue.new
release = Thread::Queue.new
inner = false
Thread.new do
  waiting.pop
  Process.kill(:INT, Process.pid)
  release.push(true)
end
begin
  Thread.handle_interrupt(SignalException => :never) do
    begin
      waiting.push(true)
      release.pop
    rescue Interrupt
      inner = true
      raise
    end
  end
rescue Interrupt
  p [:outer, inner]
end

t0 = Thread.current
t = Thread.new { Thread.pass until t0.stop?; Process.kill(:USR1, $$); :normal_end }
trap(:USR1) { p [:trap, Thread.current == t0, t.value] }
p t.value
trap(:USR1, "DEFAULT")

o = Object.new
def o.foo
  Thread.new do
    begin
      (-> { yield 42 }).call
    rescue LocalJumpError => e
      p [:lje, e.message]
    end
  end.join
end
p o.to_enum(:foo).first
r = nil
o.foo { |x| r = x; break }
p r

m = Thread.current
Thread.new do
  begin
    m.run
    Thread.pass until m.stop?
    p :not_reached
  ensure
    puts "#{m.alive?} #{m.status} #{Thread.current.status}"
  end
end
Thread.pass
