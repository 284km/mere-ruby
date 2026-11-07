class ArgumentMarkerGC
  def first(value)
    value
  end

  def second(value)
    value
  end

  def churn
    10_000.times do |i|
      first(i)
      second(i)
    end
    GC.start
    :kept
  end

  def inner(value = churn)
    value
  end

  def outer(value = inner, rest = raise(ArgumentError, "default failure"))
    [value, rest]
  end

  def keyword(value: inner, rest: raise(ArgumentError, "keyword failure"))
    [value, rest]
  end

  def lambda_default(value = inner, rest = ->(required) { required }.call)
    [value, rest]
  end
end
probe = ArgumentMarkerGC.new
p probe.inner
[:outer, :keyword, :lambda_default].each do |method|
  begin
    probe.public_send(method)
  rescue ArgumentError => error
    p [error.class, error.message]
    # Verify the callee labels without making line-number formatting the target.
    p error.backtrace.first(2).map { |line| line.split(":in ").last } unless method == :lambda_default
  end
end
