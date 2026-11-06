require 'socket'

[[Socket::AF_INET, '127.0.0.1'], [Socket::AF_INET6, '::1']].each do |family, host|
  sockets = []
  begin
    sender, first, second = Array.new(3) do
      socket = UDPSocket.new(family)
      sockets << socket
      socket.bind(host, 0)
      socket
    end
    source = sender.addr(false)
    targets = [first, second]
    ["a\0\xff".b, '', 'next'].each_with_index do |data, i|
      receiver = targets[i % 2]
      port = receiver.addr[1]
      p sender.send(data, 0, host, port)
      actual, address = receiver.recvfrom(100)
      p [actual, actual.encoding, address == source, sender.addr(false) == source]
    end
    begin
      sender.peeraddr
    rescue => error
      p error.class
    end
    # A packed sockaddr and Addrinfo both name a destination.
    [Socket.sockaddr_in(first.addr[1], host), Addrinfo.udp(host, first.addr[1])].each do |destination|
      p sender.send('packed', 0, destination)
      data, address = first.recvfrom(32)
      p [data, address == source]
    end
    p sender.send('abcdef', 0, host, first.addr[1])
    data, address = first.recvfrom(2, Socket::MSG_PEEK)
    p [data, address == source]
    p first.recv(4, Socket::MSG_PEEK)
    p first.recvfrom(3).then { |data, address| [data, address == source] }
    p sender.send('zero capacity', 0, host, first.addr[1])
    raise 'packet not ready' unless IO.select([first], nil, nil, 2)
    p first.recvfrom(0).then { |data, address| [data, address == source] }
    p sender.send('buffer', 0, host, first.addr[1])
    buffer = 'old'.encode(Encoding::UTF_16LE)
    result = first.recv(3, 0, buffer)
    p [result.equal?(buffer), result.bytes, result.encoding]
    # Coercion happens once, before the native byte pointer is taken.
    conversions = []
    message = Object.new
    message.define_singleton_method(:to_str) { conversions << :message; 'coerced' }
    flags = Object.new
    flags.define_singleton_method(:to_int) { conversions << :flags; GC.start; 0 }
    p sender.send(message, flags, host, first.addr[1])
    p [first.recv(32), conversions]
    [nil, Object.new].each do |bad|
      begin
        sender.send(bad, 0, host, first.addr[1])
      rescue => error
        p error.class
      end
    end
    begin
      first.recvfrom(-1)
    rescue => error
      p error.class
    end
    begin
      sender.send('x' * 70_000, 0, host, first.addr[1])
    rescue => error
      p error.class
    end
    [nil, 2**31, -2**31-1].each do |bad_flags|
      begin
        sender.send('bad flags', bad_flags, host, first.addr[1])
      rescue => error
        p error.class
      end
    end
    [2**31, -2**31-1].each do |bad_length|
      begin
        first.recvfrom(bad_length)
      rescue => error
        p error.class
      end
    end
    p sender.send('outbuf', 0, host, first.addr[1])
    buffer = 'old'
    data, address = first.recvfrom(64, nil, buffer)
    p [data, data.equal?(buffer), address == source]
    # Connected sends still use their peer; no fd replacement per send.
    connected = UDPSocket.new(family)
    sockets << connected
    connected.connect(host, second.addr[1])
    peer = connected.peeraddr(false)
    local = connected.addr(false)
    p connected.send('connected', 0)
    p second.recvfrom(32).then { |data, address| [data, address == local] }
    p [connected.peeraddr(false) == peer, connected.addr(false) == local]
    sender.close
    begin
      sender.send('closed', 0, host, first.addr[1])
    rescue => error
      p error.class
    end
  ensure
    sockets.each { |socket| socket.close unless socket.closed? }
  end
end

# The receiving thread must yield until another Ruby thread sends.
server = UDPSocket.new
client = UDPSocket.new
begin
  server.bind('127.0.0.1', 0)
  receiver = Thread.new { server.recvfrom(64) }
  Thread.pass
  client.send('thread', 0, '127.0.0.1', server.addr[1])
  data, address = receiver.value
  p [data, address[1] == client.addr[1], address[3]]
ensure
  server.close
  client.close
end
