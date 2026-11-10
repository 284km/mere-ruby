if defined?($visibility_wrapped) && $visibility_wrapped
  $visibility_wrapper = Module.nesting.first
  def wrapped_hidden
    :hidden
  end
else
  klass = Class.new do
    private
    define_method(:hidden) { :hidden }
    eval('def from_eval; :eval; end')
    1.times do
      private
      define_method(:nested_hidden) { :nested }
    end
    public
    define_method(:visible) { :visible }
  end
  4.times { GC.start }
  raise unless klass.private_instance_methods(false).include?(:hidden)
  raise unless klass.private_instance_methods(false).include?(:from_eval)
  raise unless klass.private_instance_methods(false).include?(:nested_hidden)
  raise unless klass.public_instance_methods(false).include?(:visible)
  raise unless klass.new.send(:hidden) == :hidden
  klass.class_eval do
    public
    define_method(:later) { :later }
  end
  raise unless klass.new.later == :later
  raise unless klass.private_instance_methods(false).include?(:hidden)

  $visibility_wrapped = true
  load __FILE__, true
  $visibility_wrapped = false
  4.times { GC.start }
  raise unless $visibility_wrapper.private_instance_methods(false).include?(:wrapped_hidden)
  puts 'class visibility scopes preserved'
end
