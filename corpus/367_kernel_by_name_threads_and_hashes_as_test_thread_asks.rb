# Kernel functions by name, threads started from Method objects, the
# outermost #hash, and the file a block reports after a string *_eval

# Kernel functions through send and Method objects
o = Object.new
p o.send(:sleep, 0), send(:sleep, 0)
p o.send(:catch) { |t| 1 }, send(:catch) { throw :x, 2 rescue 3 }
p((o.send(:format) rescue $!.class), (send(:sprintf) rescue $!.class))
p o.send(:at_exit) { }.class
p method(:Integer).to_proc.call("12"), [1, 2].map(&method(:Float))
p method(:format).to_proc.call("%03d", 7)
p method(:Integer).call("1") { }, send(:format, "%d", 3) { }

class Runner
  class T < ::Thread
    def self.new(*)
      super
    end
  end

  def go
    t = Thread.new(&method(:sleep).to_proc)
    Thread.pass until t.stop?
    p t.status
    t.kill; t.join
    p Thread.new(&Module.method(:nesting)).value
    p T.new(&Module.method(:nesting)).value
    p T.new(:to_s, &Class.new.method(:undef_method)).join.class
    p T.new("5", &method(:Integer)).value
  end
end
Runner.new.go

# a cycle found inside an inner #hash unwinds to the outermost one
arr = []
obj = Struct.new(:foo, :visited).new(arr, false)
arr << obj
def obj.hash
  self[:visited] = true
  super
  raise "recursive_outer should short circuit intermediate calls"
end
p((arr.hash; :ok), obj[:visited])
a = [1]; a << a; b = [1]; b << b
p a.hash == b.hash
x = catch(:t) { c = Object.new; c.define_singleton_method(:hash) { throw :t, 5 }; [c].hash }
p x

# the file a block reports after a string *_eval, raised or not
Module.new { module_eval("1") }
p proc {}.source_location[0] == __FILE__
Object.new.instance_eval("2")
p proc {}.source_location[0] == __FILE__
begin; eval("raise 'x'"); rescue; end
p proc {}.source_location[0] == __FILE__
begin; Object.new.instance_eval("raise 'y'"); rescue; end
p proc {}.source_location[0] == __FILE__
