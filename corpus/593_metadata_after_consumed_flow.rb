def previous_return
  return :previous
end
previous_return
constructor = proc { local = Module.new; Class.new { include local } }
p constructor.call.is_a?(Class)
10.times { constructor.call; GC.start }
events = []
Object.define_singleton_method(:inherited) { |child| events << :inherited }
p constructor.call.is_a?(Class)
Object.singleton_class.send(:remove_method, :inherited)
p events

def leaving_through_ensure(builder, events)
  begin
    return :returned
  ensure
    events << builder.call.is_a?(Class)
  end
end
p leaving_through_ensure(constructor, events)
p catch(:finish) {
  begin
    throw :finish, :thrown
  ensure
    events << constructor.call.is_a?(Class)
  end
}
p events
