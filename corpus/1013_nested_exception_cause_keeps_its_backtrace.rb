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
