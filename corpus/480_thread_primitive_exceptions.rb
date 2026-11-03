# join keeps the original primitive exception, its receiver/name and frames.
thread = Thread.new do
  Thread.current.report_on_exception = false
  nil.no_such_thread_method
end
begin
  thread.join
rescue NoMethodError => error
  p [error.class, error.name, error.receiver]
  p error.backtrace.any? { |frame| frame.include?('block in <main>') }
end
p thread.status
thread = Thread.new do
  Thread.current.report_on_exception = false
  Integer('not an integer')
end
begin
  thread.value
rescue ArgumentError => error
  p [error.class, error.message]
end
p Thread.new { Thread.exit }.join.status
