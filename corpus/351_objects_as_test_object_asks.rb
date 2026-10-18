# Objects as test_object asks (note 375): an implicit conversion (#to_ary in
# flatten, Array()) that reaches a method_missing ending in `super` is a
# decline, as ruby's check_funcall_failed makes it; the NoMethodError that
# `super` raises carries #name, #receiver and #args; attr_reader of object_id,
# __id__ or __send__ warns as def does; and an instance variable named in
# another encoding is its own variable, written in UTF-8 by #inspect.
c = Class.new { def method_missing(meth, *args) = super }
b = c.new
p [b].flatten.size, Array(b).size, [[b]].flatten.size
d = Class.new { def method_missing(m, *a) = (m == :to_ary ? [1, 2] : super) }
p [d.new].flatten
e = Class.new { def method_missing(m, *a) = raise(ArgumentError, "x") }
p(([e.new].flatten rescue $!.message))
begin; b.foo(1, 2); rescue NoMethodError => x; p [x.name, x.receiver.equal?(b), x.args]; end
require 'stringio'
old, $stderr = $stderr, StringIO.new
$VERBOSE = false
Class.new.attr_reader(:__id__)
Class.new.attr_accessor(:object_id)
Class.new.attr_writer(:__send__)
w = $stderr.string
$stderr = old
p w.lines.map { |l| l.sub(/^.*?warning: /, "") }
x = Object.new
x.instance_variable_set(:@a, 1)
x.instance_variable_set("@い", 42)
x.instance_variable_set("@う".encode(Encoding::EUC_JP), 6)
p x.inspect =~ /@う=6\b/ ? :shown : x.inspect.b
p x.instance_variable_get("@う"), x.instance_variable_get("@う".encode(Encoding::EUC_JP)), x.instance_variables.size
