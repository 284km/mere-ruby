class RequiredValues
  def require(key)
    return key.map { |entry| require(entry) } if key.is_a?(Array)
    [:required, key]
  end

  def statement(key)
    require key
  end

  def parenthesized(key)
    require(key)
  end
end
value = RequiredValues.new
p value.require([:first, :second])
p value.statement(:symbol)
p value.parenthesized([false, nil, 7])

class RelativeRequiredValues
  def require_relative(value)
    [:relative, value]
  end

  def call(value)
    require_relative(value)
  end
end
p RelativeRequiredValues.new.call(:symbol)
begin
  require :not_a_path
rescue TypeError => error
  p [error.class, error.message]
end
