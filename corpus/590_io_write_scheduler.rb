Warning[:experimental]=false
class WriteSchedulerProbe
  attr_reader :calls
  def initialize(mode)
    @mode=mode
    @calls=[]
    @attempts=0
  end
  def block(*) = nil
  def unblock(*) = nil
  def kernel_sleep(*) = nil
  def io_wait(io,events,timeout)
    @calls << [:wait,events,timeout]
    case @mode
    when :false then false
    when :nil then nil
    when :zero then 0
    else IO::WRITABLE
    end
  end
  def io_write(io,buffer,minimum,offset)
    @calls << [:write,minimum,offset,buffer.size]
    @attempts+=1
    return -Errno::EAGAIN::Errno if @mode!=:success && @attempts==1
    buffer.size
  end
  def fiber_interrupt(*) = nil
  def scheduler_close = nil
end
[:success,:retry,:false,:nil,:zero].each do |mode|
  reader,writer=IO.pipe
  scheduler=WriteSchedulerProbe.new(mode)
  Fiber.set_scheduler(scheduler)
  begin
    result=nil
    Fiber.new(blocking:false) do
      writer.timeout=0.02
      begin
        result=[mode,writer.write('abc')]
      rescue=>error
        result=[mode,error.class,error.message]
      end
    end.resume
    p result
    p scheduler.calls
  ensure
    Fiber.set_scheduler(nil)
    reader.close
    writer.close
  end
end
