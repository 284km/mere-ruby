# A `yield` in a define_method body is the block of the method the body was
# WRITTEN in, called whenever the defined method runs -- also after that
# method has returned. It was found when the body was written straight in
# the method or in a class_eval block; in a `Module.new { }` / `Class.new { }`
# block, and for define_method / define_singleton_method with a receiver,
# it was "no block given (yield)". activerecord's migrator test wraps a
# migration so:
#   x.extend(Module.new { define_method(:up) { yield(:up, x); super() } })
class Sensor; def up = :base_up; def down = :base_down; end
def wrap(name)
  x = Sensor.new
  x.extend(Module.new {
    define_method(:up) { yield(:up, name); super() }
    define_method(:down) { yield(:down, name); super() }
  }) if block_given?
  x
end
calls = []
x = wrap(:a) { |dir, n| calls << [dir, n] }
p x.up, x.public_send(:down), x.up, calls
p wrap(:b).up

def in_module = Module.new { define_method(:go) { yield 2 } }
p Object.new.extend(in_module { |v| v * 2 }).go
def in_class = Class.new { define_method(:go) { yield 3 } }
p in_class { |v| v * 3 }.new.go
def in_nested = Module.new { [1].each { define_method(:go) { yield 5 } } }
p Object.new.extend(in_nested { |v| v * 5 }).go
def in_struct = Struct.new(:a) { define_method(:go) { yield a } }
p in_struct { |v| v * 7 }.new(1).go

# with a receiver
def on_singleton
  o = Object.new
  o.define_singleton_method(:go) { yield 1 }
  o
end
p on_singleton { |v| v + 1 }.go
def on_class(k) = k.define_method(:go) { yield 6 }
k = Class.new
on_class(k) { |v| v * 6 }
p k.new.go
def on_class_eval
  k = Class.new
  k.class_eval { define_method(:go) { yield 8 } }
  k
end
p on_class_eval { |v| v * 8 }.new.go

# a method with no block: the body's yield is LocalJumpError
def no_block = Module.new { define_method(:go) { yield 9 } }
begin
  Object.new.extend(no_block).go
rescue LocalJumpError => e
  p e.message
end
# block_given? in the body asks the same frame
def given = Module.new { define_method(:go) { block_given? } }
p Object.new.extend(given { }).go, Object.new.extend(given).go
# a proc keeps its method's block, as ever
def pr = proc { yield 4 }
p pr { |v| v * 4 }.call
