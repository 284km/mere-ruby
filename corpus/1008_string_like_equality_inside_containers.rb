class StringLike1008
  attr_reader :calls
  def initialize
    @calls = []
  end
  def to_str
    raise 'String#== must ask == without converting the object'
  end
  def ==(other)
    @calls << other
    other == 'token'
  end
end
value = StringLike1008.new
p ['token'] == [value]
p ['different'] == [value]
p ['token'].include?(value)
p ['token'].index(value)
p({key: 'token'} == {key: value})
p({key: 'token'}.eql?({key: value}))
p [['token']] == [[value]]
p value.calls
