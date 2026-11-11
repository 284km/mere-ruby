holder = Class.new do
  def build
    :built
  end
  protected :build
  alias new build
end
value = holder.new
p holder.protected_method_defined?(:new)
p value.send(:new)
begin
  value.new
  raise 'protected instance method became public'
rescue NoMethodError => error
  p [error.name, error.receiver.equal?(value)]
end

parent = Class.new do
  def new
    :value
  end
end
object = parent.new
3.times { object.new }
parent.send(:protected, :new)
child = Class.new(parent)
p [parent.protected_method_defined?(:new), child.protected_method_defined?(:new)]
p object.send(:new)
p child.new.send(:new)
child.send(:public, :new)
GC.start
p [parent.protected_method_defined?(:new), child.public_method_defined?(:new)]
p child.new.new
copy = parent.dup
p copy.protected_method_defined?(:new)
p copy.new.send(:new)
