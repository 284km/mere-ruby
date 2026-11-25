h = {a: 1, b: 'x'}
p((h in {a: Integer => a}))
p((h in {a:, **rest}))
p [a, rest]
class Hash
  alias_method :saved_pattern_read1024, :[]
  def [](key)
    $reads1024 << key
    saved_pattern_read1024(key)
  end
end
$reads1024 = []
p((h in {a:, b:}))
p $reads1024
class Hash
  alias_method :[], :saved_pattern_read1024
end
h.define_singleton_method(:key?) { |key| false }
p((h in {a:}))
