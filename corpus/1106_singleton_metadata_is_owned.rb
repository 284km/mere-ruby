map = ObjectSpace::WeakMap.new
kept = []
1000.times do |index|
  object = Object.new
  payload = [index]
  object.define_singleton_method(:value) { payload }
  map[object] = true
  kept << object if index % 200 == 0
end
GC.start
GC.start
p kept.map(&:value)
# Conservative native stacks can retain some values; the table must not
# keep every receiver alive through its own singleton-method metadata.
p map.size < 500

def singleton_method_1106
  object = Object.new
  payload = [:retained_method]
  object.define_singleton_method(:value) { payload }
  object.method(:value)
end
method = singleton_method_1106
GC.start
p method.call

def singleton_class_1106(map)
  object = Object.new
  object.define_singleton_method(:value) { :retained_class }
  map[object] = true
  object.singleton_class
end
class_map = ObjectSpace::WeakMap.new
singleton = singleton_class_1106(class_map)
singleton.const_set(:Payload, [:constant])
GC.start
p class_map.size
p singleton.const_get(:Payload)
p singleton.instance_method(:value).owner.equal?(singleton)

map2 = ObjectSpace::WeakMap.new
1000.times do
  object = Object.new
  body = proc { object }
  object.define_singleton_method(:myself, body)
  map2[object] = true
end
GC.start
GC.start
p map2.size < 500
