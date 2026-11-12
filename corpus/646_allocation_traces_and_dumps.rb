# Round 25 of note 545: ObjectSpace.trace_object_allocations records where an
# Object, a String, an Array and a Hash were made (file, line, the method and
# its class -- a block's being its own method's); ObjectSpace.dump writes an
# immediate as its own JSON, a Float's special value, a class's name, and a
# String's control characters as JSON escapes.
require 'objspace'

def make_top = Object.new
class Maker
  def build = [1]
  def self.build_s = { a: 1 }
end

traced = ObjectSpace.trace_object_allocations do
  [make_top, Maker.new.build, Maker.build_s, Object.new]
end
traced.each do |o|
  p [File.basename(ObjectSpace.allocation_sourcefile(o)),
     ObjectSpace.allocation_sourceline(o),
     ObjectSpace.allocation_class_path(o),
     ObjectSpace.allocation_method_id(o)]
end
outside = Object.new
p ObjectSpace.allocation_sourcefile(outside)

# start / stop nest: tracing goes on until the last stop
ObjectSpace.trace_object_allocations_clear
ObjectSpace.trace_object_allocations_start
ObjectSpace.trace_object_allocations_start
ObjectSpace.trace_object_allocations_stop
still = Object.new
ObjectSpace.trace_object_allocations_stop
after = Object.new
p ObjectSpace.allocation_sourceline(still).is_a?(Integer), ObjectSpace.allocation_sourceline(after)
ObjectSpace.trace_object_allocations_clear
p ObjectSpace.allocation_sourceline(still)

# an immediate is its own JSON; a String's control characters are escapes
p ObjectSpace.dump(nil), ObjectSpace.dump(true), ObjectSpace.dump(0), ObjectSpace.dump(:sym)
p ObjectSpace.dump(1.5)
p ObjectSpace.dump("a\x0f\x7f\"b")[/"value":"[^"\\]*(\\.[^"\\]*)*"/]
p ObjectSpace.dump(Float::NAN)[/"value":"[^"]*"/], ObjectSpace.dump(-Float::INFINITY)[/"value":"[^"]*"/]
p ObjectSpace.dump(Object)[/"name":"[^"]*"/], ObjectSpace.dump(Class.new).include?('"name"')
p ObjectSpace.dump(Object.new.singleton_class)[/"real_class_name":"[^"]*", "singleton":true/]
o = Object.new
2.times { |i| o.instance_variable_set("@v#{i}", i) }
p ObjectSpace.dump(o)[/"ivars":\d+/]
