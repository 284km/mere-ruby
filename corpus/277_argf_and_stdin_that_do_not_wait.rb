# ARGF and standard input as CRuby's test_argf drives them: a read that must
# not wait, an in-place mode that belongs to one ARGF, readers that take
# chomp:, and a limit of 0 that is refused instead of read forever.
path = "/tmp/mr277_#{$$}.txt"
File.write(path, "foo\nbar\nbaz\n")

# the in-place mode is the ARGF's own
ARGF.inplace_mode = ".bak277"
a = ARGF.class.new(path)
p a.inplace_mode, ARGF.inplace_mode
begin
  ARGF.inplace_mode = "a\0"
rescue ArgumentError => e
  p e.message
end
p a.gets, ARGF.inplace_mode
a.close
ARGF.inplace_mode = nil
p File.read(path).lines.size, File.exist?(path + ".bak277")

# limit 0
[:readlines, :each_line].each do |m|
  begin
    ARGF.class.new(path).send(m, 0) {}
  rescue ArgumentError => e
    p e.message
  end
end

# a child reading its standard input without waiting, and Kernel#readline's chomp:
rb = RbConfig.ruby
child = <<~'RUBY'
  $stdout.sync = true
  p $stdin.read_nonblock(1, +"", exception: false)
  begin
    $stdin.read_nonblock(1)
  rescue IO::WaitReadable => e
    p e.class
  end
  puts "ready"
  IO.select([$stdin])
  p $stdin.read_nonblock(5)
  p readline(chomp: true), gets(chomp: true)
  p readlines(chomp: true)
  p $stdin.read_nonblock(1, exception: false)
RUBY
IO.popen([rb, "-e", child], "r+") do |f|
  p f.gets, f.gets
  p f.gets
  f.write "ab\ncd\nef\ngh\n"
  f.close_write
  puts f.read
end
File.delete(path)
