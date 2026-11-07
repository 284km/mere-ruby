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

# User conversions can close the socket and immediately reuse its descriptor.
# A failed send must leave the destination empty; a failed receive must leave
# the replacement socket's queued packet intact.
[:message, :flags, :host, :port, :packed].each do |conversion|
  receiver = UDPSocket.new
  udp = UDPSocket.new
  replacement = nil
  begin
    receiver.bind('127.0.0.1', 0)
    fd = udp.fileno
    port = receiver.addr[1]
    packed = Socket.sockaddr_in(port, '127.0.0.1')
    proxy = Object.new
    proxy.define_singleton_method(conversion == :flags ? :to_int : :to_str) do
      udp.close
      replacement = UDPSocket.new
      raise 'descriptor was not reused' unless replacement.fileno == fd
      case conversion
      when :message then 'unexpected'
      when :flags then 0
      when :host then '127.0.0.1'
      when :port then port.to_s
      when :packed then packed
      end
    end
    caught = nil
    begin
      if conversion == :packed
        udp.send('unexpected', 0, proxy)
      else
        udp.send(conversion == :message ? proxy : 'unexpected',
                 conversion == :flags ? proxy : 0,
                 conversion == :host ? proxy : '127.0.0.1',
                 conversion == :port ? proxy : port)
      end
    rescue IOError => error
      caught = error
    end
    raise 'send did not reject the closed stream' unless caught
    raise 'send touched the replacement descriptor' if IO.select([receiver], nil, nil, 0.02)
    p [:closed_during_send, conversion, caught.class, caught.message]
  ensure
    [udp, receiver, replacement].each { |socket| socket.close if socket && !socket.closed? }
  end
end

[:recv, :recvfrom].each do |method|
  [:length, :flags].each do |conversion|
    sender = UDPSocket.new
    udp = UDPSocket.new
    replacement = nil
    begin
      fd = udp.fileno
      proxy = Object.new
      proxy.define_singleton_method(:to_int) do
        udp.close
        replacement = UDPSocket.new
        raise 'descriptor was not reused' unless replacement.fileno == fd
        replacement.bind('127.0.0.1', 0)
        sender.send('keep queued', 0, '127.0.0.1', replacement.addr[1])
        raise 'packet not ready' unless IO.select([replacement], nil, nil, 2)
        conversion == :length ? 64 : 0
      end
      caught = nil
      begin
        length = conversion == :length ? proxy : 64
        flags = conversion == :flags ? proxy : 0
        if method == :recv
          udp.recv(length, flags)
        else
          udp.recvfrom(length, flags)
        end
      rescue IOError => error
        caught = error
      end
      raise 'receive did not reject the closed stream' unless caught
      raise 'receive consumed the replacement packet' unless IO.select([replacement], nil, nil, 0)
      raise 'replacement packet changed' unless replacement.recv(64) == 'keep queued'
      p [:closed_during_receive, method, conversion, caught.class, caught.message]
    ensure
      [udp, sender, replacement].each { |socket| socket.close if socket && !socket.closed? }
    end
  end
end
