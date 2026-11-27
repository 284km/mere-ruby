Thread.report_on_exception = false
class QueuedA1135 < StandardError; end
class QueuedB1135 < StandardError; end

ready, resume = Queue.new, Queue.new
seen, pending = [], []
worker = Thread.new do
  Thread.handle_interrupt(Exception => :never) do
    ready << true
    resume.pop
    2.times do
      begin
        Thread.handle_interrupt(Exception => :immediate) {}
      rescue StandardError => error
        seen << error.message
        pending << Thread.pending_interrupt?
      end
    end
  end
end
ready.pop
worker.raise(QueuedA1135.new("first"))
worker.raise(QueuedB1135.new("second"))
resume << true
raise "FIFO worker timed out" unless worker.join(10)
p [:fifo, seen, pending, worker.pending_interrupt?]

ready, resume = Queue.new, Queue.new
seen = []
worker = Thread.new do
  begin
    Thread.handle_interrupt(StandardError => :never) do
      ready << true
      resume.pop
    end
  rescue StandardError
    seen << :rescued_pending_exception
  end
end
ready.pop
worker.raise(StandardError.new("pending"))
worker.kill
joined = !worker.join(2).nil?
unless joined
  resume << true
  raise "kill worker cleanup timed out" unless worker.join(10)
end
p [:kill_after_pending, joined, seen]

ready, resume = Queue.new, Queue.new
first, second, states = [], [], []
worker = Thread.new do
  Thread.handle_interrupt(Exception => :never) do
    ready << true
    resume.pop
    while Thread.pending_interrupt?(QueuedB1135)
      begin
        Thread.handle_interrupt(QueuedA1135 => :never, QueuedB1135 => :immediate) {}
      rescue QueuedB1135 => error
        GC.start if second.size % 13 == 0
        second << error.message
      end
    end
    states << [Thread.pending_interrupt?(QueuedA1135), Thread.pending_interrupt?(QueuedB1135)]
    while Thread.pending_interrupt?(QueuedA1135)
      begin
        Thread.handle_interrupt(QueuedA1135 => :immediate) {}
      rescue QueuedA1135 => error
        GC.start if first.size % 13 == 0
        first << error.message
      end
    end
  end
end
ready.pop
40.times do |index|
  worker.raise(QueuedA1135.new("a#{index}"))
  worker.raise(QueuedB1135.new("b#{index}"))
end
resume << true
raise "masked queue worker timed out" unless worker.join(10)
p [:masked_order_and_gc, second, first, states, worker.pending_interrupt?]

ready, resume = Queue.new, Queue.new
worker = Thread.new do
  Thread.handle_interrupt(Exception => :never) do
    ready << true
    resume.pop
  end
end
ready.pop
worker.raise(QueuedA1135.new("unhandled first"))
worker.raise(QueuedB1135.new("still pending"))
resume << true
begin
  worker.join
rescue StandardError => error
  p [:finished_exception, error.message]
end
p [:finished_pending, worker.pending_interrupt?, worker.pending_interrupt?(QueuedB1135)]
