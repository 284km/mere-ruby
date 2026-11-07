require 'socket'

# A listening socket can queue a connection without a Ruby accept thread.
# Failures therefore leave no thread blocked in an ensure clause.
def exchange(host, **options)
  server = TCPServer.new(host, 0)
  client = TCPSocket.new('localhost', server.addr[1], **options)
  accepted = server.accept
  accepted.write("a\0b")
  p [client.remote_address.ip_address == host, client.recvfrom(3)]
  accepted.close
  accepted = nil
  p client.recvfrom(1) # EOF is nil, not a two-element packet.
ensure
  accepted&.close
  client&.close
  server&.close
end

exchange('127.0.0.1', test_mode_settings: {delay: {ipv6: 1000}})
exchange('127.0.0.1', test_mode_settings: {error: {ipv6: Socket::EAI_FAIL}})
# A deadline for the unresolved family must preserve the IPv4 answer and
# release the preference wait, even before that answer has been attempted.
exchange('127.0.0.1', resolv_timeout: 0.01,
         test_mode_settings: {delay: {ipv6: 1000}})

# A failed connection does not hide the unresolved family's timeout when
# there is no usable address or active attempt left.
closed = TCPServer.new('127.0.0.1', 0)
port = closed.addr[1]
closed.close
begin
  TCPSocket.new('localhost', port, resolv_timeout: 0.01,
               test_mode_settings: {delay: {ipv4: 1000}})
rescue IO::TimeoutError
  p :resolution_timeout_after_connection_failure
end

[:open_timeout, :resolv_timeout].each do |kind|
  begin
    TCPSocket.new('localhost', 1, **{kind => 0.02},
                  test_mode_settings: {delay: {ipv4: 1000, ipv6: 1000}})
  rescue IO::TimeoutError
    p kind
  end
end

begin
  TCPSocket.new('localhost', 1, open_timeout: 1, connect_timeout: 1)
rescue ArgumentError
  p :conflicting_timeouts
end

server = TCPServer.new('127.0.0.1', 0)
client = TCPSocket.new('127.0.0.1', server.addr[1], '127.0.0.1', 0,
                       connect_timeout: 1, fast_fallback: false)
accepted = server.accept
p client.local_address.ip_address == '127.0.0.1'
client.close
accepted.close
server.close

# Each address comes from getifaddrs; IPv6 scope IDs must survive conversion.
addresses = Socket.ip_address_list
p [addresses.any?(&:ipv4_loopback?), addresses.all?(&:ip?),
   addresses.all? { |a| a.ip_port == 0 && a.socktype == 0 }]
