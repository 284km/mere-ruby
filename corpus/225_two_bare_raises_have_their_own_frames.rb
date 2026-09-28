# Two bare `raise`s build the same cheap exception -- a RuntimeError with the
# message "unhandled exception" -- and the Locations #backtrace_locations
# builds were cached beside that VALUE, so the second raise answered the
# first one's frames. Each raise retires the cache now.
def first_raise
  begin
    raise
  rescue RuntimeError => e
    e.backtrace_locations.first.lineno
  end
end
p first_raise
second = begin
  raise
rescue RuntimeError
  $!
end
p second.backtrace_locations.first.lineno
p second.backtrace_locations.equal?(second.backtrace_locations)
3.times do |i|
  begin
    raise "same"
  rescue => e
    p [i, e.backtrace_locations.first.lineno]
  end
end
