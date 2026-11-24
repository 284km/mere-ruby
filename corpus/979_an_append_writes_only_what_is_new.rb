# A File opened for appending writes what it was given onto the end of the
# file, and nothing else. A flush used to read the whole file and write it
# back with the new bytes added: each flush cost the size of the file, and
# between the truncate and the write the file on disk was empty. A logger
# flushes per line, so ActiveRecord's test log (45 MB by the end of its
# suite) was read and rewritten for every SQL statement.
#
# What a program can see of that: another handle's bytes are not lost, the
# file is never shorter than it was, and its content is what was written, in
# order.
require "tmpdir"
dir = Dir.mktmpdir("mrb_append")
path = File.join(dir, "log.txt")
begin
  File.write(path, "head\n")
  a = File.open(path, "a")
  a.sync = true
  a.write("a1\n")
  p File.read(path)
  # a second appender on the same path: both keep what the other wrote
  b = File.open(path, "a")
  b.write("b1\n"); b.flush
  a.write("a2\n")
  b.write("b2\n"); b.flush
  p File.read(path)
  # bytes that arrive from OUTSIDE the handle stay: the handle does not
  # write back an older picture of the file
  File.open(path, "a") { |f| f.write("outside\n") }
  a.write("a3\n")
  p File.read(path)
  # the size only grows, flush by flush
  sizes = []
  200.times { |i| a.write("line #{i}\n"); sizes << File.size(path) }
  p sizes.each_cons(2).all? { |x, y| y > x }, sizes.first, sizes.last
  # a seek does not move an append
  a.seek(0)
  a.write("after seek\n")
  p File.read(path).lines.last, File.read(path).lines.first
  # binary bytes, a NUL among them
  a.write("\x00\xFF\n".b)
  p File.binread(path)[-3, 3].bytes
  # buffered (not sync) and then closed
  c = File.open(path, "a")
  c.write("c1\n"); c.write("c2\n")
  c.close
  p File.read(path).lines.last(2)
  a.close; b.close
  p File.read(path).lines.size
  # a file that is not there yet is created by the append
  fresh = File.join(dir, "fresh.txt")
  File.open(fresh, "a") { |f| f.write("x"); f.flush; f.write("y") }
  p File.read(fresh)
  # "a+" reads what is there and appends
  File.open(fresh, "a+") { |f| f.write("z"); f.flush; f.rewind; p f.read }
  # a Logger, which is how this was met
  require "logger"
  lp = File.join(dir, "l.log")
  lg = Logger.new(lp)
  lg.formatter = proc { |sev, _, _, msg| "#{sev}:#{msg}\n" }
  3.times { |i| lg.info("m#{i}") }
  p File.read(lp).lines.reject { |l| l.start_with?("#") }
  lg.close
ensure
  Dir.children(dir).each { |f| File.delete(File.join(dir, f)) }
  Dir.rmdir(dir)
end
