# Objects as CRuby's test_object asks them (note 342): inspect shows a
# snapshot of the ivars even when one's #inspect removes them, a
# method_missing called by name is private (and, run, is the missing-name
# refusal), Kernel#inspect bound to a String / Array / Hash is Kernel's, an
# undef in Enumerable leaves a builtin class's own method, and the
# "may cause serious problems" warnings cover __id__ and define_method.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message.gsub(/0x\h+/, '0x')}"; end
  puts "#{n}: #{r}"
end
t(1) {
  obj = Object.new
  evil = Object.new
  evil.define_singleton_method(:inspect) { obj.instance_variables.each { |v| obj.remove_instance_variable(v) }; "evil" }
  obj.instance_variable_set(:@evil, evil)
  3.times { |i| obj.instance_variable_set(:"@v#{i}", i) }
  [obj.inspect.sub(/0x\h+/, ""), obj.instance_variables]
}
t(2) { c = Class.new; c.class_eval { undef_method(:method_missing) }; [(c.new.method_missing rescue $!.class), (Class.new.new.method_missing rescue $!.message.sub(/0x\h+/, "")), (Object.new.send(:method_missing) rescue $!.message), (Object.new.send(:method_missing, :q) rescue $!.class), (1.instance_eval { method_missing } rescue $!.class)] }
t(3) { ki = Kernel.instance_method(:inspect); [String, Array, Hash].map { |k| o = Class.new(k).new; o.instance_variable_set(:@a, 1); ki.bind_call(o).gsub(/0x\h+/, "") } }
t(4) { o = Object.new; o.instance_variable_set(:@b, 2); Kernel.instance_method(:inspect).bind_call(o).sub(/0x\h+/, "") }
$stderr = $stdout
$VERBOSE = false
Class.new.define_method(:__send__) {}
class Q320; def __id__; end; end
Class.new.instance_eval { undef_method(:__id__) }
Class.new.instance_eval { remove_method(:initialize) rescue nil }
$VERBOSE = nil
module Enumerable; undef min; end
t(5) { [(1..3).min, [3, 1].min, ((1..2).min {} rescue $!.message), ({a: 1}.min rescue $!.class)] }
