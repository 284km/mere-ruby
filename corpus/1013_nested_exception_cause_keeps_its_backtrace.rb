def first_error1013
  raise 'first'
end
def second_error1013
  first_error1013
rescue
  raise 'second'
end
def third_error1013
  second_error1013
rescue
  raise 'third'
end
begin
  third_error1013
rescue => error
  causes = []
  while error
    locations = error.backtrace_locations
    p [error.message, locations&.first&.base_label&.split('#')&.last,
       error.backtrace&.length == locations&.length]
    p error.cause.equal?(error.cause)
    causes << error
    error = error.cause
  end
  p causes.map { |e| e.backtrace_locations.first.base_label.split('#').last }
end
begin
  first_error1013
rescue => first
  begin
    raise 'next'
  rescue => second
    p second.cause.equal?(first)
    p second.cause.backtrace == first.backtrace
  end
end

class BareRescueWrapper1013 < StandardError
  attr_reader :cause
  def initialize
    super($!.message)
    @cause = $!
  end
  def backtrace
    @cause.backtrace
  end
end

wrapped = begin
  raise
rescue
  raise BareRescueWrapper1013.new rescue $!
end
p [:bare_custom_cause, !wrapped.backtrace.nil?,
   wrapped.backtrace == wrapped.cause.backtrace,
   wrapped.cause.backtrace_locations.is_a?(Array)]

outer = begin
  raise 'outer1013'
rescue
  saved = $!
  begin
    raise 'inner1013'
  rescue
  end
  p [:bare_current_identity, saved.equal?($!)]
  saved
end
p [:bare_retained_trace, outer.message, !outer.backtrace.nil?,
   outer.backtrace_locations.is_a?(Array)]
