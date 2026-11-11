class EmptyBindingBase
  def passthrough(*args)
    args
  end
end
class EmptyBindingProtocol < EmptyBindingBase
  def zero
    [block_given?, (yield if block_given?)]
  end
  def defaulted(value = zero)
    [value, __method__]
  end
  def capture(&block)
    block
  end
  def bounce
    yield
  end
  def forward(&block)
    bounce(&block)
    :after
  end
  ruby2_keywords def relay(*args, &block)
    zero(*args, &block)
  end
  def passthrough
    super
  end
  def locals
    marker = :local
    [marker, binding.local_variables.sort]
  end
end
object = EmptyBindingProtocol.new
p object.zero
p object.zero { :literal }
block = proc { :forwarded }
p object.zero(&block)
p object.capture { :fresh }.call
p object.defaulted
p object.defaulted(:given)
p object.zero(**{})
p object.relay(**{})
[:positional, :keyword].each do |kind|
  begin
    kind == :positional ? object.zero(1) : object.relay(flag: true)
  rescue ArgumentError => error
    p [kind, error.class]
  end
end
p(object.forward { break :escaped })
p object.forward(&-> { break :lambda })
p object.method(:zero).unbind.bind_call(object)
p object.passthrough
p object.passthrough(**{})
p object.locals
p object.method(:zero).parameters
