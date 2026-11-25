# RubyVM.stat: ruby's counters, by name or into a Hash. The values are each
# implementation's own; what is compared is their names, their class, the Hash
# filled in place, and the errors.
h = RubyVM.stat
p h.class, h.keys
p h.values.all?(Integer)
p RubyVM.stat(:next_shape_id).class
p RubyVM.stat(:constant_cache_misses).class

mine = {a: 1}
r = RubyVM.stat(mine)
p r.equal?(mine), mine.keys

class MyHash < Hash; end
m = MyHash.new
p RubyVM.stat(m).equal?(m), m.size

p RubyVM.method(:stat).arity

[[:unknown], [:"\u{30eb 30d3 30fc}"], [1], ["next_shape_id"], [nil], [{}.freeze], [1, 2]].each do |args|
  begin
    RubyVM.stat(*args)
    puts "no error for #{args.inspect}"
  rescue => e
    puts "#{e.class}: #{e.message}"
  end
end
