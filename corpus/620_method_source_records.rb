eval("def foo; :foo; end\ndef oo; :oo; end\n", TOPLEVEL_BINDING, "source-row-old.rb", 100)
p [method(:foo).source_location, method(:oo).source_location]
aliased = Object.class_eval { alias_method :row_alias, :foo; instance_method(:row_alias) }
p aliased.source_location
eval("def foo = :new_foo\n", TOPLEVEL_BINDING, "source-row-new.rb", 200)
GC.start
p [method(:foo).source_location, foo, oo]
klass = Class.new do
  def source_row_first; :class_value; end
  alias source_row_second source_row_first
end
copy = klass.clone
method_copy = copy.instance_method(:source_row_second)
original_site = klass.instance_method(:source_row_first).source_location
old_class_method = klass.instance_method(:source_row_first)
klass.class_eval("def source_row_first; :new_class_value; end", "source-row-class-new.rb", 300)
GC.start
p [method_copy.source_location == original_site, method_copy.bind(copy.new).call]
p [old_class_method.source_location == original_site, old_class_method.bind(klass.new).call, klass.new.source_row_first]
events = []
trace = TracePoint.new(:call, :return) do |event|
  events << [event.event, event.method_id, event.lineno] if [:foo, :oo].include?(event.method_id)
end
trace.enable { foo; oo }
p events
