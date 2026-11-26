mode, count = ARGV.fetch(0), Integer(ARGV.fetch(1))
srand(Integer(ARGV.fetch(2).split("=").last))
reader, writer = IO.pipe
total = 0
work = -> do
  count.times do
    case mode
    when "ready", "thread_ready"
      result = IO.select(nil, [writer], nil, 0)
      total += 1 if result == [[], [writer], []]
    when "nonblock"
      writer.write_nonblock("x")
      total += 1 if reader.read_nonblock(1) == "x"
    else
      raise "unknown mode"
    end
  end
end
begin
  mode == "thread_ready" ? Thread.new(&work).join : work.call
  p [mode, count, total]
ensure
  reader.close
  writer.close
end
