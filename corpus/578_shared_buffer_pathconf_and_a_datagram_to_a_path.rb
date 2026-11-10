# Round 15 of note 541 (Mere v0.1.726): an IO::Buffer made MAPPED | SHARED is
# memory a forked child writes into and its parent reads (a MAPPED one
# without SHARED is the parent's own); IO#pathconf asks fpathconf(3) by
# Etc::PC_*; and a datagram socket sends to a path, the receiver naming the
# bound sender's path and "" for an unbound one.
$VERBOSE = nil
require "socket"
require "etc"

b = IO::Buffer.new(64, IO::Buffer::MAPPED | IO::Buffer::SHARED)
p [b.shared?, b.mapped?, b.size]
pid = fork { b.set_string("Hello World") }
Process.wait(pid)
p b.get_string(0, 11)
p b.slice(6, 5).get_string
c = b.dup
b.set_string("J")
p [c.get_string(0, 5), b.get_string(0, 5), c.shared?]
pid = fork { b.set_value(:U8, 1, 0x41) }
Process.wait(pid)
p b.get_string(0, 5)
p [b.resize(128).size, b.get_string(0, 5), b.shared?]
b.free
p b.null?

own = IO::Buffer.new(64, IO::Buffer::MAPPED)
pid = fork { own.set_string("child") }
Process.wait(pid)
p own.get_string(0, 5)

IO.pipe do |r, w|
  v = w.pathconf(Etc::PC_PIPE_BUF)
  p v.is_a?(Integer) && v >= 512
end
p Etc::PC_NAME_MAX.is_a?(Integer), Etc::PC_PIPE_BUF != Etc::PC_NAME_MAX
p((STDOUT.pathconf(-5) rescue $!.class))
p((STDOUT.pathconf(nil) rescue $!.class))

base = "/tmp/mr578-#{$$}"
path1, path2 = "#{base}-a", "#{base}-b"
client = Socket.new(:UNIX, :DGRAM)
client.bind(Socket.sockaddr_un(path1))
server = Socket.new(:UNIX, :DGRAM)
server.bind(Socket.sockaddr_un(path2))
u = UNIXSocket.for_fd(server.fileno)
u.autoclose = false
p client.send("hello", 0, Socket.sockaddr_un(path2))
data, (fam, from) = u.recvfrom(5)
p [data, fam, from == path1]
anon = Socket.new(:UNIX, :DGRAM)
p anon.send("hey", 0, Addrinfo.unix(path2))
data, (fam, from) = u.recvfrom(5)
p [data, fam, from]
p((anon.send("x", 0, Socket.sockaddr_un("#{base}-none")) rescue $!.class))
[client, server, anon].each(&:close)
File.unlink(path1, path2)
