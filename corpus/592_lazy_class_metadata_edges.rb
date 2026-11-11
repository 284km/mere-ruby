leaf = Module.new { def marker; :leaf; end }
middle = Module.new { include leaf }
base = Class.new { include middle }
descendant = Class.new(base)
extra = Module.new { def extra; :extra; end }
descendant.singleton_class.include(extra)
container = Module.new
container.const_set(:Nested, descendant)
leaf = middle = base = descendant = extra = nil
10.times { GC.start }
kept = container.const_get(:Nested)
p [kept.new.marker, kept.extra, kept.superclass.new.marker]

wrapper = Module.new
anonymous = Module.new { def second; :second; end }
wrapper.prepend(anonymous)
root = Class.new { include wrapper }
wrapper = anonymous = nil
10.times { GC.start }
p [root.new.second, root.ancestors.grep(Module).size > 2]
