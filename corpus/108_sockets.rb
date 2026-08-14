# TCP, over the interpreter's own socket primitives. The whole exchange runs
# in one process: the connect sits in the listener's backlog until accept
# takes it, so no thread is needed.
require "socket"

p [TCPSocket.superclass.to_s, TCPServer.superclass.to_s, IPSocket.superclass.to_s]
p [Socket::AF_INET, Socket::SOCK_STREAM, Socket::SOL_SOCKET]

PORT = 53791
server = TCPServer.new(PORT)
client = TCPSocket.new("127.0.0.1", PORT)
conn = server.accept

# a payload with a zero byte in it: the bytes cross as bytes
client.write("hello\0world\n")
line = conn.gets
p line
p [line.bytesize, line.encoding.to_s]

conn.write("pong\n")
conn.write("second\n")
p client.gets
p client.gets

client.print("a", "b")
client.write("\n")
p conn.gets

client.close
p conn.read
conn.close
server.close
p [client.closed?, conn.closed?, server.closed?]

# connecting where nobody listens is the errno ruby raises
begin
  TCPSocket.new("127.0.0.1", 1)
rescue Errno::ECONNREFUSED => e
  p e.class
end

# The sockets mere-ruby does not speak exist and refuse; ruby implements them,
# so only their presence is compared here (what they raise is in KNOWN_GAPS).
p [defined?(UDPSocket), defined?(UNIXSocket), defined?(UNIXServer)]

# Addrinfo carries the pair it was given
ai = Addrinfo.tcp("127.0.0.1", 80)
p [ai.ip_address, ai.ip_port, ai.afamily == Socket::AF_INET]
