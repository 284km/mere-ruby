def report(label, receiver)
  yield
rescue NameError => error
  p [label, error.class.name, error.name, (error.respond_to?(:args) ? error.args : nil), error.receiver.equal?(receiver)]
end
[
  [:nil, nil], [:false, false], [:true, true], [:integer, 1],
  [:bignum, 2**80], [:float, 1.5], [:rational, 1r], [:complex, 1i],
  [:string, +"x"], [:array, []], [:hash, {}], [:symbol, :x],
  [:range, 1..2], [:regexp, /x/], [:proc, proc {}],
  [:class, Class.new], [:module, Module.new], [:object, Object.new]
].each do |label, receiver|
  report([label, :bare], receiver) { receiver.instance_eval { missing_primitive_probe } }
  report([label, :parenthesized], receiver) { receiver.instance_eval { missing_primitive_probe() } }
  report([label, :argument], receiver) { receiver.instance_eval { missing_primitive_probe(42) } }
  report([label, :explicit], receiver) { receiver.missing_primitive_probe }
end
class String
  def method_missing(name, *args)
    return [:handled, name, args] if name == :handled_primitive_probe
    super
  end
end
string = +"x"
p string.instance_eval { handled_primitive_probe }
p string.instance_eval { handled_primitive_probe(42) }
report(:super_bare, string) { string.instance_eval { missing_primitive_probe } }
report(:super_parenthesized, string) { string.instance_eval { missing_primitive_probe() } }
p string.instance_eval { upcase }
p nil.instance_eval { to_s }
begin
  nil.instance_eval { Integer.sqrt }
rescue ArgumentError => error
  p [error.class.name, error.message]
end
class CoercionRaise
  def to_str = self.missing_conversion_probe
end
begin
  (+"x").instance_eval { concat(CoercionRaise.new) }
rescue NameError => error
  p [:nested, error.class.name, error.name, error.receiver.class.name]
end

begin
  nil.instance_eval { missing_nil_vcall }
rescue NameError => error
  p [:nil_message, error.message, error.receiver.equal?(nil)]
end

class MissingConversion
  def method_missing(name, *args)
    super
  end
end
missing_conversion = MissingConversion.new
missing_after_rescue rescue nil
p [:after_rescue, [missing_conversion].flatten.first.equal?(missing_conversion)]
