# An Addrinfo is a sockaddr plus three integers, and everything it answers is
# read back out of that sockaddr: the address text, the port, the predicates,
# inspect. None of it needs the network, and none of it may depend on the
# machine -- no constant values, no raw bytes (their layout is the
# platform's), no names from /etc/hosts.
require "socket"

p Addrinfo.tcp("127.0.0.1", 80)
p Addrinfo.udp("::1", 53)
p Addrinfo.ip("10.0.0.1")
p Addrinfo.unix("/tmp/sock")
p Addrinfo.unix("rel", :DGRAM)
p Addrinfo.tcp("2001:0DB8:0000:0000:0000:0000:0000:0001", 443)

# inet_ntop's rule: the longest run of zero words is "::", the first one on a
# tie, and a mapped or compatible IPv4 address keeps its dotted tail
%w[1:0:0:1:0:0:0:1 1:0:0:0:1:0:0:1 ::ffff:192.168.1.1 ::192.168.1.1 fe80::1 1::].each do |s|
  puts "#{s} -> #{Addrinfo.ip(s).ip_address}"
end

a = Addrinfo.tcp("192.168.0.5", 8080)
p [a.ip_address, a.ip_port, a.ip_unpack, a.ipv4?, a.ipv6?, a.ip?, a.unix?]
p [a.ipv4_private?, a.ipv4_loopback?, a.ipv4_multicast?]
p [Addrinfo.ip("224.0.0.9").ipv4_multicast?, Addrinfo.ip("127.9.9.9").ipv4_loopback?]
p [Addrinfo.ip("ff02::1").ipv6_mc_linklocal?, Addrinfo.ip("ff1e::").ipv6_mc_global?,
   Addrinfo.ip("fc00::1").ipv6_unique_local?, Addrinfo.ip("::").ipv6_unspecified?]
p Addrinfo.ip("::ffff:10.1.2.3").ipv6_to_ipv4
p Addrinfo.ip("::1").ipv6_to_ipv4

# the Array form of a sockaddr, and what inspect adds when the name given
# differs from the address
p Addrinfo.new(["AF_INET", 46102, "somehost", "127.0.0.1"])
p Addrinfo.new(["AF_INET", 46102, nil, "127.0.0.1"], nil, :STREAM)
begin
  Addrinfo.new(["AF_INET6", 80, "h", "127.0.0.1"])
rescue SocketError => e
  p e.class.ancestors.include?(SocketError)
end
p Addrinfo.new(Addrinfo.tcp("127.0.0.1", 80).to_sockaddr).inspect

# a family_addrinfo is built "the same way" as its source
src = Addrinfo.udp("127.0.0.1", 0)
p src.family_addrinfo("127.0.0.2", 99)
begin
  src.family_addrinfo(Addrinfo.tcp("127.0.0.1", 1))
rescue ArgumentError => e
  p e.message
end

# the marshal form names things instead of numbering them, and round-trips
p Addrinfo.tcp("127.0.0.1", 80).marshal_dump
p Addrinfo.unix("foo").marshal_dump
p Marshal.load(Marshal.dump(Addrinfo.udp("::1", 7)))

# numeric getaddrinfo: one result per socket type, in raddrinfo.c's order
p Addrinfo.getaddrinfo("127.0.0.1", 80)
p Addrinfo.getaddrinfo("::1", 80, nil, :DGRAM)
p Socket.getaddrinfo("127.0.0.1", 25, nil, :STREAM).map { |r| r[0, 4] }
p Socket.unpack_sockaddr_in(Socket.sockaddr_in(8080, "10.2.3.4"))
p Socket.unpack_sockaddr_un(Socket.sockaddr_un("/var/run/x.sock"))

# Socket::Option and Socket::AncillaryData are their structs
o = Socket::Option.int(:INET, :SOCKET, :KEEPALIVE, 1)
p [o.int, o.bool, o]
p Socket::Option.bool(:INET, :TCP, :NODELAY, true).bool
p Socket::Option.linger(true, 30), Socket::Option.linger(true, 30).linger
begin
  Socket::Option.new(:INET, :SOCKET, :NO_SUCH_OPTION, "")
rescue SocketError => e
  p e.message
end
d = Socket::AncillaryData.int(:INET, :IP, :TTL, 64)
p [d.int, d.cmsg_is?(:IP, :TTL), d.cmsg_is?(:SOCKET, :RIGHTS)]
i6 = Socket::AncillaryData.ipv6_pktinfo(Addrinfo.ip("::1"), 3)
p i6.ipv6_pktinfo
