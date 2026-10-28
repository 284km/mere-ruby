# Subclasses and copies of the thread primitives, and instances of a Module
# subclass used as modules.
require "delegate"

def show(label)
  r = yield
  puts "#{label}: #{r.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}: #{e.message}"
end

# a subclass of Queue / SizedQueue / ConditionVariable / Mutex is one
class MyQ < Queue; end
q = MyQ.new
show("MyQ class") { q.class }
show("MyQ push/pop") { q.push(1); q << 2; [q.size, q.pop, q.pop] }
show("MyQ respond_to") { q.respond_to?(:push) }
show("MyQ owner") { MyQ.instance_method(:push).owner }
show("MyQ seeded") { MyQ.new([3, 4]).size }

class MySQ < SizedQueue; end
s = MySQ.new(2)
show("MySQ max") { s.push(5); [s.max, s.pop] }

class MyQ2 < Queue
  def initialize(*a)
    @made = true
    super
  end
  attr_reader :made
end
q2 = MyQ2.new([7, 8])
show("MyQ2 super") { [q2.made, q2.size, q2.pop] }

class MySQ2 < SizedQueue
  def initialize(n) = super(n * 2)
end
show("MySQ2 super") { MySQ2.new(3).max }

class MyCV < ConditionVariable; end
cv = MyCV.new
show("MyCV signal") { cv.signal.equal?(cv) }

class MyM < Mutex; end
m = MyM.new
show("MyM synchronize") { m.synchronize { m.locked? } }
show("MyM after") { m.locked? }

# a COPY of one makes the same objects, and a copy without the refusing
# marshal_dump still cannot be dumped
DQ = Queue.dup
show("DQ push/pop") { d = DQ.new; d << 9; d.pop }
DQ.class_eval { remove_method :marshal_dump }
show("DQ dump") { Marshal.dump(DQ.new) }
DC = ConditionVariable.dup
DC.class_eval { remove_method :marshal_dump }
show("DC dump") { Marshal.dump(DC.new) }
show("Queue dump") { Marshal.dump(Queue.new) }
show("SizedQueue dump") { Marshal.dump(SizedQueue.new(1)) }

# an instance of a Module subclass is a module
k = Class.new(Module) do
  def initialize(...)
    include Enumerable
    super
  end
end
mi = k.new
show("include before initialize") { mi < Enumerable }
show("compare") { [Enumerable > mi, mi <=> Enumerable] }

class Bug18185 < Module
  module InstanceMethods; end
  attr_reader :ancestor_list
  def initialize
    @ancestor_list = ancestors
    include InstanceMethods
  end
  class Foo
    attr_reader :key
    def initialize(key:)
      @key = key
    end
  end
end
mod = Bug18185.new
c = Class.new(Bug18185::Foo) { include mod }
anc = c.ancestors
show("in ancestors") { anc.include?(mod) }
show("same object") { anc[1].equal?(mod) }
show("BasicObject once") { anc.count(BasicObject) }
show("key") { c.new(key: 1).key }
show("ancestor_list") { mod.ancestor_list.size == 1 && mod.ancestor_list[0].equal?(mod) }
show("class < mod") { c < mod }

# a delegator around a Time compares as the Time
t1 = Time.utc(2000)
t2 = Time.utc(2001)
d1 = SimpleDelegator.new(t1)
d2 = SimpleDelegator.new(t2)
show("d1 <=> d2") { d1 <=> d2 }
show("d2 <=> d1") { d2 <=> d1 }
show("send <=>") { d2.send(:<=>, t1) }
show("t1 <=> d2") { t1 <=> d2 }
