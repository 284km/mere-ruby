first = Class.new
first.class_eval("def sample; :old; end", "shared generated source", 17)
saved = first.instance_method(:sample)
second = Class.new
second.class_eval("def sample; :other; end", "shared generated source", 29)
a = saved.source_location
b = second.instance_method(:sample).source_location
p [a, b, a[0].frozen?, a[0].equal?(b[0])]
begin
  a[0].replace('changed')
rescue FrozenError
  puts :frozen_path
end
first.class_eval("def sample; :new; end", "replacement source", 41)
GC.start
p [saved.source_location, saved.bind(first.new).call,
   first.instance_method(:sample).source_location]
