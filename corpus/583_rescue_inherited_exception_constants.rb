module InheritedRescueErrors
  class Unauthorized < StandardError; end
end

class InheritedRescueContainer
  include InheritedRescueErrors
end

begin
  raise InheritedRescueErrors::Unauthorized, 'denied'
rescue ::InheritedRescueContainer::Unauthorized => error
  p [error.class.name, error.message]
end

RescueAlias = InheritedRescueErrors::Unauthorized
begin
  raise RescueAlias
rescue RescueAlias
  puts 'alias caught'
end

module InheritedRescueMatcher
  def self.===(value)
    value.is_a?(InheritedRescueErrors::Unauthorized)
  end
end
begin
  raise InheritedRescueErrors::Unauthorized
rescue InheritedRescueMatcher
  puts 'module matcher caught'
end
