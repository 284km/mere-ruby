class ImplicitWrappedError < StandardError
  def initialize(original)
    super(original.message)
    set_backtrace(original.backtrace)
  end

  def native_values
    [message(), backtrace(), backtrace_locations(), cause(), exception().equal?(self)]
  end

  # Native inherited methods remain callable independently of this hook.
  def respond_to?(*)
    false
  end
end

source = RuntimeError.new('wrapped failure')
source.set_backtrace(['fixture.rb:12'])
wrapped = ImplicitWrappedError.new(source)
p wrapped.native_values

class OverriddenWrappedError < ImplicitWrappedError
  def set_backtrace(value)
    super(value.map { |line| 'forwarded ' + line })
  end
end
p OverriddenWrappedError.new(source).backtrace

class RemovedWrappedError < StandardError
  undef_method :set_backtrace
  def initialize
    set_backtrace(['fixture.rb:1'])
  end
end
begin
  RemovedWrappedError.new
rescue NoMethodError => error
  p error.name
end
