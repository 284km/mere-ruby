require 'socket'
[[Socket::AF_INET,'127.0.0.1'],[Socket::AF_INET6,'::1']].each do |family,host|
  [UDPSocket,Socket].each do |type|
    receiver = type == UDPSocket ? UDPSocket.new(family) : Socket.new(family,Socket::SOCK_DGRAM)
    peer = UDPSocket.new(family)
    foreign = UDPSocket.new(family)
    begin
      if type == UDPSocket
        receiver.bind(host,0)
      else
        receiver.bind(Socket.sockaddr_in(0,host))
      end
      peer.bind(host,0)
      local = receiver.local_address
      descriptor = receiver.fileno
      if type == UDPSocket
        receiver.connect(host,peer.addr[1])
      else
        receiver.connect(peer.local_address)
      end
      raise 'bound descriptor replaced' unless receiver.fileno == descriptor
      raise 'bound port changed' unless receiver.local_address.ip_port == local.ip_port
      raise 'kernel peer changed' unless receiver.remote_address.ip_port == peer.addr[1]
      foreign.send('foreign',0,host,local.ip_port)
      peer.send('accepted',0,host,local.ip_port)
      raise 'connected UDP not ready' unless IO.select([receiver],nil,nil,2)
      data = receiver.recv(64)
      raise 'connected UDP accepted another sender' unless data == 'accepted'
      receiver.send('reply',0)
      raise 'bound connected UDP send changed' unless peer.recv(64) == 'reply'
      conversions = 0
      length = Object.new
      length.define_singleton_method(:to_int) { conversions += 1; 3 }
      peer.send('coerced',0,host,local.ip_port)
      raise 'UDP recv length coercion changed' unless receiver.recv(length) == 'coe' && conversions == 1
      p [type.name, family == Socket::AF_INET6, data, receiver.fileno == descriptor]
    ensure
      [receiver,peer,foreign].each(&:close)
    end
  end
end
