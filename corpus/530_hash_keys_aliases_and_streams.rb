# What net/http, resolv, zlib and io/wait found: an Array key holding
# objects with their own #hash and #eql?, an alias of Class#new taken before
# the class defined its own, `raise exc, msg` on a lightweight exception, the
# bytes after a deflate stream's end, a recursive inflate, and a FIFO opened
# with O_NONBLOCK.
require "zlib"
require "tmpdir"

def show(label)
  v = yield
  puts "#{label}: #{v.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}: #{e.message}"
end

class Label
  attr_reader :s
  def initialize(s) = @s = s
  def ==(o) = o.class == Label && o.s.casecmp?(s)
  alias eql? ==
  def hash = s.downcase.hash
end
names = {}
names[[Label.new("www"), Label.new("Example")]] = 12
show("array key") { names[[Label.new("WWW"), Label.new("example")]] }
show("array key?") { names.key?([Label.new("www"), Label.new("example")]) }
show("nested") { {[[Label.new("a")]] => 1}[[[Label.new("A")]]] }
show("hash key") { {{k: Label.new("x")} => 2}[{k: Label.new("X")}] }

class Conn
  def initialize(*a) = @a = a
  attr_reader :a
  class << self
    alias newobj new
  end
  def self.new(*) = :from_new
end
show("alias of new") { [Conn.newobj(1, 2).class, Conn.newobj(1, 2).a, Conn.new] }

class MyError < StandardError; end
show("raise exc, msg") do
  begin
    begin
      raise MyError, "open failure"
    rescue => e
      raise e, "Failed to open (#{e.message})"
    end
  rescue => w
    [w.class, w.message]
  end
end

z = Zlib::Inflate.new
# (zlib's own deflate of "hello": the bytes are the stream, not mere-ruby's
#  deflate output, whose length may differ)
show("after the end") { [z.inflate("x\x9C\xCBH\xCD\xC9\xC9\a\x00\x06,\x02\x15\r\n".b), z.finished?, z.total_in] }
z2 = Zlib::Inflate.new
z2.inflate(Zlib.deflate("hi"))
show("fed after the end") { [z2.inflate("xy"), z2.finish] }
z3 = Zlib::Inflate.new
s = Zlib.deflate("x" * 50_000)
show("recursive inflate") { z3.inflate(s) { z3.inflate(s) } }

Dir.mktmpdir do |d|
  fifo = File.join(d, "fifo")
  File.mkfifo(fifo)
  show("writer before a reader") do
    File.open(fifo, IO::WRONLY | IO::NONBLOCK)
  rescue SystemCallError => e
    [e.class, e.message.sub(fifo, "FIFO")]
  end
  rd = File.open(fifo, IO::RDONLY | IO::NONBLOCK)
  wr = File.open(fifo, IO::WRONLY | IO::NONBLOCK)
  show("classes") { [rd.class, wr.class] }
  show("nothing yet") { rd.wait_readable(0) }
  wr.syswrite "hi"
  show("readable") { rd.wait_readable(1).equal?(rd) }
  wr.close
  show("gets") { rd.gets }
  rd.close
end
