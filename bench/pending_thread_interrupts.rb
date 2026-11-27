mode, count = ARGV.fetch(0), Integer(ARGV.fetch(1))
srand(Integer(ARGV.fetch(2).split("=").last))
Thread.report_on_exception = false
handled = 0
case mode
when "plain"
  count.times { handled += 1 }
when "single"
  ready, resume = Queue.new, Queue.new
  worker = Thread.new do
    Thread.handle_interrupt(Exception => :never) do
      count.times do
        ready << true
        resume.pop
        begin
          Thread.handle_interrupt(Exception => :immediate) {}
        rescue StandardError
          handled += 1
        end
      end
    end
  end
  count.times do
    ready.pop
    worker.raise(StandardError.new("pending"))
    resume << true
  end
  worker.join
when "burst"
  ready, resume = Queue.new, Queue.new
  worker = Thread.new do
    Thread.handle_interrupt(Exception => :never) do
      ready << true
      resume.pop
      while Thread.pending_interrupt?
        begin
          Thread.handle_interrupt(Exception => :immediate) {}
        rescue StandardError
          handled += 1
        end
      end
    end
  end
  ready.pop
  count.times { |index| worker.raise(StandardError.new(index.to_s)) }
  resume << true
  worker.join
else
  raise "unknown mode"
end
p [mode, count, handled]
