require "socket"
require "io/nonblock"
require "io/wait"

def with_stream(kind)
  reader, writer = kind == :pipe ? IO.pipe : UNIXSocket.pair
  yield reader, writer
ensure
  reader.close unless reader.closed?
  writer.close unless writer.closed?
end

# Cleanup must write the native String buffer without executing overrides
# that could replace the pending IO::TimeoutError with an unrelated error.
class TimeoutReplaceBuffer < String
  def replace(*) = raise('replace override was called')
end
class TimeoutOverrideBuffer < String
  [:bytesize, :encoding, :b, :byteslice, :replace, :force_encoding].each do |name|
    define_method(name) do |*|
      $timeout_buffer_calls << name
      raise "#{name} override was called"
    end
  end
end
[:pipe, :socket].each do |kind|
  [TimeoutReplaceBuffer, TimeoutOverrideBuffer].each do |klass|
    [nil, 2].each do |length|
      ['', 'old', 'long buffer'].each do |initial|
        with_stream(kind) do |reader, writer|
          $timeout_buffer_calls = []
          buffer = klass.new(initial)
          String.instance_method(:force_encoding).bind_call(buffer, Encoding::UTF_16LE)
          reader.timeout = 0.002
          writer.write('a')
          writer.flush
          begin
            reader.read(length, buffer)
            raise 'subclass-buffer read did not time out'
          rescue IO::TimeoutError => error
            bytes = String.instance_method(:bytes).bind_call(buffer)
            encoding = String.instance_method(:encoding).bind_call(buffer)
            p [kind, length, initial, error.class, error.message, bytes, encoding, $timeout_buffer_calls]
          end
          writer.write('tail')
          writer.close
          p reader.read
        end
      end
    end
  end
end

[:pipe, :socket].each do |kind|
  with_stream(kind) do |reader, writer|
    p [kind, reader.timeout, writer.timeout]
    reader.timeout = 0.0001
    copy = reader.dup
    begin
      p [reader.timeout, copy.timeout, writer.timeout]
      copy.timeout = 0.02
      p [reader.timeout, copy.timeout]
    ensure
      copy.close
    end
    reader.timeout = nil
    p reader.timeout
  end

  [[:read], [:read, 1], [:gets], [:getc], [:getbyte]].each do |call|
    with_stream(kind) do |reader, writer|
      reader.timeout = 0.002
      begin
        reader.public_send(*call)
        p :unexpected_success
      rescue IO::TimeoutError => error
        p [kind, call, error.class, error.message]
      end
      # Timing out leaves the stream usable, including after clearing timeout.
      reader.timeout = nil
      writer.write("ok")
      writer.flush
      p reader.read(2)
    end
  end

  [[:readpartial, 1], [:sysread, 1]].each do |call|
    with_stream(kind) do |reader, writer|
      reader.timeout = 0
      sender = Thread.new do
        sleep 0.02
        writer.write("z")
        writer.flush
      end
      begin
        p [call, reader.public_send(*call)]
      ensure
        sender.join
      end
    end
  end

  with_stream(kind) do |reader, writer|
    reader.timeout = 0.002
    p reader.read_nonblock(1, exception: false)
    p reader.wait_readable
    p reader.wait_readable(0)
    writer.write("line\n")
    writer.flush
    p reader.wait_readable.equal?(reader)
    p reader.gets
    writer.close
    p [reader.read, reader.read(1)]
  end

  with_stream(kind) do |reader, writer|
    # A logical blocking mode must still honor the stream timeout.
    reader.nonblock = false
    reader.timeout = 0.002
    begin
      reader.read(1)
    rescue IO::TimeoutError => error
      p [error.class, reader.nonblock?]
    end
  end

  with_stream(kind) do |reader, writer|
    reader.timeout = 0
    writer.write("x")
    writer.flush
    p reader.read(1)
    begin
      reader.read(1)
    rescue IO::TimeoutError => error
      p error.class
    end
  end
end

server = TCPServer.new("127.0.0.1", 0)
begin
  server.timeout = 0.002
  begin
    server.accept
  rescue IO::TimeoutError => error
    p error.class
  end
ensure
  server.close
end

# A timed-out operation owns the prefix it already read; recovery starts
# after that prefix, including when it came from previous read-ahead.
[:pipe, :socket].each do |kind|
  [[:read], [:read, 4], [:gets], [:readline], [:gets, nil], [:gets, "END"]].each do |call|
    [false, true].each do |prefetched|
      with_stream(kind) do |reader, writer|
        reader.timeout = 0.002
        writer.write(prefetched ? "first\na" : "a")
        writer.flush
        p reader.gets if prefetched
        begin
          reader.public_send(*call)
          raise "partial read did not time out"
        rescue IO::TimeoutError
          p [kind, call, prefetched, :timed_out]
        end
        writer.write("b\nrest")
        writer.close
        p [reader.gets, reader.read]
      end
    end
  end
  [nil, 10].each do |length|
    ["", "X", "OLD", "long buffer"].each do |initial|
      ["", "a", "abcd"].each do |prefix|
        with_stream(kind) do |reader, writer|
          reader.timeout = 0.002
          buffer = initial.dup.force_encoding("UTF-16LE")
          writer.write(prefix)
          writer.flush
          begin
            reader.read(length, buffer)
            raise "buffered partial read did not time out"
          rescue IO::TimeoutError
            p [kind, length, initial, prefix, buffer.bytes, buffer.encoding]
          end
          writer.write("tail")
          writer.close
          p reader.read
        end
      end
    end
  end
end

# A partial multibyte character belongs to the failed read too.
[:pipe, :socket].each do |kind|
  [[:gets, 1], [:getc], [:readchar]].each do |call|
    with_stream(kind) do |reader, writer|
      reader.timeout = 0.002
      reader.set_encoding('UTF-8')
      writer.write("\xc3".b)
      writer.flush
      begin
        reader.public_send(*call)
        raise "partial character did not time out"
      rescue IO::TimeoutError
        p [kind, call, :timed_out]
      end
      writer.write("Z\n")
      writer.close
      p reader.read.bytes
    end
  end
end
