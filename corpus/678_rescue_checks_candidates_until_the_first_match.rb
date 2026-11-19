[[ArgumentError, /bad/], [/bad/, ArgumentError], [NameError, /bad/], [], nil, ArgumentError, 3].each do |candidates|
  begin
    begin
      raise ArgumentError, 'bad'
    rescue *candidates
      p :caught
    end
  rescue => error
    p [error.class, error.message]
  end
end

def candidate(events, value)
  events << value.inspect
  value
end
events = []
begin
  raise ArgumentError
rescue candidate(events, ArgumentError), candidate(events, /bad/)
  p [:expressions, events]
end
begin
  raise ArgumentError
rescue ArgumentError, UndefinedLaterRescueCandidate
  p :later_constant_unread
end

class RescueCandidates
  def initialize(values)
    @values = values
  end
  def to_a
    @values
  end
end
begin
  raise ArgumentError
rescue *RescueCandidates.new([ArgumentError, /bad/])
  p :converted
end
module RescueMatcher
  def self.===(exception)
    p [:matching, exception.class]
    true
  end
end
begin
  raise ArgumentError
rescue RescueMatcher, candidate(events, /bad/)
  p :module_match
end
begin
  begin
    raise ArgumentError
  rescue *RescueCandidates.new([NameError, /bad/])
    p :unexpected
  end
rescue => error
  p [error.class, error.message]
end
