class NativeResponseAlias
  alias original_respond_to? respond_to?
  def respond_to?(*args)
    :ruby_override
  end
  def visible = :yes
  protected
  def protected_value = :protected
  private
  def hidden = :no
end

object = NativeResponseAlias.new
p object.respond_to?(:visible)
p [object.original_respond_to?(:visible), object.original_respond_to?('hidden'),
   object.original_respond_to?(:hidden, true), object.original_respond_to?(:protected_value),
   object.original_respond_to?(:protected_value, Object.new)]

class NativeResponseAlias
  def respond_to_missing?(name, include_private)
    return include_private if name == :dynamic_private
    name == :dynamic
  end
end
p [object.original_respond_to?(:dynamic), object.original_respond_to?(:dynamic_private),
   object.original_respond_to?(:dynamic_private, true), object.original_respond_to?(:absent)]

name = Object.new
def name.to_str = 'visible'
p object.original_respond_to?(name)

[[], [:visible, true, :extra], [123]].each do |args|
  begin
    object.original_respond_to?(*args)
  rescue ArgumentError, TypeError => error
    p [error.class, error.message]
  end
end

class ResponseChild < NativeResponseAlias
  def visible = :child
end
p ResponseChild.new.original_respond_to?(:visible)

class << object
  def singleton_value = :singleton
end
p [object.original_respond_to?(:singleton_value), object.original_respond_to?(:visible)]
