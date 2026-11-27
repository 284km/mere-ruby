module MissingClaims
  def respond_to_missing?(name, include_private = false)
    (@claims ||= []) << [name, include_private]
    name == :virtual || super
  end

  def claims
    @claims || []
  end
end

class ClaimedHash < Hash
  include MissingClaims
end

class ClaimedString < String
  include MissingClaims
end

class ClaimedArray < Array
  include MissingClaims
end

[ClaimedHash.new, ClaimedString.new, ClaimedArray.new].each do |value|
  p [value.class.name, defined?(value.virtual), defined?(value.absent), value.claims]
end

[{}, "", []].each do |value|
  value.extend(MissingClaims)
  p [:singleton, value.class.name, defined?(value.virtual), value.claims]
end

class HiddenClaim < ClaimedHash
  private
  def virtual
    :hidden
  end
end
value = HiddenClaim.new
p [:private, defined?(value.virtual), value.claims]

class SuppressedClaim < ClaimedHash
  def respond_to?(name, include_private = false)
    name != :respond_to_missing? && super
  end
end
value = SuppressedClaim.new
p [:suppressed, defined?(value.virtual), value.claims]

class OneArgumentClaim < ClaimedHash
  def respond_to?(name)
    name == :respond_to_missing?
  end
end
value = OneArgumentClaim.new
p [:one_argument, defined?(value.virtual), value.claims]

class RealClaim < ClaimedHash
  def virtual
    :real
  end
end
value = RealClaim.new
p [:real, defined?(value.virtual), value.claims]

value = ClaimedHash.new
def value.virtual
  :real_singleton
end
p [:real_singleton, defined?(value.virtual), value.claims]

p [:ordinary, defined?({}.absent), defined?("".absent), defined?([].absent)]
