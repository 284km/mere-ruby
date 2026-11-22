class Response
  def self.[](*args)
    [:parent, args.reverse]
  end
end

class MockResponse < Response
  class << self
    alias [] new
    alias build new
  end

  attr_reader :args
  def initialize(*args)
    @args = args
  end
end

p Response[1, 2, 3]
p MockResponse[1, 2, 3].args
p MockResponse.build(:first, :second).args

class MethodAlias < Response
  singleton_class.send(:alias_method, :[], :new)
  attr_reader :value
  def initialize(value)
    @value = value
  end
end
p MethodAlias[:value].value

# A Ruby definition at the front of the chain still precedes a builtin alias.
class CustomResponse < MockResponse
  def self.[](*args)
    [:custom, args]
  end
end
p CustomResponse[:ok]
