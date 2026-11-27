class Module
  alias saved_reader_1107 attr_reader
end
module AttrWrapper1107
  def attr_reader(...) = super
  def attr_writer(...) = super
  def attr_accessor(...) = super
  def attr(...) = super
end
Module.prepend(AttrWrapper1107)

def report_attr_1107(method)
  klass = Class.new
  klass.send(method, :value)
  object = klass.new
  object.instance_variable_set(:@value, 7)
  p [method, object.respond_to?(:value), object.respond_to?(:value=)]
rescue NoMethodError => error
  p [method, error.class, error.name]
end
[:attr_reader, :attr_writer, :attr_accessor, :attr].each { |method| report_attr_1107(method) }

# A definition in Module replaces its native entry. Super from that body
# starts after Module and must not rediscover the overwritten builtin.
class Module
  def attr_reader(...) = super
  def attr_writer(...) = super
  def attr_accessor(...) = super
  def attr(...) = super
end
[:attr_reader, :attr_writer, :attr_accessor, :attr].each { |method| report_attr_1107(method) }

# A retained alias still owns the original native implementation.
class SavedReader1107
  saved_reader_1107 :value
end
object = SavedReader1107.new
object.instance_variable_set(:@value, 9)
p object.value
