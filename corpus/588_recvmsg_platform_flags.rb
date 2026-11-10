require 'socket'
[:dgram, :stream].each do |kind|
  [false, true].each do |nonblock|
    first, second = Socket.pair(Socket::AF_UNIX, kind == :dgram ? Socket::SOCK_DGRAM : Socket::SOCK_STREAM)
    begin
      second.send('data',0)
      message, _, flags = nonblock ? first.recvmsg_nonblock(4) : first.recvmsg(4)
      p [kind, nonblock, message, flags]
    ensure
      first.close
      second.close
    end
  end
end
