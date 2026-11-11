# Each invocation returns a fresh class including that invocation's module.
code = proc do
  scratch = Module.new
  Class.new { include scratch }
end
classes = []
40.times { classes << code.call }
GC.start
raise unless classes.uniq.size == 40
raise unless classes.all? { |klass| klass.new.class.equal?(klass) && klass.ancestors[1].is_a?(Module) }

# Assignment to an existing captured local remains visible after the call.
existing = nil
outer_code = proc do
  existing = Module.new
  Class.new { include existing }
end
created = outer_code.call
raise unless created.ancestors.include?(existing)

# A constructor override must run and can supply a different module.
replacement = Module.new
Module.define_singleton_method(:new) { replacement }
created = code.call
Module.singleton_class.send(:remove_method, :new)
raise unless created.ancestors.include?(replacement)

# inherited can replace the captured module between the two statements.
alternate = Module.new
Object.define_singleton_method(:inherited) { |child| existing = alternate }
created = outer_code.call
Object.singleton_class.send(:remove_method, :inherited)
raise unless created.ancestors.include?(alternate)

# A real body statement is executed, rather than treated as metadata.
seen = []
observed = proc do
  scratch = Module.new
  seen << :body
  Class.new { include scratch }
end
observed.call
raise unless seen == [:body]
GC.start
raise unless classes.all? { |klass| klass.new.class.equal?(klass) }
puts 'metadata-only block guards preserve values, captured locals, and callbacks'
