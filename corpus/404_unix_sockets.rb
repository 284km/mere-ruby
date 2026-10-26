# UNIX domain sockets: a server at a path, a client connected to it, what
# each end says its path and addresses are, bytes both ways, the refusals
# (no listener, a path in use, a path too long for sun_path), and Socket's
# own unix helpers. The path is short and under /tmp on purpose: sun_path
# holds 104 bytes on macOS, and a long working directory would make both
# sides refuse alike.
require "socket"

def try404
  yield
rescue StandardError => e
  [e.class, e.message.gsub(PATH, "PATH")]
end

PATH = "/tmp/mr404-#{$$}.sock"
File.unlink(PATH) if File.exist?(PATH)

p try404 { UNIXSocket.new(PATH) }
p try404 { UNIXSocket.new("/tmp/" + "x" * 200) }
p try404 { UNIXSocket.new(nil) }

server = UNIXServer.new(PATH)
p server.path == PATH, server.addr == ["AF_UNIX", PATH], server.local_address.unix_path == PATH
p File.socket?(PATH), server.inspect == "#<UNIXServer:#{PATH}>"
p try404 { UNIXServer.new(PATH) }

client = UNIXSocket.new(PATH)
peer = server.accept
p peer.class, client.path, client.addr, client.peeraddr == ["AF_UNIX", PATH]
p peer.path == PATH, peer.peeraddr
client.write("ping")
p peer.recvfrom(4)
peer.write("pong")
p client.read(4)
client.close
p peer.read
peer.close

p server.accept_nonblock(exception: false)
c2 = UNIXSocket.new(PATH)
fd = server.sysaccept
p fd.is_a?(Integer)
IO.for_fd(fd).close
c2.close
p server.listen(3)
server.close
File.unlink(PATH)

# Socket's own: a listening socket at a path, removed when the block ends
Socket.unix_server_socket(PATH) do |s|
  p s.class, s.local_address.unix?
  Socket.unix(PATH) do |c|
    a, _ = s.accept
    c.write("abc")
    p a.read(3)
    a.close
  end
end
p File.exist?(PATH)

# Socket.new with an AF_UNIX address
s = Socket.new(:UNIX, :STREAM)
s.bind(Addrinfo.unix(PATH))
s.listen(1)
c = Socket.new(:UNIX, :STREAM)
p c.connect(Addrinfo.unix(PATH))
a, = s.accept
c.write("xy")
p a.read(2)
[a, c, s].each(&:close)
File.unlink(PATH)

# a pair has no paths
x, y = UNIXSocket.pair
p x.path, y.addr
x.close
y.close
