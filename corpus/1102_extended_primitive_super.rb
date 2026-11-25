module ExtendedBase1102
  def hi(*args, &block)
    [self.class, args, block && block.call]
  end
end
module ExtendedMiddle1102
  def hi(*args, &block) = [:middle, super]
end
module ExtendedTop1102
  def hi(*args, &block) = [:top, super]
end

[Object.new, +"x", [], {}].each do |object|
  object.extend(ExtendedBase1102)
  object.extend(ExtendedMiddle1102)
  object.extend(ExtendedTop1102)
  p object.hi(1, 2) { :block }
  p object.method(:hi).super_method.call(3) { :bound }
  object.define_singleton_method(:hi) { |*args, &block| [:singleton, super(*args, &block)] }
  p object.hi(4) { :singleton_block }
end

module ExtendedBuiltin1102
  def length = [:wrapped, super]
end
[+"abc", [1, 2], {a: 1}].each do |object|
  object.extend(ExtendedBuiltin1102)
  p object.length
end
