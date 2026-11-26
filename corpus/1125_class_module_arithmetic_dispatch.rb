def report(label, left, right)
  result = yield
  p [label, :result, result]
rescue Exception => error
  p [label, error.class.name, (error.is_a?(NameError) ? error.name : nil),
     (error.is_a?(NoMethodError) ? error.receiver.equal?(left) : nil),
     (error.is_a?(NoMethodError) ? error.args == [right] : nil)]
end
LeftClass = Class.new
LeftModule = Module.new
[LeftClass, LeftModule].each do |left|
  ['+', '-', '*', '/', '%', '**', '<<', '>>'].each do |operator|
    right = 42
    report([left.name, operator], left, right) { eval("left #{operator} right", binding) }
    report([left.name, :method, operator], left, right) { left.public_send(operator, right) }
  end
end
class ArithmeticParent
  def self.+(other) = [:inherited, other]
end
class ArithmeticChild < ArithmeticParent; end
p ArithmeticChild + 42
class ArithmeticMissing
  def self.method_missing(name, *args)
    return [:missing, name, args] if [:+, :-, :*, :/, :%, :**, :<<, :>>].include?(name)
    super
  end
end
p ArithmeticMissing + 42
p ArithmeticMissing << 42
module ArithmeticModule
  def self.+(other) = [:module, other]
end
p ArithmeticModule + 42
class LateArithmetic; end
def install_operator
  def LateArithmetic.+(other) = [:late, other]
  42
end
p LateArithmetic + install_operator
p [ArithmeticChild < ArithmeticParent, ArithmeticParent > ArithmeticChild,
   ArithmeticChild <= ArithmeticParent, ArithmeticParent >= ArithmeticChild,
   ArithmeticChild <=> ArithmeticParent, ArithmeticParent <=> ArithmeticChild]
