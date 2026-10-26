# Socket options, set and read back through getsockopt(2) / setsockopt(2):
# a flag, an int, a linger, TCP_NODELAY, the socket's type, what each
# argument form becomes, and the refusals. Flags are compared as booleans
# (macOS reads one back as the option's own bit, Linux as 1).
require "socket"

def try406
  yield
rescue StandardError => e
  [e.class, e.message]
end

s = Socket.new(:INET, :STREAM)
p s.getsockopt(:SOCKET, :REUSEADDR).bool
p s.setsockopt(:SOCKET, :REUSEADDR, true), s.getsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR).bool
p s.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 0), s.getsockopt(:SOCKET, :REUSEADDR).bool
p s.setsockopt(:SOCKET, :KEEPALIVE, [1].pack("i")), s.getsockopt(:SOCKET, :KEEPALIVE).bool
p s.getsockopt(:SOCKET, :TYPE).int == Socket::SOCK_STREAM
p s.setsockopt(Socket::Option.linger(true, 7)), s.getsockopt(:SOCKET, :LINGER).linger
p s.getsockopt(:SOCKET, :LINGER).inspect.sub(/on\(\d+\)/, "on")
p s.setsockopt(:TCP, :NODELAY, 1), s.getsockopt(:TCP, :NODELAY).bool
opt = s.getsockopt(:SOCKET, :TYPE)
p opt.class, opt.level == Socket::SOL_SOCKET, opt.optname == Socket::SO_TYPE, opt.family == Socket::AF_INET
p try406 { s.setsockopt(:SOCKET, :REUSEADDR, nil) }
p try406 { s.setsockopt(:SOCKET, :REUSEADDR, 2**40) }
p try406 { s.setsockopt(:SOCKET, :LINGER, "\x00\x00\x00") }.first
p try406 { s.getsockopt(:SOCKET, :NOSUCH) }.first
s.close
p try406 { s.getsockopt(:SOCKET, :TYPE) }

server = TCPServer.new("127.0.0.1", 0)
p server.getsockopt(:SOCKET, :REUSEADDR).bool
server.close

a, b = UNIXSocket.pair
p a.getsockopt(:SOCKET, :TYPE).int == Socket::SOCK_STREAM, a.getsockopt(:SOCKET, :TYPE).family == Socket::AF_UNIX
a.close
b.close
