class EqualityProxy944
  undef_method :==
  undef_method :!=
  def respond_to?(name, *flags) = name == :to_str || super
  def method_missing(name, *args)
    return args[0] == "abc" if name == :==
    return args[0] != "abc" if name == :!=
    super
  end
end
class EqualityModule944 < Module
  undef_method :==
  undef_method :!=
  def respond_to?(name, *flags) = name == :to_str || super
  def method_missing(name, *args)
    return args[0] == "abc" if name == :==
    return args[0] != "abc" if name == :!=
    super
  end
end
[EqualityProxy944.new, EqualityModule944.new].each do |proxy|
  p [proxy.__send__(:==, "abc"), proxy.__send__(:!=, "abc")]
  p ["abc" == proxy, "abc" != proxy, "other" == proxy]
end
class MissingIdentity944
  undef_method :==
  undef_method :!=
end
[:==, :!=].each do |operation|
  begin
    MissingIdentity944.new.public_send(operation, 1)
  rescue NoMethodError => error
    p [error.class, error.name]
  end
end
