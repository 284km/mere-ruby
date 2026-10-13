# Class and Object as CRuby's test_class and test_object ask them (note 324):
# Class cannot be subclassed and a non-class superclass is named; an
# uninitialized class makes nothing; a singleton class is not copied and a
# frozen object's refuses a def; an Integer cannot be extended; a private
# method_missing / initialize_copy is a method of every object when called
# with no receiver; remove_instance_variable's NameError carries its receiver
# and name; a class body refuses break / next / redo / return.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message.gsub(/0x\h+/, '0x').lines.first.chomp}"; end
  puts "#{n}: #{r}"
end
t(1) { [(Class.new(Class) rescue $!.message), (Class.new(Module.new) rescue $!.message), (Class.new(Object.new) rescue $!.message)] }
t(2) { [(Class.allocate.new rescue $!.message), (Class.allocate.superclass rescue $!.message)] }
t(3) { o = Object.new; [(o.singleton_class.dup rescue $!.message), (BasicObject.dup rescue $!.message), Class.new.send(:initialize_copy, Class.new).class] }
t(4) { o = Object.new.freeze; [(class << o; def x; end; end rescue $!.class), (o.singleton_class.class_eval { def y; end } rescue $!.class), o.singleton_methods] }
t(5) { [(1.extend(Module.new) rescue $!.message), (:s.extend(Module.new) rescue $!.message), (nil.singleton_class.attached_object rescue $!.message)] }
t(6) { [(1.method_missing(:foo) rescue $!.message), (1.instance_eval { method_missing } rescue $!.message), (Object.new.instance_eval { initialize_copy(1) } rescue $!.message)] }
t(7) { o = Object.new; [(o.remove_instance_variable(:@a) rescue [$!.receiver.equal?(o), $!.name]), (Object.instance_eval { remove_instance_variable(:@zz) } rescue [$!.receiver, $!.name]), (o.instance_variable_get(1) rescue $!.message)] }
t(8) { %w[next break redo retry return].map { |w| begin; eval("class C302; #{w}; end"); :ok; rescue SyntaxError => e; e.message[/Invalid \w+( in class\/module body)?/]; end } }
