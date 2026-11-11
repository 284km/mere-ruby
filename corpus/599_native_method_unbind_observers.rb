class UnbindTarget
  def marker; :marker; end
end
bound = UnbindTarget.new.method(:marker)
bound.freeze
first = bound.unbind
second = bound.unbind
p [first.class, first.frozen?, first.equal?(second), first.bind_call(bound.receiver)]
begin
  bound.unbind(1)
rescue ArgumentError
  puts :arity_checked
end

Method.send(:private, :unbind)
begin
  bound.unbind
rescue NoMethodError
  puts :private_unbind
end
Method.class_eval do
  def method_missing(name, *arguments)
    return :private_missing if name == :unbind
    super
  end
end
p bound.unbind
Method.send(:remove_method, :method_missing)
p bound.send(:unbind).class
Method.send(:public, :unbind)
p bound.unbind.class

events = []
trace = TracePoint.new(:c_call, :c_return) do |event|
  events << event.event if event.method_id == :unbind
end
trace.enable { bound.unbind }
p events

wrapper = Module.new do
  def unbind
    :override
  end
end
Method.prepend(wrapper)
p bound.unbind
