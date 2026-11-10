require 'socket'
require 'io/nonblock'

def write_pair(kind)
  reader, writer = kind == :pipe ? IO.pipe : UNIXSocket.pair
  yield reader, writer
ensure
  reader.close unless reader.closed?
  begin; writer.close unless writer.closed?; rescue StandardError; IO.for_fd(writer.fileno).close rescue nil; end
end

def fill_writer(writer)
  loop do
    break if writer.write_nonblock('f' * 4096, exception: false) == :wait_writable
  end
end

def drain_writer(reader)
  total = 0
  loop do
    data = reader.read_nonblock(65536, exception: false)
    break if data == :wait_readable || data.nil?
    total += data.bytesize
  end
  total
end

[:pipe, :socket].each do |kind|
  [:write, :syswrite, :puts, :flush, :sync, :empty_syswrite].each do |operation|
    write_pair(kind) do |reader, writer|
      fill_writer(writer)
      writer.timeout = 0.005
      if [:flush, :sync].include?(operation)
        writer.sync = false
        raise 'buffered write count changed' unless writer.write('tail') == 4
        writer.sync = true if operation == :sync
      end
      begin
        case operation
        when :write then writer.write('x')
        when :syswrite then writer.syswrite('x')
        when :puts then writer.puts('x')
        when :flush then writer.flush
        when :sync then writer.flush
        when :empty_syswrite then writer.syswrite('')
        end
        raise 'blocked write ignored timeout'
      rescue IO::TimeoutError => error
        p [kind, operation, error.class, error.message, writer.closed?]
      end
      drain_writer(reader)
      writer.timeout = nil
      writer.flush
      if [:flush, :sync].include?(operation)
        raise 'flush lost pending bytes' unless reader.read(4) == 'tail'
      else
        raise 'timed-out direct write was buffered for a later flush' unless reader.read_nonblock(64, exception: false) == :wait_readable
      end
    end
  end

  write_pair(kind) do |reader, writer|
    fill_writer(writer)
    writer.sync = false
    writer.write('tail')
    writer.timeout = 0.005
    begin
      writer.close
      raise 'close lost its flush timeout'
    rescue IO::TimeoutError => error
      p [kind, :close_flush, error.class, error.message, writer.closed?]
    end
    drain_writer(reader)
    writer.timeout = nil
    writer.close
    raise 'close retry lost buffered bytes' unless reader.read == 'tail'
  end

  write_pair(kind) do |reader, writer|
    fill_writer(writer)
    writer.timeout = 0
    p [kind, :empty_write, writer.write('')]
    p [kind, :nonblock, writer.write_nonblock('x', exception: false)]
    begin
      writer.write_nonblock('x')
    rescue IO::WaitWritable => error
      p [kind, error.class]
    end
  end

  write_pair(kind) do |reader, writer|
    writer.timeout = 0.005
    begin
      writer.write('p' * 1_000_000)
      raise 'partial-progress write ignored timeout'
    rescue IO::TimeoutError => error
      count = drain_writer(reader)
      p [kind, :partial, error.class, count > 0 && count < 1_000_000]
    end
    writer.timeout = nil
    writer.write('ok')
    writer.close
    raise 'partial write retained or duplicated its unsent suffix' unless reader.read == 'ok'
  end

  write_pair(kind) do |reader, writer|
    fill_writer(writer)
    writer.timeout = 0.5
    drainer = Thread.new { sleep 0.01; drain_writer(reader) }
    raise 'ready writer failed' unless writer.write('ok') == 2
    drainer.join
    p [kind, :readiness_recovery, writer.timeout]
  end

  write_pair(kind) do |reader, writer|
    fill_writer(writer)
    writer.timeout = 1
    thread = Thread.new do
      Thread.current.report_on_exception = false
      begin
        writer.write('x')
        :unexpected
      rescue RuntimeError => error
        error.message
      end
    end
    sleep 0.01
    thread.raise(RuntimeError, 'write interrupted')
    p [kind, :interrupt, thread.value, writer.closed?]
  end
  write_pair(kind) do |reader, writer|
    fill_writer(writer)
    writer.timeout=1
    thread=Thread.new do
      Thread.current.report_on_exception=false
      begin
        writer.write('x')
        :unexpected
      rescue IOError=>error
        [error.class,error.message]
      end
    end
    sleep 0.01
    writer.close
    p [kind,:closed_waiter,thread.value]
  end

end

reader, writer = IO.pipe
begin
  p writer.send(:timeout=,0.01).equal?(writer)
  [nil,0,0.01,-0.01,Float::INFINITY,Float::NAN,1r,Complex(1,0),false,'0.01'].each do |value|
    begin
      writer.timeout = value
      p [value,writer.timeout]
    rescue Exception => error
      p [value,error.class,error.message]
    end
  end
ensure
  reader.close
  writer.close
end

# syswrite is raw and must not flush the stream's pending buffered output.
reader, writer = IO.pipe
begin
  writer.sync = false
  writer.write('buffered')
  $VERBOSE = nil
  writer.syswrite('raw')
  writer.flush
  writer.close
  p reader.read
ensure
  reader.close unless reader.closed?
  writer.close unless writer.closed?
end

class WriteInterval
  attr_reader :calls
  def initialize = (@calls=0)
  def divmod(unit)
    raise 'interval divisor' unless unit == 1
    @calls+=1
    [0, Rational(1,100)]
  end
end
reader,writer=IO.pipe
begin
  value=WriteInterval.new
  p [writer.send(:timeout=,value).equal?(writer), writer.timeout.equal?(value)]
  p [writer.write('x'),value.calls>=1]
  writer.close
  p reader.read
ensure
  reader.close unless reader.closed?
  writer.close unless writer.closed?
end

class WriteStringOverrides < String
  [:empty?,:bytesize,:b,:byteslice].each do |method|
    define_method(method) { |*| raise "write dispatched #{method}" }
  end
end
reader,writer=IO.pipe
begin
  writer.timeout=0.1
  value=WriteStringOverrides.new('abc')
  p [writer.write(value),writer.syswrite(value)]
  writer.close
  p reader.read
ensure
  reader.close unless reader.closed?
  writer.close unless writer.closed?
end

# Duplicated streams keep the original interval object and wait independently.
reader,writer=IO.pipe
duplicate=nil
begin
  value=WriteInterval.new
  writer.timeout=value
  duplicate=writer.dup
  raise 'dup changed interval identity' unless duplicate.timeout.equal?(value)
  fill_writer(writer)
  begin
    duplicate.write('x')
    raise 'duplicated writer ignored timeout'
  rescue IO::TimeoutError=>error
    p [:duplicate_write,error.class,writer.timeout.equal?(value)]
  end
  drain_writer(reader)
  duplicate.timeout=nil
  duplicate.write('ok')
  raise 'dup lost original interval' unless writer.timeout.equal?(value)
  p reader.read(2)
ensure
  duplicate.close if duplicate && !duplicate.closed?
  writer.close unless writer.closed?
  reader.close unless reader.closed?
end
