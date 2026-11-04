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

# A handled failure in thread_end must not reuse the worker's pending error.
Thread.report_on_exception = false
observed = []
hook = TracePoint.new(:thread_end) do
  observed << $!
  begin
    Integer('invalid callback input')
  rescue ArgumentError => error
    observed << [error.class, error.cause]
  end
  GC.start
end
hook.enable
[:missing, :argument, :explicit, :exit].each do |kind|
  worker_line = nil
  worker = Thread.new do
    case kind
    when :missing
      worker_line = __LINE__ + 1
      nil.original_worker_failure
    when :argument
      worker_line = __LINE__ + 1
      Integer('invalid worker input')
    when :explicit
      worker_line = __LINE__ + 1
      raise 'original worker failure'
    when :exit then Thread.exit
    end
  end
  begin
    worker.join
    p [kind, worker.status]
  rescue StandardError => error
    p [kind, error.class, error.cause, error.backtrace.any? { |frame| frame.include?(":#{worker_line}:") }]
    p error.name if NoMethodError === error
    p error.message.include?('invalid worker input') if ArgumentError === error
  end
end
hook.disable
p observed

# Reporting invokes user code too; its handled errors leave join's error intact.
class ThreadReportSink
  attr_reader :text
  def initialize; @text = ''; end
  def write(text)
    begin
      Integer('invalid report input')
    rescue ArgumentError
      @text << text
    end
    text.bytesize
  end
end
original_stderr = $stderr
sink = ThreadReportSink.new
$stderr = sink
begin
  worker = Thread.new do
    Thread.current.report_on_exception = true
    Integer('original report failure')
  end
  begin
    worker.join
  rescue ArgumentError => error
    p [error.message.include?('original report failure'), error.cause.nil?,
       sink.text.include?('original report failure'), sink.text.include?('ArgumentError')]
  end
ensure
  $stderr = original_stderr
end
