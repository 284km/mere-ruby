# Construction keeps the shared class-body semantics and the ordinary frame.
outer = :outer
klass = Class.new do |created|
  raise unless self.equal?(created)
  define_method(:value) { outer }
  private
  def hidden; :hidden; end
end
raise unless klass.new.value == :outer
raise unless klass.private_instance_methods(false).include?(:hidden)
mod = Module.new do |created|
  raise unless self.equal?(created)
  def value; :module_value; end
  module_function :value
end
raise unless mod.value == :module_value
raise unless Class.new { break :class_break } == :class_break
raise unless Module.new { break :module_break } == :module_break

def constructor_return
  Class.new { return :returned }
  :unreachable
end
raise unless constructor_return == :returned
raise unless Class.new(&->(_created) { return :lambda_return }).is_a?(Class)
raise unless Class.new(&->(_created) { break :lambda_break }).is_a?(Class)
raise unless Module.new(&->(_created) { return :lambda_return }).is_a?(Module)
raise unless Module.new(&->(_created) { break :lambda_break }).is_a?(Module)
def expired_constructor_block
  proc { return :expired }
end
expired = expired_constructor_block
begin
  Class.new(&expired)
  raise 'expected LocalJumpError'
rescue LocalJumpError => error
  raise unless error.reason == :return && error.exit_value == :expired
end
# Inspect from level zero so the test checks the constructor frame itself.
frames = Class.new { break caller_locations(0).map(&:base_label) }
raise unless frames.include?('new')
raised = nil
begin
  Class.new { raise 'constructor body' }
rescue RuntimeError => error
  raised = error.message
end
raise unless raised == 'constructor body'
# An overridden constructor receives its block through ordinary dispatch.
class << Class
  def new(&block)
    block.call(:override_argument)
    :override_result
  end
end
raise unless Class.new { |value| raise unless value == :override_argument } == :override_result
class << Class
  remove_method :new
end
raise unless Class.new { def value; :restored; end }.new.value == :restored
puts 'core class block dispatch preserves body, flow, frames, and overrides'
