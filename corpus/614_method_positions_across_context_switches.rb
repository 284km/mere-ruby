klass = Class.new do
  def pause_position
    first = caller(0, 1).first.include?('pause_position')
    Fiber.yield :paused
    GC.start
    [first, caller(0, 1).first.include?('pause_position')]
  end

  def thread_position(tag, events)
    GC.start
    events << [tag, 1, caller(0, 1).first.include?('thread_position')]
    Thread.pass
    GC.start
    events << [tag, 2, caller(0, 1).first.include?('thread_position')]
  end
end

first = Fiber.new { klass.new.pause_position }
second = Fiber.new { klass.new.pause_position }
p [first.resume, second.resume]
5.times { GC.start }
p second.resume
5.times { GC.start }
p first.resume

events = []
threads = ['first', 'second'].map do |tag|
  Thread.new { klass.new.thread_position(tag, events) }
end
threads.each(&:join)
p events.sort

# Neither terminated context can leave its method name in the main context.
begin
  raise 'main context restored'
rescue RuntimeError => error
  p error.backtrace.first.include?("in '<main>'")
end
