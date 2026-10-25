# Queue and ConditionVariable refusals, a timed-out wait, Comparable's ==
# and its error, Integer#[] past the word, Integer() of a wide string, a
# missing super, a frozen class's singleton, and Fiber#to_s

def show(e) = [e.class, e.message.gsub(/0x\h+/, "X")]

[-> { Thread::Queue.allocate.push(nil) }, -> { Thread::SizedQueue.allocate.push(nil) },
 -> { Thread::Queue.new.freeze }, -> { Thread::SizedQueue.new(5).freeze },
 -> { Marshal.dump(Thread::Queue.new) }, -> { Marshal.dump(Thread::ConditionVariable.new) },
 -> { Thread::ConditionVariable.new.dup }, -> { Thread::ConditionVariable.new.clone },
 -> { Thread::SizedQueue.new(2).max = 0 }, -> { Thread::SizedQueue.new(2).max = -1 }].each do |f|
  begin
    p f.call.class
  rescue => e
    p show(e)
  end
end
q = Thread::SizedQueue.new(2); q.max = 1; p q.max
m = Thread::Mutex.new
cv = Thread::ConditionVariable.new
m.synchronize { p cv.wait(m, 0.05) }
m.synchronize { p m.sleep(0.01) }
t = Thread.new { m.synchronize { p cv.wait(m, 5).class } }
sleep 0.1 until t.status == "sleep"
m.synchronize { cv.signal }
t.join

o = Object.new
o.extend(Comparable)
def o.<=>(x) = 0 <=> x
p o == o, o.clamp(-1, 3).equal?(o), o.clamp(-1..3).equal?(o), o.clamp(1, 2)
lab = Class.new
def lab.to_s = "Eエラー"
[-> { 1.0 < lab.new }, -> { 1 < lab.new }].each { |f| begin; f.call; rescue ArgumentError => e; p e.message; end }

p((-16)[-66..], (-16)[-66...], 15[-3..], (-1)[0..], (-2**70)[-80..], (2**70)[60..65], (2**70)[68..])
begin; Integer("0".encode("utf-16be")); rescue => e; p show(e); end
begin; Integer("0".encode("utf-16le")); rescue => e; p show(e); end

ms = Class.new { def foo = super }.new
begin; ms.foo; rescue NoMethodError => e; p e.receiver.equal?(ms), e.name, e.args; end

class FrzA; freeze; end
[-> { FrzA.instance_variable_set(:@a, 1) }, -> { FrzA.singleton_class.instance_variable_set(:@a, 1) }].each do |f|
  begin; f.call; rescue FrozenError => e; p e.message; end
end

def fst(f) = f.to_s[/\((\w+)\)/, 1]
fb = Fiber.new { p fst(fb); Fiber.yield }
p fst(fb); fb.resume; p fst(fb); fb.resume; p fst(fb)
p fb.to_s == fb.inspect
