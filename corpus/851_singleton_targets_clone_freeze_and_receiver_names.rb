# Seven gaps found while round three of test_ast's speed was written (note
# 551), each against ruby 4.0:
# - a NoMethodError a builtin's leaf raised named no receiver ("undefined
#   method 'upcase'" for nil.upcase);
# - define_singleton_method on a Binding or a Proc was "can't define singleton";
# - `def s.x` on a frozen String, and define_singleton_method on one, went
#   through: a deduplicated string (a frozen literal, -"s") is ruby's
#   TypeError, one frozen at run time its FrozenError;
# - clone(freeze: true) did not freeze a String, an Array or a Hash;
# - `def o.singleton_method_added` did not hear its own definition;
# - a Struct class's singleton_methods had no :inspect;
# - a class's or a module's singleton class answered no singleton_methods.
def t(label)
  r = yield
  p [label, r]
rescue Exception => e
  p [label, e.class, e.message]
end

# receiver names
t(:nil_upcase) { nil.upcase }
t(:nil_push) { nil.push(1) }
t(:int_upcase) { 1.upcase }
t(:true_upcase) { true.upcase }
t(:arr_upcase) { [].upcase }
t(:nil_foo) { nil.foo }
t(:recv) { begin; nil.downcase; rescue NoMethodError => e; [e.name, e.receiver]; end }

# singleton definitions
t(:bind) { b = binding; b.define_singleton_method(:zz) { 1 }; b.zz }
t(:proc) { pr = proc {}; pr.define_singleton_method(:zz) { 2 }; pr.zz }
t(:bind_def) { b = binding; def b.zz = 3; b.zz }
t(:lit) { fz = "abc".freeze; def fz.x = 1; fz.x }
t(:minus) { s = -"zz"; def s.x = 1; s.x }
t(:dupfrz) { s = "y".dup.freeze; def s.x = 1; s.x }
t(:plain) { s = +"w"; def s.x = 1; s.x }
t(:dsm_lit) { fz = "abc".freeze; fz.define_singleton_method(:q) { 1 }; fz.q }
t(:dsm_frz) { s = "y".dup.freeze; s.define_singleton_method(:q) { 1 }; s.q }
t(:arr_frz) { a = [1].freeze; def a.x = 1; a.x }
t(:hsh_frz) { h = {a: 1}.freeze; h.define_singleton_method(:x) { 1 }; h.x }
t(:sc_lit) { def SC.x = 1; SC.x } if (SC = "const".freeze)
t(:sc_class) { SC.singleton_class }
t(:obj_frz) { o = Object.new.freeze; begin; def o.x = 1; rescue FrozenError => e; [e.class, e.message[/\A[^:]*/], e.receiver.equal?(o)]; end }

# clone(freeze:)
t(:clone_s) { s = "x"; [s.clone(freeze: true).frozen?, s.clone(freeze: false).frozen?, s.clone.frozen?, s.freeze.clone(freeze: false).frozen?, s.clone.frozen?] }
t(:clone_a) { a = [1]; [a.clone(freeze: true).frozen?, a.freeze.clone.frozen?, a.clone(freeze: false).frozen?] }
t(:clone_h) { h = {}; [h.clone(freeze: true).frozen?, h.clone(freeze: nil).frozen?] }
t(:clone_o) { o = Object.new; [o.clone(freeze: true).frozen?, o.frozen?] }

# singleton_method_added hearing its own definition
$log = []
t(:sma) { o = Object.new; def o.singleton_method_added(n) = $log << n; def o.foo = 1; def o.bar = 2; $log }
$log2 = []
t(:sma_redef) do
  o = Object.new
  def o.singleton_method_added(n) = $log2 << [:old, n]
  def o.singleton_method_added(n) = $log2 << [:new, n]
  $log2
end

# Struct class singleton inspect
St = Struct.new(:a)
Kw = Struct.new(:a, keyword_init: true)
t(:st) { [St.singleton_methods.sort, St.inspect, Kw.inspect, Kw.singleton_methods.include?(:inspect)] }

# singleton_methods of singleton classes
class SC0; def self.k = 1; end
class SC1 < SC0; def self.j = 2; end
module Mo; end
class Mm; class << self; class << self; def mm; end; end; end; end
t(:g1) { SC1.singleton_methods.sort }
t(:g2) { SC1.singleton_class.singleton_methods.sort }
t(:g3) { SC1.singleton_methods(false).sort }
t(:g4) { Mo.singleton_class.singleton_methods.sort }
t(:g5) { Object.new.singleton_class.singleton_methods.sort }
t(:g6) { [Mm.singleton_class.singleton_methods.sort, Mm.singleton_class.singleton_methods(false)] }
