# GC.stat(:total_allocated_objects) and ObjectSpace.each_object agree: an
# object counted is an object each_object finds, and the interpreter makes
# none the program does not see -- GC.stat built its whole Hash to answer one
# key, every method frame made an Array of its arguments that only Struct's
# initializer reads, and a flow signal made Strings (sqlite3's
# test_step_does_not_allocate_when_done measures a C method that allocates
# nothing)
GC.disable
def strings = (n = 0; ObjectSpace.each_object(String) { n += 1 }; n)
def arrays = (n = 0; ObjectSpace.each_object(Array) { n += 1 }; n)
def measure(n)
  s0 = strings; a0 = arrays; t0 = GC.stat(:total_allocated_objects)
  n.times { yield }
  t1 = GC.stat(:total_allocated_objects); a1 = arrays; s1 = strings
  [t1 - t0, s1 - s0, a1 - a0]
end
class C
  def i(a) = a
  def self.c(a, b) = b
end
o = C.new
def m1(a) = a
cases = [[:strings, proc { "a" + "b" }], [:arrays, proc { [1, 2] }], [:instance_call, proc { o.i(1) }],
         [:class_call, proc { C.c(1, 2) }], [:main_call, proc { m1(1) }], [:stat, proc { GC.stat(:count) }]]
# (each case once first: a first call may fill a cache, in either runtime)
2.times { cases.each { |_, pr| measure(1, &pr) } }
base = measure(0) { }
cases.each do |name, pr|
  [1, 10].each do |n|
    t, s, a = measure(n, &pr)
    p [name, n, t - base[0], s - base[1], a - base[2]]
  end
end
p GC.stat(:count).is_a?(Integer), GC.stat[:total_allocated_objects].is_a?(Integer)
begin
  GC.stat(:no_such_key)
rescue ArgumentError => e
  p e.message
end
