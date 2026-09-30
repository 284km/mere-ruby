# A socket is an IO: BasicSocket's superclass is IO, so every stream method,
# IO.select and #to_io are a socket's too, over the same buffers a pipe has.
# The server is on 127.0.0.1 and the client asks for "localhost", which
# resolves to ::1 first on most machines -- the connect has to try the next
# address rather than give up on the first. Only stable values are printed
# (no ports, no descriptor numbers).
require "socket"

p TCPSocket.ancestors.take_while { |c| c != Object }.first(4)
p [TCPServer.new("127.0.0.1", 0).is_a?(IO), Socket.superclass.superclass]

server = TCPServer.new("127.0.0.1", 0)
port = server.addr[1]
client = TCPSocket.new("localhost", port)
conn = server.accept

p [client.to_io.equal?(client), client.fileno.is_a?(Integer), client.respond_to?(:readpartial)]
p [client.sync, client.binmode?, client.external_encoding]

# nothing has been written: not readable within the timeout
p IO.select([conn], nil, nil, 0)
client.write("one\ntwo\nthree\n")
r, = IO.select([conn.to_io], nil, nil, 5)
p r.map(&:class)

# a line read reads ahead; a write in between must not drop what it read
p conn.gets
conn.write("ack\n")
p client.gets
p conn.gets(chomp: true)
p conn.readpartial(100)

client.puts "a", "b"
client.print "c\n"
p conn.each_line.first(3)

# closing the write half is the peer's end of file
client.close_write
p [conn.read, conn.eof?, client.closed?]
conn.close
p [conn.closed?, (conn.gets rescue $!.class)]
client.close

# a server in a thread, reached with the IO methods only
t = Thread.new do
  s = server.accept
  line = s.readline
  s.write "got #{line}"
  s.close
end
c2 = TCPSocket.new("127.0.0.1", port)
c2.puts "hello"
p c2.read
t.join
c2.close
server.close

begin
  TCPSocket.new("127.0.0.1", port)
rescue SystemCallError => e
  p e.class
end
