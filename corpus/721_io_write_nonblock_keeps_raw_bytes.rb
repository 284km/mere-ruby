# Nonblocking writes use the supplied bytes, without stream conversion or
# dispatching String#b. A busy pipe may retry the same large String many times.
reader, writer = IO.pipe
begin
  writer.set_encoding(Encoding::UTF_16LE)
  text = "é!"
  written = writer.write_nonblock(text)
  writer.close
  p [written, reader.read.bytes, text.encoding.name]
ensure
  reader.close unless reader.closed?
  writer.close unless writer.closed?
end

reader, writer = IO.pipe
begin
  writer.set_encoding(Encoding::UTF_16LE)
  text = "\xff".force_encoding(Encoding::UTF_8).freeze
  written = writer.write_nonblock(text)
  writer.close
  p [written, reader.read.bytes, text.encoding.name, text.frozen?]
ensure
  reader.close unless reader.closed?
  writer.close unless writer.closed?
end

# Ordinary writes still use the configured converter.
reader, writer = IO.pipe
begin
  writer.set_encoding(Encoding::UTF_16LE)
  written = writer.write("é!")
  writer.close
  p [written, reader.read.bytes]
ensure
  reader.close unless reader.closed?
  writer.close unless writer.closed?
end

reader, writer = IO.pipe
begin
  text = "a\0b"
  def text.b
    raise "write_nonblock dispatched String#b"
  end
  begin
    written = writer.write_nonblock(text)
    writer.close
    p [written, reader.read.bytes]
  rescue => error
    p [error.class, error.message]
  end
ensure
  reader.close unless reader.closed?
  writer.close unless writer.closed?
end

reader, writer = IO.pipe
begin
  value = Object.new
  def value.to_s = "converted"
  written = writer.write_nonblock(value)
  writer.close
  p [written, reader.read]
ensure
  reader.close unless reader.closed?
  writer.close unless writer.closed?
end
