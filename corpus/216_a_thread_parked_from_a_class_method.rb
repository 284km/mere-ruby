# A bare `sleep` whose self is a module or class -- a class method, or a
# Thread block written inside one -- was "undefined method 'sleep' for
# module M": sleep/fork/exit live apart from Kernel's other functions and the
# class-self path had no route to them, so the thread died instead of
# parking. And Thread#to_s was `#<Thread:0x..>` with no place or status,
# while `p thread` showed its bookkeeping ivars.
module M
  def self.nap
    sleep(0)
  end
  def self.go
    Thread.new { sleep }
  end
end
class C
  def self.go
    Thread.new { sleep; :woke }
  end
end
p M.nap
t = M.go
Thread.pass while t.status == "run"
p [t.alive?, t.status, t.stop?]
u = C.go
Thread.pass while u.status == "run"
p [u.alive?, u.status]
p t.to_s.sub(/0x\h+/, "X"), t.inspect.sub(/0x\h+/, "X")
t.kill; t.join
p t.to_s.sub(/0x\h+/, "X")
t.name = "worker"
p t.inspect.sub(/0x\h+/, "X"), t.to_s.encoding
p Thread.current.to_s.sub(/0x\h+/, "X")
