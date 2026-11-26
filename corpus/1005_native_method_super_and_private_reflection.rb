class MethodOverride1005
  def method(*args)
    super
  end

  def public_method(*args)
    super
  end

  def public_value; :public; end
  private def hidden_value; :private; end
end
object = MethodOverride1005.new
p [object.method(:public_value).call, object.method(:hidden_value).call]
p object.public_method(:public_value).call
begin
  object.public_method(:hidden_value)
rescue NameError => error
  p error.class
end
[[], [:public_value, :extra]].each do |args|
  begin
    object.method(*args)
  rescue ArgumentError => error
    p [error.class, error.message]
  end
end
[:method_missing, :singleton_method_added, :respond_to_missing?].each do |name|
  p [name, object.respond_to?(name), object.respond_to?(name, true)]
end
class NoMissing1005
  undef_method :method_missing
end
p NoMissing1005.new.respond_to?(:method_missing, true)
[Exception, SyntaxError, SystemCallError, SignalException, Interrupt].each do |klass|
  p [klass.name, klass.public_instance_methods.include?(:initialize),
     klass.private_instance_methods.include?(:initialize)]
end
require 'delegate'
class ErrorDelegate1005 < DelegateClass(SyntaxError); end
error = SyntaxError.new('original message')
p ErrorDelegate1005.new(error).message
