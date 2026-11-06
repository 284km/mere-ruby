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
