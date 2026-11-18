module MainFoundation
  def work(value, flag: false, &block)
    [value, flag, block && block.call(value)]
  end
end
module MainWrapper
  include MainFoundation
  def work(value, **options, &block)
    super(value, flag: true, **options, &block)
  end
end
module MainAPI
  include MainWrapper
  private :work
end
extend MainAPI

value = work(:argument) { |item| [:block, item] }
p value
p work(:overridden, flag: false)

module MainPrefix
  def work(*args, **options, &block)
    [:prefix, super]
  end
end
singleton_class.prepend MainPrefix
p work(:prepended)

def global_work
  :object_method
end
module MainGlobalWrapper
  def global_work
    [:wrapper, super]
  end
end
extend MainGlobalWrapper
p global_work

module MainStop
  include MainFoundation
  undef_method :work
end
extend MainStop
begin
  work(:blocked)
rescue => error
  p error.class
end
