# Thread.handle_interrupt and Thread#pending_interrupt?. A Thread#raise from
# another thread is an interrupt its target has not seen yet: it waits while a
# :never mask (or an :on_blocking one, away from a blocking call) holds it
# back, and is delivered when the mask allows -- at the end of the block, even
# if the block raised its own exception, and the interrupt is what propagates.
p Thread.pending_interrupt?, Thread.current.pending_interrupt?
begin
  Thread.handle_interrupt(RuntimeError => :never) do
    main = Thread.current
    Thread.new { main.raise "deferred" }.join
    p Thread.pending_interrupt?, Thread.pending_interrupt?(RuntimeError), Thread.pending_interrupt?(IOError)
    p :block_finished
  end
rescue => e
  p [:after_the_block, e.message]
end
p Thread.pending_interrupt?, Thread.main.status
Thread.handle_interrupt(RuntimeError => :never) do
  main = Thread.current
  Thread.new { main.raise "waiting" }.join
  begin
    Thread.handle_interrupt(RuntimeError => :immediate) { p :not_run }
  rescue => e
    p [:immediate, e.message]
  end
  p Thread.pending_interrupt?
end
begin
  Thread.handle_interrupt(StandardError => :on_blocking) do
    main = Thread.current
    Thread.new { main.raise ArgumentError, "wins" }.join
    raise "the block's own"
  end
rescue => e
  p [e.class, e.message]
end
[{ RuntimeError => :sometimes }, nil].each do |mask|
  begin
    mask ? Thread.handle_interrupt(mask) { } : Thread.handle_interrupt(RuntimeError => :never)
  rescue ArgumentError => e
    p e.message
  end
end
