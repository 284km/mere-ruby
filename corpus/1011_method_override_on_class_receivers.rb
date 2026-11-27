module MethodDSL1011
  def method(name, *args)
    [:expression, name, args]
  end
  def contains(*args)
    method(:contains, *args)
  end
end
class MethodReceiver1011
  extend MethodDSL1011
end
p MethodReceiver1011.contains('a')
p MethodReceiver1011.method(:contains, 'a', 'b')
class MethodArray1011 < Array
  include MethodDSL1011
end
p MethodArray1011.new.contains('a')
class NativeMethodReceiver1011
  def self.contains(*args) = args
  def self.method(name, *args)
    return super(name) if args.empty?
    [:override, name, args]
  end
end
p NativeMethodReceiver1011.method(:contains, 'a')
p NativeMethodReceiver1011.method(:contains).call('a')
